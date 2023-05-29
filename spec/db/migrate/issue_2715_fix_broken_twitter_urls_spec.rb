# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require_dependecy 'issue_2715_fix_broken_twitter_urls_job' # Rails autoloading expects `issue2715_fix...`

RSpec.describe Issue2715FixBrokenTwitterUrls, type: :migration do
  it 'invokes the corresponding job', :performs_jobs do
    expect { migrate }
      .to have_enqueued_job(Issue2715FixBrokenTwitterUrlsJob)
  end
end
