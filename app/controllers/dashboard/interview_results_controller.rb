class Dashboard::InterviewResultsController < Dashboard::BaseController
  before_action :set_result, only: [:show, :notify_hire, :notify_reject, :regenerate_summary, :judge_pass, :judge_fail]

  def index
    redirect_to dashboard_candidates_path
  end

  def show
    @responses = @result.interview.interview_responses
      .in_order
      .includes(:question)
      .with_attached_answer_audio
      .with_attached_answer_video
  end

  def notify_hire
    send_decision_email(:hire)
  end

  def notify_reject
    send_decision_email(:reject)
  end

  def regenerate_summary
    InterviewEngine::SessionManager.ensure_summary!(@result, force: true)
    redirect_to dashboard_interview_result_path(@result), notice: "AI総評を生成しました。"
  rescue StandardError => e
    Rails.logger.error("[regenerate_summary] result=#{@result.id}: #{e.class}: #{e.message}")
    redirect_to dashboard_interview_result_path(@result), alert: "AI総評の生成に失敗しました。"
  end

  def judge_pass
    apply_manual_judgment!(:passed)
  end

  def judge_fail
    apply_manual_judgment!(:failed)
  end

  private

  def apply_manual_judgment!(status)
    unless @result.pending_review? || @result.interview.situation.manual_judgment?
      return redirect_to dashboard_interview_result_path(@result), alert: "この結果は手動判定の対象ではありません。"
    end

    @result.update!(final_status: status)
    redirect_to dashboard_interview_result_path(@result), notice: status == :passed ? "合格に確定しました。" : "不合格に確定しました。"
  end

  def scoped_results
    interview_results_scope
  end

  def set_result
    @result = scoped_results
      .includes(interview: [:user, :situation, :interview_responses])
      .find(params[:id])
  end

  def result_client
    @result.interview.situation.client
  end

  def send_decision_email(decision)
    label = decision == :hire ? "採用" : "不採用"
    user = @result.interview.user
    if user&.email.blank?
      return redirect_back fallback_location: dashboard_interview_result_path(@result),
                           alert: "候補者のメールアドレスがありません。"
    end

    client = result_client
    vars = decision_template_variables(client)
    if decision == :hire
      subject = client.render_decision_email_template(client.hire_email_subject_template, vars)
      body = client.render_decision_email_template(client.hire_email_body_template, vars)
    else
      subject = client.render_decision_email_template(client.reject_email_subject_template, vars)
      body = client.render_decision_email_template(client.reject_email_body_template, vars)
    end

    InterviewDecisionMailer.decision_email(
      interview_result: @result,
      decision: decision,
      subject: subject,
      body: body,
      reply_to: client.email
    ).deliver_now

    @result.interview.update!(ops_status: "contacted")

    redirect_back fallback_location: dashboard_interview_result_path(@result),
                  notice: "#{label}通知メールを #{user.email} へ送信しました。"
  rescue StandardError => e
    Rails.logger.error("[InterviewDecisionMailer] #{decision} failed result=#{@result.id}: #{e.class}: #{e.message}")
    redirect_back fallback_location: dashboard_interview_result_path(@result),
                  alert: "#{label}通知メールの送信に失敗しました。設定を確認してください。"
  end

  def decision_template_variables(client)
    interview = @result.interview
    user = interview.user
    {
      "candidate_name" => user&.name.presence || "候補者",
      "candidate_email" => user&.email.to_s,
      "company" => client.company.presence || "弊社",
      "situation_title" => interview.situation&.title.to_s,
      "average_score" => @result.average_score.to_s
    }
  end
end
