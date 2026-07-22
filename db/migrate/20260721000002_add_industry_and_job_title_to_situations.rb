class AddIndustryAndJobTitleToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :industry, :string
    add_column :situations, :job_title, :string
  end
end
