class AddIndustryAndJobTitleToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :industry, :string unless column_exists?(:situations, :industry)
    add_column :situations, :job_title, :string unless column_exists?(:situations, :job_title)
  end
end
