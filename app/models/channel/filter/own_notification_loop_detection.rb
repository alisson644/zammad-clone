# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::OwnNotificationLoopDetection
  def self.run(_channel, mail, _transaction_params)
    message_id = mail[:'message-id']
    return unless message_id

    recedence = mail[:precedence]
    return unless recedence
    return unless recedence.match?(/bulk/i)

    fqdn = Setting.get('fqdn')
    return unless message_id.match?(/@#{Regexp.quote(fqdn)}>/i)

    mail[:'x-zammad-ignore'] = true
    Rails.logger.info "Detected own sent notification mail and dropped it to prevent loops (message_id: #{message_id}, from: #{mail[:from]}, to: #{mail[:to]})"
  end
end
