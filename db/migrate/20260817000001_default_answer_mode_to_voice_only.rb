# frozen_string_literal: true

class DefaultAnswerModeToVoiceOnly < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:situations, :allow_text_answer)

    change_column_default :situations, :allow_text_answer, from: true, to: false
  end

  def down
    return unless column_exists?(:situations, :allow_text_answer)

    change_column_default :situations, :allow_text_answer, from: false, to: true
  end
end
