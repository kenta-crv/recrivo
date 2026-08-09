# frozen_string_literal: true

class SituationFaqsController < Dashboard::BaseController
  before_action :set_situation
  before_action :set_faq, only: [:update, :destroy]

  def create
    faq = @situation.situation_faqs.new(faq_params)
    faq.position = (@situation.situation_faqs.maximum(:position) || 0) + 1
    if faq.save
      redirect_to @situation, notice: "FAQを追加しました"
    else
      redirect_to @situation, alert: faq.errors.full_messages.join(", ")
    end
  end

  def update
    if @faq.update(faq_params)
      redirect_to @situation, notice: "FAQを更新しました"
    else
      redirect_to @situation, alert: @faq.errors.full_messages.join(", ")
    end
  end

  def destroy
    @faq.destroy
    redirect_to @situation, notice: "FAQを削除しました"
  end

  private

  def set_situation
    @situation = situations_scope.find(params[:situation_id])
  end

  def set_faq
    @faq = @situation.situation_faqs.find(params[:id])
  end

  def faq_params
    params.require(:situation_faq).permit(:question, :answer, :category, :status, :position)
  end
end
