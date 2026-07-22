class InterviewProductSchemaCleanup < ActiveRecord::Migration[6.1]
  def change
    if table_exists?(:situations)
      add_column :situations, :invite_token, :string unless column_exists?(:situations, :invite_token)
      remove_column :situations, :deal_id if column_exists?(:situations, :deal_id)
      remove_column :situations, :situation_type if column_exists?(:situations, :situation_type)
      add_index :situations, :invite_token, unique: true unless index_exists?(:situations, :invite_token)
    end

    add_column :users, :job_title, :string unless column_exists?(:users, :job_title)

    %w[
      follow_up_unsubscribes follow_up_deliveries
      deal_presentation_events deal_presentations deal_pages deal_segments
      deal_audios deal_documents deal_evaluations deal_faqs deal_follow_up_templates
      deal_speeches deal_summaries deal_transcripts deals user_progresses
    ].each do |table|
      drop_table table.to_sym if table_exists?(table)
    end
  end
end
