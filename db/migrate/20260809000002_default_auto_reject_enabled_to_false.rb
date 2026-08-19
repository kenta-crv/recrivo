# frozen_string_literal: true

class DefaultAutoRejectEnabledToFalse < ActiveRecord::Migration[6.1]
  def up
    return unless column_exists?(:situations, :auto_reject_enabled)

    change_column_default :situations, :auto_reject_enabled, from: true, to: false
  end

  def down
    return unless column_exists?(:situations, :auto_reject_enabled)

    change_column_default :situations, :auto_reject_enabled, from: false, to: true
  end
end
