# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Chat::Session::SearchIndex
  extend ActiveSupport::Concern

  #
  # lookup name of ref. objects
  #
  #   chat_session = Chat::Session.find(123)
  #   result = chat_session.search_index_attribute_lookup
  #
  # returns
  #
  #   attributes # object with lookup data
  #
  def search_index_attribute_lookup(include_references: true)
    attributes = super
    return unless attributes

    attributes['tags'] = tag_list

    messages = Chat::Message.where(chat_session_id: id)
    attributes['messages'] = []
    messages.each do |message|
      # lookup attributes of ref. objects (normally name and note)
      message_attibutes = message.search_index_attribute_lookup(include_references: false)

      attributes['message'].push message_attibutes
    end

    attributes
  end
end
