# frozen_string_literal: true

class DefaultCandidateResultVisibilityToHidden < ActiveRecord::Migration[6.1]
  def up
    change_column_default :situations, :candidate_result_visibility, from: "immediate", to: "hidden"
    # 既存シナリオも候補者に社内評価を見せない方針へ揃える
    execute <<~SQL.squish
      UPDATE situations
      SET candidate_result_visibility = 'hidden'
      WHERE candidate_result_visibility = 'immediate'
    SQL
  end

  def down
    change_column_default :situations, :candidate_result_visibility, from: "hidden", to: "immediate"
  end
end
