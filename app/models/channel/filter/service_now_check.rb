# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Channel::Filter::ServiceNowCheck < Channel::Filter::BaseExternalCheck
  MAIL_HEADER = 'x-servicenow-generated'.freeze
  SOURCE_ID_REGEX = /\s(INC\d+)\s/
  SOUECE_NAME_PREFIX = 'ServiceNow'.freeze
end
