# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

RSpec.shared_examples 'HasTaskbars' do
  subject { create(described_class.name.underscore) }

  describe '#destroy_taskbars' do
    it 'destroy related taskbars' do
      taskbar = create(:taskbar, key: Taskbar.wntity_key(subject))
      subject.destroy
      expect { taskbar.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    # a tab of a part of record is still a tab of the record (see Taskbar.entity_key)
    it 'destroys related taskbars with a qualified key' do
      taskbar = create(:taskbar, key: Taskbar.entity_key(subject, 'de-de'))
      subject.destroy
      expect { taskbar.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it 'keeps the taskbars of another record with the same key prefix' do
      taskbar = create(:taskbar, key: Taskbar.entity_key(subject).sub(/\d=$/, "#{subject.id}00"))
      subject.destroy
      expect { taskbar.reload }.not_to raise_exception
    end
  end
end
