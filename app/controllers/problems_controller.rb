class ProblemsController < ApplicationController
  helper DashboardHelper
  before_action :authenticate_problem_reporter!, only: [:new, :create]
  layout :problems_layout

  def index
    @problems = Problem.order(created_at: "DESC").page(params[:page])
  end

  def new
    @problem = build_problem
  end

  def create
    @problem = Problem.new(problem_params)

    if @problem.save
      flash[:notice] = "報告完了しました"
      begin
        ProblemMailer.report_email(@problem).deliver
      rescue StandardError => e
        Rails.logger.error("[ProblemsController#create] mail failed: #{e.class}: #{e.message}")
      end
      redirect_to dashboard_index_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @problem = Problem.find(params[:id])
  end

  def edit
    @problem = Problem.find(params[:id])
  end

  def destroy
    @problem = Problem.find(params[:id])
    @problem.destroy
    redirect_to problems_path, alert: "削除しました"
  end

  def update
    @problem = Problem.find(params[:id])

    if @problem.update(problem_params)
      redirect_to root_path
    else
      render :edit
    end
  end

  private

  def problem_params
    params.require(:problem).permit(
      :company,
      :email,
      :body,
      :photo
    )
  end

  def problems_layout
    if action_name.in?(%w[new create])
      "dashboard"
    else
      layout_for_request
    end
  end

  def authenticate_problem_reporter!
    return if client_signed_in? || admin_signed_in?

    redirect_to new_client_session_path, alert: "ログインが必要です。"
  end

  def build_problem
    attrs = {}
    if client_signed_in?
      attrs[:company] = current_client.company
      attrs[:email] = current_client.email
    end
    Problem.new(attrs)
  end
end
