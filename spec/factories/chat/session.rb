# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

Factory.define do
  factory :'chat/session' do
    chat_id { Chat.pluck(:id).sample }
  end
end
