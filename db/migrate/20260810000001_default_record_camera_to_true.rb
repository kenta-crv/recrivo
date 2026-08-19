# frozen_string_literal: true

class DefaultRecordCameraToTrue < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:situations, :record_camera)

    change_column_default :situations, :record_camera, from: false, to: true
  end

  def down
    return unless column_exists?(:situations, :record_camera)

    change_column_default :situations, :record_camera, from: true, to: false
  end
end
