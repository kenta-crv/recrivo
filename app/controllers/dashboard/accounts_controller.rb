module Dashboard
  class AccountsController < Dashboard::BaseController
    before_action :authenticate_client!
    before_action :set_client

    def show
    end

    def update
      @client.assign_attributes(account_params)
      if @client.save(context: :profile_update)
        redirect_to dashboard_account_path, notice: "企業情報を更新しました。"
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_client
      @client = current_client
    end

    def account_params
      params.require(:client).permit(
        :company, :name, :tel, :address, :url, :email,
        :hire_email_subject, :hire_email_body,
        :reject_email_subject, :reject_email_body
      )
    end
  end
end
