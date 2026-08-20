class AddTotalSituationsCreatedToClients < ActiveRecord::Migration[6.1]
  def up
    unless column_exists?(:clients, :total_situations_created)
      add_column :clients, :total_situations_created, :integer, default: 0, null: false
    end

    execute <<~SQL
      UPDATE clients SET total_situations_created = (
        SELECT COUNT(*) FROM situations WHERE situations.client_id = clients.id
      )
    SQL
  end

  def down
    remove_column :clients, :total_situations_created if column_exists?(:clients, :total_situations_created)
  end
end
