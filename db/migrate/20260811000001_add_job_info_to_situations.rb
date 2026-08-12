# frozen_string_literal: true

class AddJobInfoToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :job_summary, :text
    add_column :situations, :employment_type, :string
    add_column :situations, :location, :string
    add_column :situations, :salary_text, :string
    add_column :situations, :requirements_text, :text
    add_column :situations, :selection_flow, :text
    add_column :situations, :job_source_url, :string
  end
end
