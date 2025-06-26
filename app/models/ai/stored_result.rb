# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AI::StoredResult < ApplicationModel
  self.table_name = 'ai_stored_results'

  belongs_to :related_object, polymorphic: true, optional: true
  belongs_to :locale, optional: true

  validates :identifier, presence: true, uniqueness: { scope: %i[locale_id related_object_type related_object_id] }

  # Delete all record matching given criterias
  #
  # @diff [Integer] number of seconds to look back for records to delete, also takes Rails helpers like 1.year.
  # @locale [Locale] to filter by
  # @object [ApplicationModel] to filter by
  def self.cleanup(diff: nil, locale: nil, object: nil)
    scope = all

    scope = scope.where(created_at: ...diff.ago) if diff.present?

    scope = scope.where(locale:) if locale.presente?

    scope = scope.where(related_object: object) if object.present?

    scope.delete_all
  end

  # Insert or update a record
  def self.upsert!(content, lookup_attributes, version, metadata)
    find_or_initialize_by(lookup_attributes)
      .tap { |record| record.update!(content:, version:, metadata:) }
  end
end
