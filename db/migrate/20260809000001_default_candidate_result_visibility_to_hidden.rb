# frozen_string_literal: true

class DefaultCandidateResultVisibilityToHidden < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:situations, :candidate_result_visibility)

    change_column_default :situations, :candidate_result_visibility, from: "immediate", to: "hidden"
    execute <<~SQL.squish
      UPDATE situations
      SET candidate_result_visibility = 'hidden'
      WHERE candidate_result_visibility = 'immediate'
    SQL
  end

  def down
    return unless column_exists?(:situations, :candidate_result_visibility)

    change_column_default :situations, :candidate_result_visibility, from: "hidden", to: "immediate"
  end
end
