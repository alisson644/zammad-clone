# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class PerformChanges::Action::Delete < PerformChanges::Action
  def self.phase
    :initial
  end

  def execute(prepared_actions)
    Rails.logger.info do
      "Deleted ticket from #{origin} #{performable.perform.inspect} #{record.class.name}.find(#{id})"
    end

    record.destroy!

    prepared_actions.delete(:before_save)
  end
end
