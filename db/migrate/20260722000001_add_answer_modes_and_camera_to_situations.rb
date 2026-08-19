class AddAnswerModesAndCameraToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :allow_text_answer, :boolean, default: true, null: false unless column_exists?(:situations, :allow_text_answer)
    add_column :situations, :allow_voice_answer, :boolean, default: true, null: false unless column_exists?(:situations, :allow_voice_answer)
    add_column :situations, :record_camera, :boolean, default: false, null: false unless column_exists?(:situations, :record_camera)
  end
end
