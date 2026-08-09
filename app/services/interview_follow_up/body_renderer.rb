# frozen_string_literal: true

module InterviewFollowUp
  class BodyRenderer
    include Rails.application.routes.url_helpers

    def initialize(delivery)
      @delivery = delivery
      @interview = delivery.interview
      @situation = @interview.situation
      @client = @situation.client
      @user = @interview.user
    end

    def subject
      render_template(@delivery.subject.presence || @delivery.interview_follow_up_template.subject)
    end

    def text_body
      body = render_template(@delivery.body.presence || @delivery.interview_follow_up_template.body)
      parts = [body]
      if include_next_step_link? && next_step_url.present?
        parts << ""
        parts << "次のステップ: #{next_step_url}"
      end
      parts << ""
      parts << "配信停止: #{unsubscribe_url}"
      parts.join("\n")
    end

    def html_body
      escaped = ERB::Util.html_escape(render_template(@delivery.body.presence || @delivery.interview_follow_up_template.body))
                       .gsub(/\r\n|\r|\n/, "<br>\n")
      html = +"<p>#{escaped}</p>"
      if include_next_step_link? && next_step_url.present?
        html << %(<p><a href="#{ERB::Util.html_escape(tracked_next_step_url)}">次のステップを確認する</a></p>)
      end
      html << %(<p style="color:#64748b;font-size:12px"><a href="#{ERB::Util.html_escape(unsubscribe_url)}">配信停止</a></p>)
      html << %(<img src="#{ERB::Util.html_escape(open_pixel_url)}" width="1" height="1" alt="" style="display:none" />)
      html.html_safe
    end

    private

    def variables
      {
        "candidate_name" => @user&.name.presence || "候補者",
        "candidate_email" => @user&.email.to_s,
        "company" => @client&.company.presence || @client&.name.to_s,
        "situation_title" => @situation.title.to_s,
        "invite_url" => invite_url,
        "average_score" => average_score.to_s
      }
    end

    def render_template(template)
      rendered = template.to_s.dup
      variables.each { |key, value| rendered = rendered.gsub("{{#{key}}}", value.to_s) }
      rendered
    end

    def include_next_step_link?
      @delivery.interview_follow_up_template.include_next_step_link?
    end

    def next_step_url
      @situation.follow_up_next_step_url.presence
    end

    def tracked_next_step_url
      "#{app_origin}/follow_up/c/#{@delivery.next_step_token}"
    end

    def open_pixel_url
      "#{app_origin}/follow_up/o/#{@delivery.tracking_token}"
    end

    def unsubscribe_url
      "#{app_origin}/follow_up/unsubscribe/#{@interview.ensure_follow_up_unsubscribe_token!}"
    end

    def invite_url
      "#{app_origin}/i/#{@situation.invite_token}"
    end

    def app_origin
      default_url_options = Rails.application.config.action_mailer.default_url_options || {}
      host = default_url_options[:host].presence || "localhost:3000"
      protocol = default_url_options[:protocol].presence || "http"
      "#{protocol}://#{host}"
    end

    def average_score
      data = @interview.interview_result&.results_data
      data = JSON.parse(data) rescue data if data.is_a?(String)
      return nil unless data.is_a?(Hash)

      data["average_score"] || data[:average_score]
    end
  end
end
