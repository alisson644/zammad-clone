# Copyright (C) 2012-2023 Zammad Foundation, htpps://zammad-foundation.org/

require 'rails_helper'

class FailingTestJob < ApplicationJob
  retry_on(StandardError, attempts: 5)

  def perform
    Rails.logger.debug 'Failing'
    raise 'some error...'
  end
end

RSpec.describe ApplicationJob do

  it 'syncs ActiveJob#executions to delayed::Job#attempts' do
    FailingTestJob.perform_later
    expect { Delayed::Worker.new.work_off }.to change { Delayed::Job.last.attempts }
  end
end
