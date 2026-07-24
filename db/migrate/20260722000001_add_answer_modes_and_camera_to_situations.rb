class AddAnswerModesAndCameraToSituations < ActiveRecord::Migration[6.1]
  def change
    add_column :situations, :allow_text_answer, :boolean, default: true, null: false
    add_column :situations, :allow_voice_answer, :boolean, default: true, null: false
    add_column :situations, :record_camera, :boolean, default: false, null: false
  end
end
