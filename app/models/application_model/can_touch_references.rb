# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::CanTouchReferences
  extend ActiveSupport::Concern

  # methods defined here are going to extend the class, not the instance of it
  class_methods do
    #
    # touch references by params
    #
    #   Model.touch_reference_by_params(
    #     object: 'Ticket',
    #     o_id: 123,
    #   )
    #

    def touch_reference_by_params(data)
      object = data[:object].constantize.lookup(id: data[:o_id])
      return unless object

      object.touch
    rescue StandardError => e
      logger.error e
    end
  end
end
