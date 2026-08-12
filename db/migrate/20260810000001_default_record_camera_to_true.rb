# frozen_string_literal: true

class DefaultRecordCameraToTrue < ActiveRecord::Migration[6.1]
  def up
    change_column_default :situations, :record_camera, from: false, to: true
  end

  def down
    change_column_default :situations, :record_camera, from: true, to: false
  end
end
