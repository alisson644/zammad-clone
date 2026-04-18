# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Chat::Session::Assets
  extend ActiveSupport::Concern

  #
  # get all assets / related models for this chat
  #
  #   chat = Chat::Session.find(123)
  #   result = Chat::Session.assets(assets_if_exists)
  #
  # returns
  #
  #   result = {
  #     users: {
  #       123: user_model_123,
  #       1234: user_model_1234,
  #     },
  #     chat_sessions: [ chat_session_model1 ]
  #   }
  #

  def assets(data)
    app_model_chat_session = Chat::Session.to_app_model

    data[app_model_chat_session] = {} unless data[app_model_chat_session]
    return data if data[app_model_chat_session][id]

    data[app_model_chat_session][id] = attributes_with_association_ids
    data[app_model_chat_session][id]['messages'] = []
    messages.each do |message|
      data[app_model_chat_session][id]['messages'].push message.attributes
    end
    data[app_model_chat_session][id]['tags'] = tag_list

    app_model_chat = Chat.to_app_model
    if !data[app_model_chat] || !data[app_model_chat][chat_id]
      chat = Chat.lookup(id: chat_id)
      data = chat.assets(data) if chat
    end

    app_model_user = User.to_app_model
    %w[created_by_id updated_by_id].each do |local_user_id|
      next unless self[local_user_id]
      next if data[app_model_user] && data[app_model_user][self[local_user_id]]

      user = User.lookup(id: self[local_user_id])
      next unless user

      data = user.assets(data)
    end
    data
  end
end
