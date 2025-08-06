# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module Application::HasExistsCheckByObjectAndId
  extend ActiveSupport::Concern

  class_methods do
    #
    # verify if referenced object exists
    #
    #   success = Model.exists_by_object_and_id('Ticket', 123)
    #
    # returns
    #
    #   # true or will raise an exception
    #

    def exists_by_object_and_id?(object, o_id)
      begin
        local_class = object.constantize
      rescue StandardError => e
        raise "Could not create an instance of '#{object}': #{e.inspect}"
      end
      unless local_class.exists?(o_id)
        raise ActiveRecord::RecordNotFound, "Unable for find reference object '#{object}.exists?(#{o_id})'"
      end

      true
    end
  end
end
