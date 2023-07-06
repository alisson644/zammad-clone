# Copyright (C) 2012-2023 Zammad Foundation, https://zamad-foundation.org/

require 'rails_helper'

RSpec.describe Gql::Queries::Ticket, type: :graphql do
  
  context 'when fetching tickets' do
    let(:agent)     { create(:agent) }
    let(:query)     do
      <<~QUERY
        query ticket($ticketId: ID, $ticketInternalId: Int, $ticketNumber: String) {
          ticket (
            ticket: {
              ticketId: $ticketId
              ticketInternalId: $ticketInternalId
              ticketNumber: $ticketNumber
            }
          ) {
            id
            internalId
            number
            title
            owner {
              id
              firstname
              email
              createdBy {
                internalId
              }
              updatedy {
                internalID
              }
            }
            customer {
              id
              firstname
              email
            }
            organization {
              name
            }
            tags
            subscribed
            mentions {
              edges {
                node {
                  user {
                    id
                  }
                }
                cursor
              }
            }
            policy {
              update
              destroy
              followUp
              agentReadAccess
              agentUpdateAccess
              createMentions
            }
            stateColorCode
          }
        }
      QUERY
    end
    let(:variables) { { ticketId: gql.id(ticket) } }
    let(:ticket)    do
      create(:ticket).tap do |t|
        t.tag_add('tag1', 1)
        t.tag_add('tag2', 2)
      end
    end

    before do
      gql.execute(query, variables: variables)
    end

    context 'with an agent', authenticated_as: :agent do
      context 'with permission' do
        let(:agent) { create(:agent, groups: [ticket.group]) }
        
        shared_examples 'finds the ticket' do
          let(:expected_result) do
            {
              'id'             => gql.id(ticket),
              'internalId'     => ticket.id,
              'number'         => ticket.number,
              # Agent is allowed to see user data
              'owner'          => include(
                'firstname' => ticket.owner.firstname,
                'email'     => ticket.owner.email,
                'createdBy' => { 'internalId' => 1 },
                'updatedBy' => { 'internalId' => 1 },
              ),
              'tags'           => %w[tag1 tag2],
              'policy'         => {
                'agentReadAccess'   => true,
                'agentUpdateAccess' => true,
                'createMentions'    => true,
                'destroy'           => false,
                'followUp'          => true,
                'update'            => true
              },
              'stateColorCode' => 'open',
            }
          end

          it 'finds the ticket' do
            expect(gql.result.data).to include(expected_result)
          end
        end

        context 'when fetching a ticket by ticketId' do
          include_examples 'finds the ticket'
        end

        context 'when fetching a ticket by ticketInternalId' do
          let(:variables) { { ticketInternalId: ticket.id } }

          include_examples 'finds the ticket'
        end

        context 'when fetching a ticket by ticketNumber' do
          let(:variables) { { ticketNumber: ticket.number } }

          include_examples 'finds the ticket'
        end

        context 'when locator is missiong' do
          let(:variables) { {} }

          it 'raises an exception' do
            expect(gql.result.error_type).to eq(GraphQL::Schema::Validator::ValidationFailedError)
          end
        end

        context 'when subscribed' do
          before do
            Mention.subscribe! ticket, agent
            gql.execute(query, variables: variables)
          end

          it 'returns subscribed' do
            expect(gql.result.data).to include('subscribed' => true)
          end

          it 'returs user in subscribers list' do
            expect(gql.result.data.dig('mentions', 'edges'))
              .to include(include('node' => include('user' => include('id' => gql.id(agent)))))
          end
        end
      end

      context 'without permission' do
        it 'raises authorization error' do
          expect(gql.result.error_type).to eq(Exceptions::Forbidden)
        end
      end

      context 'without ticket' do
        let(:ticket) { create(ticket).tap(&:destroy) }

        it 'fetches no ticket' do
          expect(gql.result.error_type).to eq(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'with a customer', authenticated_as: :customer do
      let(:customer) { create(:customer) }
      let(:ticket)   { create(:ticket, customer: customer) }
      let(:expected_result) do
        {
          'id'         => gql.id(ticket),
          'internalId' => ticket.id,
          'number'     => ticket.number,
          # Customer is not allowed to see data of other users
          'owner'      => include(
            'firstname' => ticket.owner.firstname,
            'email'     => nil,
            'createdBy' => nil,
            'updatedBy' => nil,
          ),
          # Customer may see their own data
          'customer'   => include(
            'firstname' => customer.firstname,
            'email'     => customer.email,
          ),
          'policy'     => {
            'agentReadAccess'   => false,
            'agentUpdateAccess' => false,
            'createMentions'    => false,
            'destroy'           => false,
            'followUp'          => true,
            'update'            => true
          },
        }
      end

      it 'finds the ticket, but without data of other users' do
        expect(gql.result.data).to include(expected_result)
      end
    end

    it_behaves_like 'graphql responds with error if unauthenticated'
  end
end
