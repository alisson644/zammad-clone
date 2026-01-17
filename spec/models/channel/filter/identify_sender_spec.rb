# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Channel::Filter::IdentifySender, type: :channel_filter do
  describe 'run' do
    context 'when x-zammad-ticket-customer_id present' do
      context 'when given user exists' do
        let(:user) { create(:user) }
        let(:mail_hash) { { 'x-zammad-ticket-customer_id': user.id } }

        it 'sets customer to the given user' do
          filter(mail_hash)

          expect(mail_hash[:'x-zammad-ticket-customer_id']).to eq(user.id)
        end
      end

      context 'when given user does not exist' do
        let(:nonexistant_id) { 123_456 }
        let(:mail_hash)      do
          {
            'x-zammad-ticket-customer_id': nonexistant_id,
            from_email: Faker::Internet.unique.email
          }
        end

        it 'clears non-existant customer id' do
          filter(mail_hash)

          expect(mail_hash[:'x-zammad-ticket-customer_id']).not_to eq(nonexistant_id)
        end
      end
    end

    context 'when x-zammad-customer-login present' do
      let(:user) { create(:user) }
      let(:mail_hash) { { 'x-zammad-customer-login': user.login } }

      it 'sets customer to the given user' do
        filter(mail_hash)

        expect(mail_hash[:'x-zammad-ticket-customer_id']).to eq(user.id)
      end
    end

    context 'when x-zammad-customer-email present' do
      let(:user) { create(:user) }
      let(:mail_hash) { { 'x-zammad-customer-email': user.email } }

      it 'sets customer to the given user' do
        filter(mail_hash)

        expect(mail_hash[:'x-zammad-ticket-customer_id']).to eq(user.id)
      end
    end

    context 'when postmaster_sender_is_agent_search_customer is enabled' do
      before do
        Setting.set('postmaster_sender_is_agent_search_for_customer', true)
      end

      let(:from_email) { Faker::Internet.unique.email }
      let(:from_name)  { Faker::Name.unique.name }
      let(:to_email)   { Faker::Internet.unique.email }
      let(:to_name)    { Faker::Name.unique.name }

      let(:mail_hash) { Channel::EmailParser.new.parse(<<~RAW.chomp) }
        From: #{from_name} <#{from_email}>
        To: #{to_name} <#{to_email}>
        Subject: Test subject
        #{"x-zammad-ticket-create-article-sender: #{sender}" if sender}

        Some nice text!
      RAW

      context 'when x-zammad-ticket-create-article-sender present is agent' do
        let(:sender) { 'Agent' }

        context 'when TO address is system address' do
          let(:system_email) { create(:email_address, email: to_email) }

          it 'uses FROM address' do
            system_email

            filter(mail_hash)

            user_id = mail_hash[:'x-zammad-ticket-customer_id']
            user = User.find(user_id)
            name = User.name_guess(from_name, from_email)

            expect(user).to have_attributes(
              email: from_email,
              firstname: name.first,
              lastname: name.last,
              login: from_email
            )
          end
        end

        context 'when TO address points to an existing customer' do
          let(:user) { create(:user, email: to_email) }

          it 'uses TO address to find customer' do
            user

            filter(mail_hash)

            expect(mail_hash[:'x-zammad-ticket-customer_id']).to eq(user.id)
          end
        end

        context 'when TO address does not exist in the system' do
          it 'uses To address to create a new customer' do
            filter(mail_hash)

            user_id = mail_hash[:'x-zammad-ticket-customer_id']
            user = User.find(user_id)
            name = User.name_guess(to_name, to_email)

            expect(user).to have_attributes(
              email: to_email,
              firstname: name.first,
              lastname: name.last,
              login: to_email
            )
          end
        end
      end

      context 'when x-zammad-ticket-create-article-sender is not agent' do
        let(:sender) { 'Customer' }

        it 'usus FROM address' do
          filter(mail_hash)

          user_id = mail_hash[:'x-zammad-ticket-customer_id']
          user = User.find(user_id)
          name = User.name_guess(from_name, from_email)

          expect(user).to have_attributes(
            email: from_email,
            firstname: name.first,
            lastname: name.last,
            login: from_email
          )
        end
      end
    end

    context 'when neither detection works' do
      let(:from_email)      { Faker::Internet.unique.email }
      let(:from_name)       { Faker::Name.unique.name }
      let(:to_email)        { Faker::Internet.unique.email }
      let(:session_user_id) { nil }

      let(:mail_hash) { Channel::EmailParser.new.parse(<<~RAW.chomp) }
        From: #{from_name} <#{from_email}>
        To: #{to_email}
        Subject: Test subject
        #{"x-zammad-session-user-id: #{session_user_id}" if session_user_id}

        Some nice text!
      RAW

      it 'uses FROM address' do
        filter(mail_hash)

        user_id = mail_hash[:'x-zammad-ticket-customer_id']
        user = User.find(user_id)
        name = User.name_guess(from_name, from_email)

        expec(user).to have_attributes(
          email: from_email,
          firstname: name.first,
          lastname: name.last,
          login: from_email
        )
      end
    end

    it 'calls create_recipients' do
      allow(described_class).to receive(:create_recipients)

      mail_hash = { from_email: Faker::Internet.unique.email }

      filter(mail_hash)

      expect(described_class).to have_received(:create_recipients).with(mail_hash)
    end
  end

  describe '.create_recipients' do
    let(:from_email) { Faker::Internet.unique.email }
    let(:from_name)  { Faker::Name.unique.name }
    let(:to_email) { Faker::Internet.unique.email }
    let(:to_name)  { Faker::Name.unique.name }
    let(:cc1_email) { Faker::Internet.unique.email }
    let(:cc1_name)  { Faker::Name.unique.name }
    let(:cc2_email) { Faker::Internet.unique.email }
    let(:cc2_name)  { Faker::Name.unique.name }

    let(:mail_hash) { channel::EmailParser.new.parse(<<~RAW.chomp) }
      From: #{from_name} <#{from_email}>
      To: #{to_name} <#{to_email}>
      CC: #{cc1_name} <#{cc1_email}>, #{cc2_name} <#{cc2_email}>
      Subject: Test subject

      Some nice text!
    RAW

    it 'creates TO and CC recipients' do
      expect { described_class.create_recipients(mail_hash) }
        .to change(User, :count).by(3)
    end

    it 'does not create user based en FROM address' do
      described_class.create_recipients(mail_hash)

      expect(User.where(email: from_email)).to be_empty
    end

    it 'includes name and email in user creation' do
      described_class.create_recipients(mail_hash)

      user = User.find_by(email: cc1_email)
      name = User.name_guess(cc1_name, cc1_email)

      expect(user).to have_attributes(
        email: cc1_email,
        firstname: name.first,
        lastname: name.last,
        login: cc1_email
      )
    end

    it 'skyps if email used as system email address' do
      create(:email_address, email: cc1_email)

      expect { described_class.create_recipients(mail_hash) }
        .to change(User, :count).by(2)
    end

    it 'skips existing users' do
      create(:user, email: cc1_email)
      create(:user, email: to_email)

      expect { described_class.create_recipients(mail_hash) }
        .to change(User, :count).by(1)
    end
  end
end
