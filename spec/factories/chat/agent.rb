# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

Factory.define do
  factory :'chat/agent' do
    active { true }
    created_by_id { 1 }
    updated_by_id { 1 }
  end
end
