# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Requires: let!(:group_relation_instance) { ... }
Rspec.shared_examples 'HasGroupRelationDefinition' do
  let(:group_relation_model_key) { group_relation_instance.model_name.element }

  context 'relation creation' do
    it 'refresh updated_at of related instances' do
      group = create(:group)

      travel 1.minute

      expect do
        described_class.create!(
          group_relation_model_key => group_relation_instance,
          group:
        )
      end.to change {
               group.reload.updated_at
             }.and(change do
                     group_relation_instance.reload.updated_at
                   end)
    end
  end

  context 'related instance deletion' do
    it 'refreshes updated_at of group instance' do
      group = create(:group)

      described_class.create!(
        group_relation_model_key => group_relation_instance,
        group:
      )

      travel 1.minute

      expect do
        group.destroy
      end.to(change do
        group_relation_instance.reload.updated_at
      end)
    end

    it 'refreshes updated_at of relation instance' do
      group = create(:group)

      described_class.create!(
        group_relation_model_key => group_relation_instance,
        group:
      )

      travel 1.minute

      expect do
        group_relation_instance.destroy
      end.to(change do
        group.reload.updated_at
      end)
    end
  end
end
