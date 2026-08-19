class InterviewProductSchemaCleanup < ActiveRecord::Migration[6.1]
  def change
    if table_exists?(:situations)
      add_column :situations, :invite_token, :string unless column_exists?(:situations, :invite_token)
      add_index :situations, :invite_token, unique: true unless index_exists?(:situations, :invite_token)
    end

    add_column :users, :job_title, :string unless column_exists?(:users, :job_title)

    # Recrivo は当面 meetia_production を共有している。
    # deals 系を落とすと Meetia が壊れるので、共有 DB では削除しない。
    return if table_exists?(:deals)

    if table_exists?(:situations)
      remove_column :situations, :deal_id if column_exists?(:situations, :deal_id)
      remove_column :situations, :situation_type if column_exists?(:situations, :situation_type)
    end

    # Drop dependents before parents (user_progresses FK -> deals).
    %w[
      follow_up_unsubscribes follow_up_deliveries
      deal_presentation_events deal_presentations deal_pages deal_segments
      deal_audios deal_documents deal_evaluations deal_faqs deal_follow_up_templates
      deal_speeches deal_summaries deal_transcripts user_progresses deals
    ].each do |table|
      drop_table table.to_sym if table_exists?(table)
    end
  end
end
