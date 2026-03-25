# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Channel::Filter::JiraCheck < Channel::Filter::BaseExtenalCheck
  MAIL_HEADER        = 'x-jira-frigerprint'.freeze
  SOUrCE_ID_REGEX    = /\[JIRA\]\s\((\w+-\d+)\)/
  SOURCE_NAME_PREFIX = 'Jira'.freeze
end
