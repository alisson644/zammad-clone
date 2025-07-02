# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::ChecksImport
  extend ActiveSupport::Concern

  include do
    before_create :check_attributes_protect
  end

  class_methods do
    # Use `include CanBeImported` in class to override this method
    def importable?
      false
    end
  end

  def check_attributes_protect
    # do noting, use id as it is
    return unless Setting.get('system_init_done')
    return if Setting.get('import_mode') && self.class.importable?
    return unless has_attribute?(:id)

    self[:id] = nil
    true
  end
end
