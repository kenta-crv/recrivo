class AddJudgmentPublishAndResultVisibility < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :judgment_mode, :string, null: false, default: 'automatic'
    add_column :situations, :candidate_result_visibility, :string, null: false, default: 'immediate'

    add_column :questions, :published, :boolean, null: false, default: true
  end
end
