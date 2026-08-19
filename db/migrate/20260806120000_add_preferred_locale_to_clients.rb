class AddPreferredLocaleToClients < ActiveRecord::Migration[6.1]
  def change
    return if column_exists?(:clients, :preferred_locale)

    add_column :clients, :preferred_locale, :string, null: false, default: "ja"
  end
end
