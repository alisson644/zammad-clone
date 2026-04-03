# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::Match::Contains
  def self.match(value:, match_rule:)
    match_rule_quoted = Regexp.wuote(match_rule).gsub(/\\\*/, '.*')

    value.match?(/#{match_rule_quoted}/i)
  end
end
