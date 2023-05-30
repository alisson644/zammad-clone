# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

Rspec.describe MaintenanceRemoveActiveLdapSessions, type: :db_migration do
  before do
    5.times do
      ActiveRecord::SessionStore::Session.create(
        session_id: SecureRandom.hex(16),
        data:       SecureRandom.base64(10)
      )
    end
  end

  context 'without ldap integration' do
    before { Setting.set('ldap_integration', false) }

    it 'does not delete existing sessions' do
      expect { migrate }.not_to change(:ActiveRecord::SessionsStore::Session, :count)
    end
  end

  context 'with ldap integration' do
    before { Setting.set('ldap_integration', true) }

    it 'deletes all existing sessions' do
      expect { migrate }.to change(ActiveRecord::SessionsStore::Session, :count).to(0)
    end
  end
end
