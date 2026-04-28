# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Checklist
  module Assets
    extend ActiveSupport::Concern

    def assets(data)
      app_model = self.class.to_app_model

      data[app_model] = {} unless data[app_model]
      return data if data[app_model][id]

      data[app_model][id]['ticket_inaccessible'] = true if ticket && !ticket.authorized_asset?

      items.each { |elem| elem.assets(data) }
      ticket.assets(data)

      data
    end
  end
end
