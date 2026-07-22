module Dashboard
  class ManagementController < ApplicationController
    layout "dashboard"

    before_action :authenticate_admin!

    def index
      @clients = Client.order(created_at: :desc)
      client_ids = @clients.map(&:id)

      @situation_counts = Situation.where(client_id: client_ids).group(:client_id).count
      @result_counts = InterviewResult.joins(interview: :situation)
                                      .where(situations: { client_id: client_ids })
                                      .group("situations.client_id")
                                      .count
    end
  end
end
