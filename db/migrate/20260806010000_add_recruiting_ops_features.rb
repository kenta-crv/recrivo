# frozen_string_literal: true

class AddRecruitingOpsFeatures < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :candidate_info_fields, :json, default: {} unless column_exists?(:situations, :candidate_info_fields)
    add_column :situations, :skip_candidate_registration, :boolean, default: false, null: false unless column_exists?(:situations, :skip_candidate_registration)
    add_column :situations, :follow_up_next_step_url, :string unless column_exists?(:situations, :follow_up_next_step_url)
    add_column :situations, :page_views_count, :integer, default: 0, null: false unless column_exists?(:situations, :page_views_count)
    add_column :situations, :enable_satisfaction_survey, :boolean, default: true, null: false unless column_exists?(:situations, :enable_satisfaction_survey)

    add_column :interviews, :preview, :boolean, default: false, null: false unless column_exists?(:interviews, :preview)
    add_column :interviews, :satisfaction_rating, :integer unless column_exists?(:interviews, :satisfaction_rating)
    add_column :interviews, :satisfaction_feedback, :text unless column_exists?(:interviews, :satisfaction_feedback)
    add_column :interviews, :follow_up_unsubscribe_token, :string unless column_exists?(:interviews, :follow_up_unsubscribe_token)
    add_column :interviews, :follow_up_unsubscribed_at, :datetime unless column_exists?(:interviews, :follow_up_unsubscribed_at)
    add_column :interviews, :ops_status, :string, default: "new", null: false unless column_exists?(:interviews, :ops_status)

    add_index :interviews, :preview unless index_exists?(:interviews, :preview)
    add_index :interviews, :follow_up_unsubscribe_token, unique: true unless index_exists?(:interviews, :follow_up_unsubscribe_token)
    add_index :interviews, :ops_status unless index_exists?(:interviews, :ops_status)

    # プレビューは同一ユーザー×シナリオで複数可。本番の一意制約はモデルで担保
    unique_user_situation = indexes(:interviews).find { |i| i.name == "index_interviews_on_user_and_situation" }
    if unique_user_situation&.unique
      remove_index :interviews, name: "index_interviews_on_user_and_situation"
      add_index :interviews, [:user_id, :situation_id],
                name: "index_interviews_on_user_and_situation"
    elsif unique_user_situation.nil?
      add_index :interviews, [:user_id, :situation_id],
                name: "index_interviews_on_user_and_situation"
    end

    unless table_exists?(:notifications)
      create_table :notifications do |t|
        t.references :client, null: false, foreign_key: true
        t.references :interview, foreign_key: true
        t.string :category, null: false, default: "general"
        t.string :title, null: false
        t.text :body
        t.boolean :read, default: false, null: false
        t.datetime :read_at
        t.timestamps
      end
      add_index :notifications, [:client_id, :read]
      add_index :notifications, [:client_id, :created_at]
    end

    unless table_exists?(:interview_events)
      create_table :interview_events do |t|
        t.references :interview, foreign_key: true
        t.references :situation, null: false, foreign_key: true
        t.string :event_type, null: false
        t.string :session_key
        t.integer :question_id
        t.json :metadata, default: {}
        t.boolean :preview, default: false, null: false
        t.timestamps
      end
      add_index :interview_events, [:situation_id, :event_type]
      add_index :interview_events, [:situation_id, :created_at]
      add_index :interview_events, :session_key
    end

    unless table_exists?(:situation_faqs)
      create_table :situation_faqs do |t|
        t.references :situation, null: false, foreign_key: true
        t.string :question, null: false
        t.text :answer, null: false
        t.string :category
        t.string :status, default: "approved", null: false
        t.integer :position, default: 0, null: false
        t.timestamps
      end
      add_index :situation_faqs, [:situation_id, :status]
    end

    unless table_exists?(:interview_follow_up_templates)
      create_table :interview_follow_up_templates do |t|
        t.references :situation, null: false, foreign_key: true
        t.integer :sequence, null: false
        t.string :kind, null: false, default: "completed"
        t.boolean :enabled, default: true, null: false
        t.integer :delay_days, default: 0, null: false
        t.string :subject, null: false
        t.text :body, null: false
        t.boolean :include_next_step_link, default: true, null: false
        t.timestamps
      end
      add_index :interview_follow_up_templates, [:situation_id, :kind, :sequence],
                unique: true,
                name: "index_follow_up_templates_on_situation_kind_sequence"
    end

    unless table_exists?(:interview_follow_up_deliveries)
      create_table :interview_follow_up_deliveries do |t|
        t.references :interview, null: false, foreign_key: true
        t.references :interview_follow_up_template, null: false, foreign_key: true,
                     index: { name: "index_follow_up_deliveries_on_template_id" }
        t.integer :sequence, null: false
        t.string :kind, null: false, default: "completed"
        t.string :status, null: false, default: "scheduled"
        t.string :subject
        t.text :body
        t.datetime :scheduled_at, null: false
        t.datetime :sent_at
        t.datetime :opened_at
        t.datetime :next_step_clicked_at
        t.string :tracking_token
        t.string :next_step_token
        t.string :error_message
        t.timestamps
      end
      add_index :interview_follow_up_deliveries, :status
      add_index :interview_follow_up_deliveries, :scheduled_at
      add_index :interview_follow_up_deliveries, :tracking_token, unique: true
      add_index :interview_follow_up_deliveries, :next_step_token, unique: true
      add_index :interview_follow_up_deliveries, [:interview_id, :kind]
    end

    unless table_exists?(:interview_follow_up_unsubscribes)
      create_table :interview_follow_up_unsubscribes do |t|
        t.references :interview, null: false, foreign_key: true
        t.string :token, null: false
        t.datetime :unsubscribed_at, null: false
        t.string :source
        t.string :ip
        t.string :user_agent
        t.timestamps
      end
      add_index :interview_follow_up_unsubscribes, :token, unique: true
    end
  end
end
