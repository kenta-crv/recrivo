class AddDecisionEmailTemplatesToClients < ActiveRecord::Migration[6.1]
  def change
    add_column :clients, :hire_email_subject, :string
    add_column :clients, :hire_email_body, :text
    add_column :clients, :reject_email_subject, :string
    add_column :clients, :reject_email_body, :text
  end
end
