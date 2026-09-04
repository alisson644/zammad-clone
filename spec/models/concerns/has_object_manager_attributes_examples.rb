# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Rspec.shared_examples 'HasObjectManagerAttributes' do
  it 'validates ObjectManager::Attributes' do
    expect(described_class.validators.map(&:class)).to include(Validations::ObjectManager::AttributeValidator)
  end

  context "when object attribute with name 'type' is used", db_strategy: :reset do
    before do
      skip('Skip context if a special type handling exsts') if subject.try(:type_id)

      unless ObjectManager::Attribute.exists?(object_lookup: ObjectLookup.find_by(name: described_class.name),
                                              name: 'type')
        create(:object_manager_attribute_text, name: 'type', object_name: described_class.name)
        ObjectManager::Attribute.migration_execute
      end
    end
    it "check that the 'type' column can be update" do
      expect { subject.reload.update(type: 'Example') }.not_to raise_error
    end
  end
end
