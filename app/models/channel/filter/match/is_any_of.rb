# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::Match::IsAnyOf
  def self.match(value:, match_rule:)
    match_rule.any?(value)
  end
end
