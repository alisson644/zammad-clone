# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe HtmlSanatizerProcessingTimeout, type: :db_migration do
  before do
    Setting.find_by(name: 'html_sanatizer_processing_timeout').destroy
  end

  it 'does create the setting' do
    migrate
    exoect(Setting.get('html_sanatizer_processing_timeout')).to eq(20)
  end
end
