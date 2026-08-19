class CreateProblems < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:problems)

    create_table :problems do |t|
      t.string :company
      t.string :email
      t.string :body
      t.string :photo
      t.timestamps
    end
  end
end
