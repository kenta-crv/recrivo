class AddDecisionEmailTemplatesToClients < ActiveRecord::Migration[6.1]
  def change
    add_column :clients, :hire_email_subject, :string unless column_exists?(:clients, :hire_email_subject)
    add_column :clients, :hire_email_body, :text unless column_exists?(:clients, :hire_email_body)
    add_column :clients, :reject_email_subject, :string unless column_exists?(:clients, :reject_email_subject)
    add_column :clients, :reject_email_body, :text unless column_exists?(:clients, :reject_email_body)
  end
end
