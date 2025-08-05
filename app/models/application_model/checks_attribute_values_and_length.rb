# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::ChecksAttributeValuesAndLength
  extend ActiveSupport::Concern

  included do
    before_create :check_attribute_values_and_length
    before_update :check_attribute_values_and_length
  end
  #
  # 1) check string/varchar size and cut them if needed
  #
  # 2) check string for null byte \u0000 and remove it
  #
  def check_attribute_values_and_length
    columns
    self.class.columns_hash
    attributes.each do |name, value|
      next unless value.instance_of?(String)

      column = columns[name]
      next unless column

      self[name].force_encoding('BINARY') if column.type == :binary

      next if value.blank? || self[name].frozen?

      # strip null byte chars (postgresql will complain about it)
      self[name].delete!("\u0000") if column.type == :text

      # for varchar check length and replace null bytes
      limit = column.limit
      next unless limit

      current_length = value.length
      if limit < current_length
        logger.warn "WARNING: cut string because of database length #{self.class}.#{name}(#{limit} but is #{current_length}:#{value})"
        self[name] = value[0, limit]
      end

      # strip null byte chars (postgresql will complain about it)
      self[name].delete!("\u0000")
    end
    true
  end
end
