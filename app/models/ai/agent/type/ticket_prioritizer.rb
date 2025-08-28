# Copyright (C) 2012-2025 Zammad Foundation, https://zammad-foundation.org/

class AI::Agent::TicketPrioritizer < AI::Agent::Type
  def name
    __('Ticket Priorizer')
  end

  def description
    __('This type of AI agent can prioritize incoming tickets based on their content.')
  end

  def role_description
    'Your job is to analyze ticket content and assign ticket the most appropriate priority based on the topic and urgency.'
  end

  def form_schema
    [
      step: 'instruction_context',
      help: __('Choose which priorities will be considered when prioritizing tickets. If you want to limit it to specific priorities, please select at least two below. Make sure the priorities have clear names and optional descriptions, as that would comprise the context provided to the AI agent.'),
      fields: [
        {
          name: 'definition::instruction_context::object_attributes::priority_id',
          display: '',
          tag: 'object_attribute_options_context',
          default: {},

          limit_label: __('Limit Priorities'),
          limit_description: __('All priorities will be considered for prioritizing tickets.'),
          table_label: __('Available Priorities'),
          show_description: true,

          object_attribute_name: 'priority_id',
          object_attribute_object: 'Ticket'
        }
      ]
    ]
  end

  def instruction
    "Apply the following principles to identify the correct prioritization:

- Ignore irrelevant information (e.g. personal anecdotes, small talk, signatures, out-of-office notifications).
- Exclude segments that don't contribute any meaningful content (e.g. greetings, farewells).
- Do not insert personal opinions about the conversation or elaborate on the answer.
- Do not explain your given answer.
- Only answer with the value in the \"priority_id\" field inside the JSON structure."
  end

  def entity_context
    {
      object_attributes: ['title'],
      articles: 'last'
    }
  end

  def result_structure
    {
      priority_id: 'integer'
    }
  end

  def action_definition
    {
      mapping: {
        'ticket.priority_id' => {
          'value' => '#{ai_agent_result.priority_id}' # rubocop:disable Lint/InterpolationCheck
        }
      }
    }
  end
end
