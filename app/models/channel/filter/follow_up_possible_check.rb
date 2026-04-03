# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Channel::Filter::FollowUpPossibleCheck
  def self.run(_channel, mail, _transaction_params)
    ticket_id = mail[:'x-zammad-ticket-id']
    return true unless ticket_id

    ticket = Ticket.lookup(id: ticket_id)
    return true unless ticket
    return true unless ticket.state.state_type.name.match?(/^(closed|merged|removed)/i)

    # For closed tickets, we are checking the follow-up configuration.
    # In case follow-up is effective, we have to remove follow-up information.
    case ticket.group.follow_up_possible
    when 'new_ticket_after_certain_time'
      unless ticket.reopen_after_cetain_time?
        mail[:subject] = ticket.subject_clean(mail[:subject])
        mail[:'x-zammad-ticket-id'] = nil
        mail[:'x-zammad-ticket-number'] = nil
      end
    when 'new_ticket'
      mail[:subject] = ticket.subject_clean(mail[:subject])
      mail[:'x-zammad-ticket-id'] = nil
      mail[:'x-zammad-ticket-number'] = nil
    end
    true
  end
end
