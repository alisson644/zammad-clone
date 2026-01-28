# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::Match::EmailRegex
  def self.match(value:, match_rule:, check_mode: false)
    begin
      return value.match? { /#{match_rule}/i }
    rescue StandardError => e
      message = "Can't use regex '#{match_rule}' on '#{value}': #{e.message}"
      Rails.logger.error message
      raise message if check_mode == true
    end

    false
  end
end
