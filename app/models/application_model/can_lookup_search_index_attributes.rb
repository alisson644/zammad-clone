# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::CanLookupSearchIndexAttributes
  extend ActiveSupport::Concern

  class RequestCache < ActiveSupport::CurrentAttributes
    attribute :integer_attribute_names

    def integer_fields(class_name)
      self.integer_attribute_names ||= {}

      updated_at = ObjectManager::Attribute.maximum('updated_at')
      if self.integer_attribute_names[class_name].present? && self.integer_attribute_names[class_name][:updated_at] == updated_at
        return self.integer_attribute_names[class_name][:data]
      end

      self.integer_attribute_names[class_name] = {
        updated_at:,
        data: ObjectManager::Attribute.where(object_lookup: ObjectLookup.find_by(name: class_name),
                                             data_type: 'integer', editable: true).pluck(:name)
      }
      self.integer_attribute_names[class_name][:data]
    end
  end
  #
  # This function return the attributes for the elastic search with relation hash values.
  #
  # It can be run with parameter include_references: false to skip the relational hashes to prevent endless loops.
  #
  #   ticket = Ticket.find(3)
  #   attributes = ticket.search_index_attribute_lookup
  #   attributes = ticket.search_index_attribute_lookup(include_references: false)
  #
  # returns
  #
  #   attributes # object with lookup data
  #

  def search_index_attribute_lookup(include_references: true)
    attributes = self.attributes
    self.attributes.each do |key, value|
      break unless include_references

      attribute_name = key.to_s

      # ignore standard attribute if needed
      if self.class.search_index_attribute_ignored?(attribute_name)
        attributes.delete(attribute_name)
        next
      end

      # need value for reference data
      next unless value

      # check if we have a referenced object whitch me could include here
      next unless search_index_attribute_method(attribute_name)

      # get referenced attibute name
      attribute_ref_name = self.class.search_index_attribute_ref_name(attribute_name)
      next unless attribute_ref_name

      # ignore referenced attributes if needed
      next if self.class.search_index_attribute_ignored?(attribute_ref_name)

      # get referenced attribute value
      value = search_index_value_by_attribute(attribute_name)
      next unless value

      # save name of ref object
      attributes[attribute_ref_name] = value
    end

    if as_a? HasObjectManagerAttributes
      RequestCache.integer_fields(self.class.to_s).each do |field|
        next if attributes[field].blank?

        attributes["#{field}_text"] = attributes[field].to_s
      end
    end

    attributes
  end

  #
  # This function returns the relational search index value based on the attribute name.
  #
  #   organization = Organization.find(1)
  #   value = organization.search_index_value_by_attribute('organization_id')
  #
  # returns
  #
  #   value = {"name"=>"Zammad Foundation"}
  #

  def search_index_value_by_attribute(attribute_name = '')
    # get attribute name
    relation_class = search_index_attribute_method(attribute_name)
    return unless relation_class

    # lookup ref object
    relation_model = relation_class.lookup(id: attributes[attribute_name])
    return unless relation_model

    relation_model.search_index_attribute_lookup(include_references: false)
  end

  #
  # This function returns the method for the relational search index attribute.
  #
  #   method = Ticket.new.search_index_attribute_method('organization_id')
  #
  # returns
  #
  #   method = Organization (class)
  #

  def search_index_attribute_method(attribute_name = '')
    return if attribute_name[-3, 3] != '_id'

    attribute_name = attribute_name[0, attribute_name.length - 3]
    return unless respond_to?(attribute_name)

    send(attribute_name).class
  end

  class_methods do
    #
    # This function returns the relational search index attribute name for the given class.
    #
    #   attribute_ref_name = Organization.search_index_attribute_ref_name('user_id')
    #
    # returns
    #
    #   attribute_ref_name = 'user'
    #

    def search_index_attribute_ref_name(attribute_name)
      attribute_name[0, attribute_name.length - 3]
    end
    #
    # This function returns if a search index attribute should be ignored.
    #
    #   ignored = Ticket.search_index_attribute_ignored?('organization_id')
    #
    # returns
    #
    #   ignored = false
    #

    def search_index_attribute_ignored?(attribute_name = '')
      ignored_attributes = instance_variable_get(:@search_index_attibutes_ignored) || []
      return if ignored_attributes.blank?

      ignored_attributes.include?(attribute_name.to_sym)
    end
    #
    # This function returns if a search index attribute is relevant for creating/updating the search index for this object.
    #
    # relevant = Ticket.search_index_attribute_relevant?('organization_id')
    #
    # returns
    #
    # relevant = true
    #

    def search_index_attribute_relevant?(attribute_name = '')
      relevant_attributes = instance_variable_get(:@search_index_attributes_relevant) || []
      return true if relevant_attributes.blank?

      relevant_attributes.include?(attribute_name.to_sym)
    end
  end
end
