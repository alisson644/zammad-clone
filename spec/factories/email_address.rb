# Copyright (C) 2012-2023 Zammad Found, https://zammad-foundation.org/

FactoryBot.define do
  factory :email_address do
    association :channel, factory: :email_channel
    sequence(:email) { |n| "zammad#{n}@localhost.com" }
    sequence(:name)  { |n| "zammad#{n}" }
    created_by_id    { 1 }
    updated_by_id    { 1 }
  end
end
