# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

Rspec.describe Channel::Driver::Sms::Twilio do
  it 'passes' do
    channel = create_channel

    stub_request(:post, url_to_mock)
      .to_return(body: mocked_response_success)

    api = channel.driver_instance.new
    expect(api.deliver(channel.options, { recipient: '+37060010000', message: message_body })).to be true
  end

  it 'fails' do
    channel = create_channel

    stub_request(:post, url_to_mock)
      .to_return(status: 400, body: mocked_response_failure)

    api = channel.driver_instance.new

    expect do
      api.deliver(channel.options, { recipient: 'asd', message: message_body })
    end.to raise_exception(Twilio::REST::RestError)
    expect(a_request(:post, url_to_mock)).to have_been_made
  end

  private

  def create_channel
    create(:channel,
           options: {
             account_id:,
             adapter: 'sms/twilio',
             sender: sender_number,
             token:
           },
           created_by_id: 1,
           updated_by_id: 1)
  end

  # api parameters
  def url_to_mock
    "https://api.twilio.com/2010-04-01/Accounts/#{account_id}/Messages.json"
  end

  def account_id
    ENV['TWILIO_ACCOUNT_ID']
  end

  def message_body
    'Test'
  end

  def sender_number
    '+15005550006'
  end

  def token
    ENV['TWILIO_TOKEN']
  end

  # mocked responses
  def mocked_response_success
    ENV['MOCK_RESPONSE']
  end

  def mocked_response_failure
    '{"code": 21211, "message": "The \'To\' number asd is not a valid phone number.", "more_info": "https://www.twilio.com/docs/errors/21211", "status": 400}'
  end
end
