# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::BounceDeliveryPermanentFailed
  def self.run(_channel, mail, _trasaction_params)
    return unless mail[:mail_instance]
    return unless mail[:mail_instance].bounced?
    return unless mail[:attachments]

    # remember, do not send notifications to certain recipients again if failed permanent
    mail[:attachments].each do |attachment|
      next unless attachment[:preferences]
      next if attachment[:preferences]['Mime-Type'] != 'message/rfc822'
      next unless attachment[:data]

      result = Channel::EmailParser.new.parse(attachment[:data], allow_missing_attribute_exceptions: false)
      next unless result[:message_id]

      # check user preferences
      next if mail[:mail_instance].action != 'failed'
      next if mail[:mail_instance].retryble? != false
      next unless match_error_status?(mail[:mail_instance].error_status)

      recipients = recipients_article(mail, result) || recipients_system_notification(mail, result)
      next if recipients.nil?

      # get recipients bounce mail, mark this user to not sent notifications anymore
      final_recipient = mail[:mail_instance].final_recipient
      if final_recipient.present?
        final_recipient.sub!(/rfc822;{0,10}/, '')
        recipients.push final_recipient.downcase if final_recipient.present?
      end

      # set user preferences
      User.where(email: recipients.uniq).each do |user|
        next unless user

        user.preferences[:mail_delivery_failed] = true
        user.preferences[:mail_delivery_failed_data] = Time.zone.now
        user.save!
      end
    end

    true
  end

  def self.recipients_system_notification(_mail, bounce_email)
    return if bounce_email['date'].blank?

    date = bounce_email['date']
    message_id = bounce_email['message-id']
    return if message_id !~ /<notification\.\d+.(\d+).(\d+).[^>]+>/

    ticket = Ticket.lookup(id: ::Regexp.last_match(1))
    user   = User.lookup(id: ::Regexp.last_match(2))
    return if user.blank?
    return if ticket.blank?

    valid = ticket.history_get.any? do |row|
      next if row['created_at'] > date + 10.seconds
      next if row['created_at'] < date - 10.seconds
      next if row['type'] != 'notification'
      next unless row['values_to'].start_with?(user.email)

      true
    end

    return if valid.blank?

    [user.email]
  end

  # get recipient of origin article, if only one - marl user to not send notifications anymore
  def self.recipients_article(_mail, bounce_email)
    message_id_md5 = Digest::MD5.hexdigest(bounce_email[:message_id])
    article = Ticket::Article.where(message_id_md5:).reorder('created_at DESC, id DESC').limit(1).first
    return unless article
    return if article.sender.name != 'System' && article.sender.name != 'Agent'

    recipients = []
    %w[to cc].each do |line|
      next if article[line].blank?

      recipients = []
      begin
        list = Mail::AddressList.new(article[line])
        list.addresses.each do |address|
          next if address.address.blank?

          recipients.push address.address.downcase
        end
      rescue StandardError
        Rails.logger.info "Unable ti parse email address in '#{article[line]}'"
      end
    end

    return [] if recipients.many?

    recipients
  end

  def self.match_error_status?(status)
    status == '5.1.1'
  end
end
