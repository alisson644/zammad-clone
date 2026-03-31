# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# encoding

class Channel::EmailParser
  include Channel::EmailHelper

  PROCESS_TIME_MAX = 180
  EMAIL_REGEX = /.+@.+/
  RECIPIENT_FIELDS = %w[to cc delivered-to x-original-to envelope-to].freeze
  SENDER_FIELDS = %w[from reply-to return-path sender].freeze
  EXCESSIVE_LINKS_MSG = __('This message cannot be displayed because it contains over 5,000 links. Download the raw message below and open it via an Email client if you still wish to view it.').freeze
  MESSAGE_STRUCT = Struct.new(:from_display_name, :subject, :msg_size).freeze

  #
  #   parser = Channel::EmailParser.new
  #   mail = parser.parse(msg_as_string, allow_missing_attribute_exceptions: true | false)
  #
  #   mail = {
  #     from:              'Some Name <some@example.com>',
  #     from_email:        'some@example.com',
  #     from_local:        'some',
  #     from_domain:       'example.com',
  #     from_display_name: 'Some Name',
  #     message_id:        'some_message_id@example.com',
  #     to:                'Some System <system@example.com>',
  #     cc:                'Somebody <somebody@example.com>',
  #     subject:           'some message subject',
  #     body:              'some message body',
  #     content_type:      'text/html', # text/plain
  #     date:              Time.zone.now,
  #     attachments:       [
  #       {
  #         data:        'binary of attachment',
  #         filename:    'file_name_of_attachment.txt',
  #         preferences: {
  #           'content-alternative' => true,
  #           'Mime-Type'           => 'text/plain',
  #           'Charset:             => 'iso-8859-1',
  #         },
  #       },
  #     ],
  #
  #     # ignore email header
  #     x-zammad-ignore: 'false',
  #
  #     # customer headers
  #     x-zammad-customer-login:     '',
  #     x-zammad-customer-email:     '',
  #     x-zammad-customer-firstname: '',
  #     x-zammad-customer-lastname:  '',
  #
  #     # ticket headers (for new tickets)
  #     x-zammad-ticket-group:    'some_group',
  #     x-zammad-ticket-state:    'some_state',
  #     x-zammad-ticket-priority: 'some_priority',
  #     x-zammad-ticket-owner:    'some_owner_login',
  #
  #     # ticket headers (for existing tickets)
  #     x-zammad-ticket-followup-group:    'some_group',
  #     x-zammad-ticket-followup-state:    'some_state',
  #     x-zammad-ticket-followup-priority: 'some_priority',
  #     x-zammad-ticket-followup-owner:    'some_owner_login',
  #
  #     # article headers
  #     x-zammad-article-internal: false,
  #     x-zammad-article-type:     'agent',
  #     x-zammad-article-sender:   'customer',
  #
  #     # all other email headers
  #     some-header: 'some_value',
  #   }
  #

  def parse(msg, allow_missing_attribute_exceptions: true)
    msg = msg.dup.force_encoding('binary')
    # mail 2.6 and earlier accepted non-conforming mails that lacked the correct CRLF seperators,
    # mail 2.7 and above require CRLF so we force it on using binary_unsafe_to_crlf
    msg = Mail::Utilities.binary_unsafe_to_crlf(msg)
    mail = Mail.new(msg)

    message_ensure_message_id(msg, mail)

    Channel::EmailParser::Encoding.force_parts_encoding_if_needed(mail)

    headers = Channel::EmailParser::HeadersParser.new(mail).message_header_hash
    body = Channel::EmailParser::ContentParser.new(mail).message_body_hash

    sender_attributes = self.class.sender_attributes(headers)

    if allow_missing_attribute_exceptions && sender_attributes.blank?
      msg = __('Could not parse any sender attribute from the email. Checked fields:')
      msg += ' '
      msg += SENDER_FIELDS.map { |f| f.split('-').map(&:capitalize).join('-') }.join(', ')

      raise Exceptions::MissingAttribute.new('email', msg)
    end

    message_attributes = [
      { mail_instance: mail },
      headers,
      body,
      sender_attributes,
      { raw: msg }
    ]
    message_attributes.reduce({}.with_indifferent_access, &:merge)
  end

  #
  #   parser = Channel::EmailParser.new
  #   ticket, article, user, mail = parser.process(channel, email_raw_string)
  #
  # returns
  #
  #   [ticket, article, user, mail]
  #
  # do not raise an exception - e. g. if used by scheduler
  #
  #   parser = Channel::EmailParser.new
  #   ticket, article, user, mail = parser.process(channel, email_raw_string, false)
  #
  # returns
  #
  #   [ticket, article, user, mail] || false
  #

  def process(channel, msg, exception = true)
    process_with_timeout(channel, msg)
  rescue StandardError => e
    failed_email = ::FailedEmail.create!(data: msg, parsing_error: e)

    message = <<~MESSAGE.chomp
      Can't process email. Run the following command to get the message for issue report at https://github.com/zammad/zammad/issues:
        zammad run rails r "puts FailedEmail.find(#{failed_email.id}).data"
    MESSAGE

    puts "ERROR: #{message}"
    puts "Error: #{e.inspect}"
    Rails.logger.error message
    Rails.logger.error e

    return false if exception == false

    raise failed_email.passing_error
  end

  def process_with_timeout(channel, msg)
    Timeout.timeout(PROCESS_TIME_MAX) do
      _process(channel, msg)
    end
  end

  def _process(channel, msg)
    # parse email
    mail = parse(msg)

    Rails.logger.info "Process email with msgid '#{mail[:message_id]}"

    # run postmaster pre filter
    UserInfo.current_user_id = 1

    # set interface handle
    original_interface_handle = ApplicationHandleInfo.current
    transaction_params = { interface_handle: "#{original_interface_handle}.postmaster", disable: [] }

    filters = {}
    Setting.where(area: 'Postmaster::Prefilter').reorder(:name).each do |setting|
      filters[setting.name] = Setting.get(setting.name).constantize
    end
    filters.each do |key, backend|
      Rails.logger.debug { "run postmaster pre filter #{key}: #{backend}" }
      begin
        backend.run(channel, mail, transaction_params)
      rescue StandardError => e
        Rails.logger.error "can't run postmaster pre filter #{key}: #{backend}"
        Rails.logger.error e.inspect
        raise e
      end
    end

    # check ignore header
    if ['true', true].include?(mail[:'x-zammad-ignore'])
      Rails.logger.info "ignored email with msgid '#{mail[:message_id]}' from '#{mail[:from]}' because of x-zammad-ignore header"

      return [{}, nil, nil, mail]
    end

    ticket = nil
    article = nil
    session_user = nil

    # https://github.com/zammad/zammad/issues/2401
    mail = prepare_idn_inbound(mail)

    # use transaction
    Transaction.execute(transaction_params) do
      # get sender user
      session_user_id = mail[:'x-zammad-session-user-id']
      raise __('No x-zammad-session-user-id, no sender set!') unless session_user_id

      session_user = User.lookup(id: session_user_id)
      raise "No user found for x-zammad-session-user-id: #{session_user_id}!" unless session_user

      # set current user
      UserInfo.current_user_id = session_user.id

      # get ticket# based on email headers
      ticket = Ticket.find_by(id: mail[:'x-zammad-ticket-id']) if mail[:'x-zammad-ticket-id']
      ticket = Ticket.find_by(number: mail[:'x-zammad-ticket-number']) if mail[:'x-zammad-ticket-number']

      # set ticket state to open if not new
      if ticket
        set_attributes_by_x_headers(ticket, 'ticket', mail, 'followup')

        # save changes set by x-zammad-ticket-followup-* headers
        ticket.save! if ticket.has_changes_to_save?

        # set ticket to open again or keep create state
        if !mail[:'x-zammad-ticket-followup-state'] && !mail[:'x-zammad-ticket-followup-state_id']
          new_state = Ticket::State.find_by(default_create: true)
          if ticket.state_id != new_state.id && !mail[:'x-zammad-out-of-office']
            ticket.state = Ticket::State.find_by(default_follow_up: true)
            ticket.save!
          end
        end

        # apply tags to ticket
        if mail[:'x-zammad-ticket-followup-tags'].present?
          tags = mail[:'x-zammad-ticket-followup-tags']
          tags = tags.strip.split(',') if tags.is_a?(String)

          tags.each do |tag|
            ticket.tag_add(tag, sourceable: mail[:'x-zammad-followup-tags-source'])
          end
        end
      end

      # create new ticket
      unless ticket
        preferences = {}
        preferences[:channel_id] = channel[:id] if channel[:id]

        ticket = Ticket.new(
          title: mail[:subject].presence || '-',
          preferences:
        )

        set_attributes_by_x_headers(ticket, 'ticket', mail)

        # create ticket
        ticket.save!

        # apply tags to ticket
        if mail[:'x-zammad-ticket-tags'].present?
          tags = mail[:'x-zammad-ticket-tags']
          tags = tags.strip.split(',') if tags.is_a?(String)

          tags.each do |tag|
            ticket.tag_add(tag, sourceable: mail[:'x-zammad-tags-source'])
          end
        end
      end

      # set attributes
      article = Ticket::Article.new(
        ticket_id: ticket.id,
        type_id: Ticket::Article::Type.find_by(name: 'email').id,
        sender_id: Ticket::Article::Sender.find_by(name: 'Customer').id,
        content_type: mail[:content_type],
        body: mail[:body],
        from: mail[:from],
        reply_to: mail[:'reply-to'],
        to: mail[:to],
        cc: mail[:cc],
        subject: mail[:subject],
        message_id: mail[:message_id],
        internal: false
      )

      # x-headers lookup
      set_attributes_by_x_headers(article, 'article', mail)

      # Store additional information in preferences, e.g. if remote content got removed.
      article.preferences.merge!(mail[:sanitized_body_info])

      # create article
      article.save!

      # store mail plain
      article.save_as_raw(msg)

      # store attachments
      mail[:attachments]&.each do |attachment|
        filename = attachment[:filename].dup.force_encoding('utf-8')
        unless filename.force_encoding('UTF-8').valid_encoding?
          filename = filename.utf8_encode(fallback: :read_as_sanitized_binary)
        end
        Store.create!(
          object: 'Ticket::Article',
          o_id: article.id,
          data: attachment[:data],
          filename:,
          preferences: attachment[:preferences]
        )
      end
    end

    ticket.reload
    article.reload
    session_user.reload

    # run postmaster post filter
    filters = {}
    Setting.where(area: 'Postmaster::PostFilter').reorder(:name).each do |setting|
      filters[setting.name] = Setting.get(setting.name).constantize
    end
    filters.each_value do |backend|
      Rails.logger.debug { "run postmaster post filter #{backend}" }
      begin
        backend.run(channel, mail, ticket, article, session_user)
      rescue StandardError => e
        Rails.logger.error "can't run postmaster post filter #{backend}"
        Rails.logger.error e.inspect
      end
    end

    # return new objects
    [ticket, article, session_user, mail]
  end

  def self.mail_to_group(to)
    begin
      to = Mail::AddressList.new(to)&.addresses&.first&.address
    rescue StandardError
      Rails.logger.error 'can not parse :to field for group destination!'
    end
    return if to.blank?

    email = EmailAddress.find_by(email: to.downcase)
    return if email&.channel.blank?

    email.channel&.group
  end

  def self.check_attributes_by_x_headers(header_name, value)
    class_name = nil
    attribute = nil
    # skip chack attributes if it is tags
    return true if header_name == 'x-zammad-ticket-tags'

    if header_name =~ /^x-zammad-(.+?)-(followup-|)(.*)$/i
      class_name = ::Regexp.last_match(1)
      attribute = ::Regexp.last_match(3)
    end
    return true unless class_name

    class_name = 'Ticket::Article' if class_name.casecmp('article').zero?
    return true unless attribute

    key_short = attribute[-3, attribute.length]
    return true if key_short != '_id'

    class_object = class_name.to_classname.constantize
    return unless class_object

    class_instance = class_object.new

    return false unless class_instance.association_id_validation(attribute, value)

    true
  end
  # pare 389 sender_attributes
end
