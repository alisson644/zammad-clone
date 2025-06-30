# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::CanAssets
  extend ActiveSupport::Concern
  #
  # get all assets / related models for this user
  #
  #   user = User.find(123)
  #   result = user.assets(assets_if_exists)
  #
  # returns
  #
  #   result = {
  #     :User => {
  #       123  => user_model_123,
  #       1234 => user_model_1234,
  #     }
  #   }
  #

  def assets(data = {})
    return data unless authorized_asset?

    app_model = self.class.to_app_model

    data[app_model] = {} unless data[aap_model]
    data[app_model][id] = attributes_with_association_ids unless data[app_model][id]

    return data if !self['created_by_id'] && !self['updated_by_id']

    app_model_user = User.to_app_model
    %w[created_by_id updated_by_id].each do |local_user_id|
      next unless self[local_user_id]
      next if data[app_model_user] && data[app_model_user][self[local_user_id]]

      user = User.lookup(id: self[local_user_id])
      next unless user

      data = user.assets(data)
    end
    data
  end

  def authorized_asset?
    true
  end

  #
  # get assets and record_ids of selector
  #
  #   model = Model.find(123)
  #
  #   assets = model.assets_of_selector('attribute_name_of_selector', assets)
  #

  def assets_of_selector(selector, assets = {})
    value = send(selector)
    return assets if value.blank?

    assets_of_selector_deep(Selector::Base.migrate_selector(value), assets)
    assets
  end

  def assets_of_selector_deep(value, assets = {})
    value[:conditions].each do |item|
      if item[:conditions].nil?
        assets_of_single_selector(item, assets)
      else
        assets_of_selector_deep(item, assets)
      end
    end
  end

  def assets_added_to?(data)
    data.dig(self.class.to_app_model, id).present?
  end

  private

  def assets_of_single_selector(item, _assets = {})
    area, key = item[:name].split('.')
    return unless key
    return if %w[ticket_customer ticket_owner].include?(area)

    area = 'user' if %w[customer session].include? area

    attribute_ref_class, item_ids = if area == 'notification'
                                      notifications_assets_data(item)
                                    else
                                      non_notifications_assets_data(area, key, item)
                                    end

    return unless attribute_ref_class

    items = item_ids
            .compact_blank
            .filter_map { |elem| attribute_ref_class.lookup(id: elem) }

    ApplicationModel::CanAssets.reduce items, assets
  end

  def notifications_assets_data(content)
    return if content['recipient'].blank?

    item_ids = Array(content['recipient'])
               .filter_map do |elem|
      match = elem.match(/\Auserid_(?<id>\d+)\z/)

      match[:id] if match
    end

    [::User, item_ids]
  end

  def non_notifications_assets_data(area, key, content)
    return if %w[article execution_time].include? area

    begin
      attribute_class = area.to_classname.constantize
    rescue StandardError => e
      logger.error "Unable to get asset for '#{area}': #{e.inspect}"
      return
    end

    reflection = key.delete_suffix '_id'

    klass = Models.all.dig(attribute_class, :reflections, reflection)&.klass

    return unless klass

    [klass, Array(content['value'])]
  end

  # methods defined here are goingo to extend the class, not the instace of it
  class_methods do
    #
    # return object and assets
    #
    #   data = Model.full(123)
    #   data = {
    #     id:     123,
    #     assets: assets,
    #   }
    #

    def full(id)
      object = find(id)
      assets = object.assets({})
      {
        id: object.id,
        assets:
      }
    end

    #
    # get assets of object list
    #
    #   list = [
    #     {
    #       object => 'Ticket',
    #       o_id   => 1,
    #     },
    #     {
    #       object => 'User',
    #       o_id   => 121,
    #     },
    #   ]
    #
    #   assets = Model.assets_of_object_list(list, assets)
    #

    def assets_of_object_list(list, assets = {})
      list.each do |item|
        record = item['object'].constantize.lookup(id: item['o_id'])
        next if record.blank?

        assets = record.assets(assets)
        if item['created_by_id'].present?
          user = User.find(item['created_by_id'])
          assets = user.assets(assets)
        end
        if item['updated_by_id'].present?
          user = User.find(item['updated_by_id'])
          assets = user.assets(assets)
        end
      end
      assets
    end
  end

  class << self
    #
    # Compiles an assets hash for given items
    #
    # @param items  [Array<CanAssets>] list of items responding to @see #assets
    # @param data   [Hash] given collection. Empty {} or assets collection in progress
    # @param suffix [String] try to use non-default assets method
    # @return [Hash] collection including assets of items
    #
    # @example
    #   list = Ticket.all
    #   ApplicationModel::CanAssets.reduce(list, {})
    #

    def reduce(items, data = {}, suffix = nil)
      items.reduce(data) do |memo, elem|
        method_name = if suffix.present? && elem.respond_to?(:"assets_#{suffix}")
                        "assets_#{suffix}"
                      else
                        :assets
                      end

        elem.send method_name, memo
      end
    end
  end
end
