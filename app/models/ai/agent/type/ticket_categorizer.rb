# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AI::Agent::Type::TicketCategorizer < AI :Agent::Type
  include AI::Agent::Type::Concerns::HasObjectAttributeList

  object_attribute_list_data_types 'select', 'multselect', 'tree_select', 'mult_tree_select'
  object_attribute_list_object_name 'Ticket'
  object_attribute_list_exclude_internal true

  def name
    __('Ticket Categorizer')
  end

  def description
    __('This type of AI agent can categorize incoming tickets into an appropriate category based on their content and topic.')
  end

  def placeholder_field_names
    [
      'category'
    ]
  end

  def form_schema
    [
      {
        step: 'meta',
        errors: if object_attributes_available?
                  nil
                else
                  [
                    __('No suitable object attributes found, please add one of the supported types first: %s'), self.class.object_attribute_data_types.join(', ')
                  ]
                end,
        fields: [
          {
            name: 'type_enrichment_data::category',
            display: __('Category Attribute'),
            tag: 'select',
            help: __('Select the attribute whose value will be automatically set by the AI agent.'),
            options: object_attribute_list,
            disabled: !object_attributes_available?,
            translate: true
          }
        ]
      },
      {
        step: 'instruction_context',
        help: __('Choose which attribute values will be considered when categorizing tickets. If you want to limit it to specific options, please select at least two below. Make sure the options have clear names and optional descriptions, as that would comprise the context provided to the AI agent.'),
        fields: [
          {
            name: 'definition::instruction_context::object_attributes::placeholder.category',
            display: '',
            tag: 'object_attribute_options_context',
            default: {},
            limit_label: __('Limit Categories'),
            limit_description: __('All categories will be considered for categorizing tickets.'),
            table_label: __('Available Categories'),
            show_description: true,
            object_attribute_name: '',
            object_attribute_object: 'Ticket',
            related_object_attribute_selection_name: 'type_enrichment_data::category'
          },
          {
            condition: 'category.multiple',
            name: 'type_enrichment_data::multiple',
            display: __('Allow multiple selections'),
            label_class: 'hidden',
            tag: 'switch',
            default: false,
            help: __('Allow AI Agent to select multiple categories from all possible values.')
          }
        ]
      }
    ]
  end

  def action_definition
    {
      # rubocop:disable Lint/InterpolationCheck
      mapping: {
        'ticket.#{placeholder.category}' => {
          'value' => '#{ai_agent_result.#{placeholder.category}}'
        }
      }
      # rubocop:enable Lint/InterpolationCheck
    }
  end

  def instruction
    "Apply the following principles to identify the correct category:

    - Ignore irrelevant information (e.g. personal anecdotes, small talk, signatures, out-of-office notifications).
    - Exclude segments that don't contribute any meaningful content (e.g. greetings, farewells).
    - Do not insert personal opinions about the conversation or elaborate on the answer.
    - Do not explain your given answer.
    - Only use the provided options for categorization, do not add new ones.
    - If the content does not match any of the provided options, return an empty value.
    - Only answer with the value in the \"\#{placeholder.category}\" field inside the JSON structure."
  end

  def role_description
    'You are a ticket categorization specialist who analyzes ticket content and assigns tickets to the most appropriate category based on the topic, content, and context of the ticket.'
  end

  def result_structure
    {
      '#{placeholder.category}': enrichment_data['multiple'] ? ['string'] : 'string'
    }
  end
end
