# frozen_string_literal: true

class Dashboard::CandidateExperiencesController < Dashboard::BaseController
  def show
    situations = situations_scope
                   .active
                   .with_attached_recruitment_material
                   .includes(:situation_faqs, :questions)
                   .order(:title)

    experience = CandidateExperienceScore.for_situations(situations)
    @experience_score = experience[:average_score]
    @experience_items = experience[:items]
    @experience_gaps = experience[:items].flat_map(&:gaps)
    @situations_count = situations.size
  end

  private

  def situations_scope
    if admin_signed_in?
      Situation.all
    else
      current_client.situations
    end
  end
end
