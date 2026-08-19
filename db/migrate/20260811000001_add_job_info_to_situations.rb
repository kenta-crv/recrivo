# frozen_string_literal: true

class AddJobInfoToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :job_summary, :text unless column_exists?(:situations, :job_summary)
    add_column :situations, :employment_type, :string unless column_exists?(:situations, :employment_type)
    add_column :situations, :location, :string unless column_exists?(:situations, :location)
    add_column :situations, :salary_text, :string unless column_exists?(:situations, :salary_text)
    add_column :situations, :requirements_text, :text unless column_exists?(:situations, :requirements_text)
    add_column :situations, :selection_flow, :text unless column_exists?(:situations, :selection_flow)
    add_column :situations, :job_source_url, :string unless column_exists?(:situations, :job_source_url)
  end
end
