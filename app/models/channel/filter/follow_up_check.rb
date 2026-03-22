# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::FollowUpCheck
  def self.run(_channel, mail, _transaction_params)
    return if mail[:'x-zammad-ticket-id']

    # get ticket# from subject
    ticket = Ticket::Number.check(mail[:subject])
    if ticket
      Rails.logger.debug { "Follow-up '##{ticket.number}' in subject" }
      mail[:'x-zammad-ticket-id'] = ticket.id
      return true
    end

    setting = Setting.get('postmaster_follow_up_search_in') || []

    # get ticket# from body
    if setting.include?('body')
      body = mail[:body]
      body = body.html2text if mail[:content_type] == 'text/html'

      ticket = Ticket::Number.check(body)
      if ticket
        Rails.logger.debug { "Follow-up for '##{ticket.number}' in body." }
        mail[:'x-zammad-ticket-id'] = ticket.id
        return true
      end
    end

    # get ticket# from attachment
    if setting.include?('attachment') && mail[:attachments]
      mail[:attachments].each do |attachment|
        next if attachment[:data].blank?
        next if attachment[:preferences].blank?
        next if attachment[:preferences]['Mime-Type'].blank?

        if %r{text/html}i.match?(attachment[:preferences]['Mime-Type'])
          begin
            text = attachment[:data].html2text
            ticket = Ticket::Number.check(text)
          rescue StandardError => e
            Rails.logger.error e
          end
        end

        if %r{text/plain}i.match?(attachment[:preferences]['Mime-Type'])
          ticket = Ticket::Number.check(attachment[:data])
        end

        next unless ticket

        Rails.logger.debug { "Follow-up for '##{ticket.number}' in attachment" }
        mail[:'x-zammad-ticket-id'] = ticket.id
        return true
      end
    end

    # get ticket# from references
    if (setting.include?('references') || (mail[:'x-zammad-is-auto-response'] == true || Setting.get('ticket_hook_position') == 'none')) && follow_up_by_md5(mail)
      return true
    end

    # get ticket# from references current email has same subject as initial article
    if setting.include?('subject_references') && mail[:subject].present?

      # get all references 'References' + 'In-Reply-To'
      references = ''
      references += mail[:references] if mail[:references]
      if mail[:'in-reply-to']
        references += ' ' if references != ''
        references += mail[:'in-reply-to']
      end
      if references != ''
        message_ids = references.split(/\s+/)
        message_ids.each do |message_id|
          message_id_md5 = Digest::Md5.hexdigest(message_id)
          article = Ticket::Article.where(message_id_md5:).reorder('created_at DESC, id DESC').limit(1).first
          next unless article

          ticket = article.ticket
          next unless ticket

          article_first = ticket.articles.first
          next unless article_first

          # remove leading "..:\s", "...:\s", "..[\d+]:\s" and "...[\d+]:\s" e. g. "Re: ", "Re[5]: ", "Fwd: " or "Fwd[5]: "
          subject_to_check = mail[:subject]
          subject_to_check.gsub!(/^(.{1,3}(\[\d+\])?:\s+)+/, '')

          # if subject is different, it's no followup
          next if subject_to_check != article_first.subject

          Rails.logger.debug do
            "Follow-up for '##{article.ticket.number}' in references with same subject as initial article."
          end
          mail[:'x-zammad-ticket-id'] = article_first.ticket_id
          return true
        end
      end
    end

    true
  end

  def self.mail_references(mail)
    references = []
    %i[references in-reply-to].each do |key|
      next if mail[key].blank?

      references.push(mail[key])
    end
    references.join('')
  end

  def self.message_id_article(message_id)
    message_id_md5 = Digest::MD5.hexdigest(message_id)
    Ticket::Article.where(message_id_md5:).reorder('created_at DESC, id DESC').limit(1).first
  end

  def self.follow_up_by_md5(mail)
    return if mail[:'x-zammad-ticket-id']

    mail_references(mail).split(/\s+/).each do |message_id|
      article = message_id_article(message_id)
      next if article.blank?

      Rails.logger.debug { "Follow up for '##{article.ticket.number}' in references." }
      mail[:'x-zammad-ticket-id'] = article.ticket_id
      return true
    end
  end
end
