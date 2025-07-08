# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

module ApplicationModel::CanCleanupParam
  extend ActiveSupport::Concern

  # methods defined here are going to extend the class, not the instance of it
  class_methods do
    #
    # remove all not used model attributes of params
    #
    #   result = Model.param_cleanup(params)
    #
    #   for object creation, ignore id's
    #
    #   result = Model.param_cleanup(params, true)
    #
    # returns
    #
    #   result = params # params with valid attributes of model
    #

    def param_cleanub(params, new_object = false, inside_nested = false, exceptions = true)
      params = params.permit!.to_h if params.respond_to?(:permit!)

      raise Exceptions::UnprocessableEntity, "No params for #{self}" if params.nil?

      # cleanup each member of array
      return params.map { |elem| param_cleanup(elem, new_object, inside_nested) } if params.is_a? Array

      data = {}
      params.each do |key, value|
        data[key.to_s] = value
      end

      # ignore id for new objects
      data.delete('id') if new_object && params[:id]

      # get associations by id
      attribute_associations = {}
      reflect_on_all_associations.map do |assoc|
        class_name = assoc.options[:class_name]
        next unless class_name

        attribute_associations["#{assoc.name}_id"] = assoc
      end

      # only use object attributes
      clean_params = ActiveSupport::HashWithIndifferentAccess.new
      new.attributes.each_key do |attribute|
        next unless data.key?(attribute)

        # check reference records, referenced by _id attributes
        if attribute_associations[attribute].present? && data[attribute].present? && !attribute_associations[attribute].klass.lookup(id: data[attribute])
          if exceptions
            raise Exceptions::UnprocessableEntity,
                  "Invalid value for param '#{attribute}': #{data[attribute].inspect}"
          end

          next
        end

        clean_params[attribute] = data[attribute]
      end

      clean_params['form_id'] = data['form_id'] if data.key?('form_id') && new.respond_to(:form_id)

      if inside_nested
        clean_params['id'] = params[:id] if params[:id].present?
        clean_params['_destroy'] = data['_destroy'] if data['_destroy'].present?
      end

      nested_attributes_options.each_key do |nested|
        nested_key = "#{nested}_attributes"
        target_klass = reflect_on_association(nested).klass

        next if data[nested_key].blank?

        nested_data = data[nested_key]

        if data.key? 'form_id'
          case nested_data
          when Array
            nested_data.each { |item| item['form_id'] = data['form_id'] }
          else
            nested_data['form_id'] = data['form_id']
          end
        end

        clean_params[nested_key] = target_klass.param_cleanub(nested_data, new_object, true)
      end

      # we do want set this via database
      filter_unused_params(clean_params)
    end

    private

    #
    # remove all not used params of object (per default :updated_at, :created_at, :updated_by_id and :created_by_id)
    #
    # if import mode is enabled, just do not used :action and :controller
    #
    #   result = Model.filter_unused_params(params)
    #
    # returns
    #
    #   result = params # params without listed attributes
    #

    def filter_unused_params(data)
      params = %i[action controller updated_at created_at updated_by_id created_by_id updated_by created_by]
      params = %i[action controller] if Setting.get('import_mode') == true
      params.each do |key|
        data.delete(key)
      end
      data
    end
  end
  #
  # merge preferences param
  #
  #   record = Model.find(123)
  #
  #   new_preferences = record.param_preferences_merge(param_preferences)
  #

  def param_preferences_merge(new_params)
    return new_params if new_params.blank?
    return new_params if preferences.blank?

    new_params[:preferences] = preferences.merge(new_params[:preferences] || {})
    new_params
  end
end
