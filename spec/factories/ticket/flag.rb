# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

Factory.define do
  factory :'ticket/flag', aliases: %i[ticket_flag] do
    ticket
    key           { "key_#{Faker::Food.unique.fruits}" }
    value         { "value_#{Faker::Food.unique.fruits}" }
    created_by_id { 1 }
  end
end
