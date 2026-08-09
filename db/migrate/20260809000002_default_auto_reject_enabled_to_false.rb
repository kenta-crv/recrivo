# frozen_string_literal: true

class DefaultAutoRejectEnabledToFalse < ActiveRecord::Migration[6.1]
  def up
    change_column_default :situations, :auto_reject_enabled, from: true, to: false
  end

  def down
    change_column_default :situations, :auto_reject_enabled, from: false, to: true
  end
end
