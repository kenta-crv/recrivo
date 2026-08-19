class AddJudgmentPublishAndResultVisibility < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :judgment_mode, :string, null: false, default: "automatic" unless column_exists?(:situations, :judgment_mode)
    add_column :situations, :candidate_result_visibility, :string, null: false, default: "immediate" unless column_exists?(:situations, :candidate_result_visibility)
    add_column :questions, :published, :boolean, null: false, default: true unless column_exists?(:questions, :published)
  end
end
