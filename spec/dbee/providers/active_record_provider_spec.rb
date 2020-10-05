# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider do
  describe '#sql' do
    before(:all) do
      connect_to_db(:sqlite)
    end

    it 'errors when joining tables with no constraints' do
      model_hash = {
        name: :users,
        models: [
          { name: :logins }
        ]
      }

      query_hash = {
        fields: [
          { key_path: 'id' },
          { key_path: 'logins.id' }
        ]
      }

      query = Dbee::Query.make(query_hash)
      model = Dbee::Model.make(model_hash)

      error_class = Dbee::Providers::ActiveRecordProvider::ExpressionBuilder::MissingConstraintError

      expect { described_class.new.sql(model, query) }.to raise_error(error_class)
    end
  end

  describe 'snapshot' do
    context 'sql' do
      %w[sqlite mysql].each do |dbms|
        context "using #{dbms}" do
          before(:all) do
            connect_to_db(dbms)
          end

          { readable: true, not_readable: false }.each_pair do |type, readable|
            context type.to_s do
              let(:key) { "#{dbms}_#{type}" }

              yaml_fixture_files('active_record_snapshots').each_pair do |filename, snapshot|
                specify File.basename(filename) do
                  model_name = snapshot['model_name']
                  query = Dbee::Query.make(snapshot['query'])
                  model = Dbee::Model.make(models[model_name])

                  expected_5_sql  = snapshot[key].to_s.chomp.tr("\n", ' ')
                  expected_6_sql  = expected_5_sql.gsub('  ', ' ').gsub("'t'", '1').gsub("'f'", '0')
                  actual_sql      = described_class.new(readable: readable).sql(model, query)

                  error_msg = <<~ERROR_MSG
                    Expected 5 SQL: #{expected_5_sql}
                    Expected 6 SQL: #{expected_6_sql}
                    Actual:         #{actual_sql}
                  ERROR_MSG

                  expect([expected_5_sql, expected_6_sql]).to include(actual_sql), error_msg
                end
              end
            end
          end
        end
      end
    end

    context 'Shallow SQL Execution' do
      %w[sqlite].each do |dbms|
        context dbms do
          before(:all) do
            connect_to_db(dbms)
            load_schema
          end

          { readable: true, not_readable: false }.each_pair do |type, readable|
            context type.to_s do
              let(:key) { "#{dbms}_#{type}" }

              yaml_fixture_files('active_record_snapshots').each_pair do |filename, snapshot|
                specify File.basename(filename) do
                  model_name = snapshot['model_name']
                  query = Dbee::Query.make(snapshot['query'])
                  model = Dbee::Model.make(models[model_name])

                  sql = described_class.new(readable: readable).sql(model, query)

                  expect { ActiveRecord::Base.connection.execute(sql) }.to_not raise_error
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'Deep SQL execution' do
    context 'the patients model' do
      before(:all) do
        connect_to_db(:sqlite)
        load_schema
        load_patient_data
      end

      describe 'pivoting' do
        let(:snapshot_path) do
          %w[
            spec
            fixtures
            active_record_snapshots
            two_table_query_with_pivoting.yaml
          ]
        end

        let(:snapshot) { yaml_file_read(*snapshot_path) }
        let(:query)    { Dbee::Query.make(snapshot['query']) }
        let(:model)    { Dbee::Model.make(models['Patients']) }

        it 'pivots table rows into columns' do
          sql = described_class.new.sql(model, query)

          results = ActiveRecord::Base.connection.execute(sql)

          expect(results[0]).to include(
            'First Name' => 'Bozo',
            'Date of Birth' => '1904-04-04',
            'Drivers License #' => '82-54-hut-hut-hike!',
            'Demographic Notes' => 'The patient is funny!',
            'Contact Notes' => 'Do not call this patient at night!'
          )

          expect(results[1]).to include(
            'First Name' => 'Frank',
            'Date of Birth' => nil,
            'Drivers License #' => nil,
            'Demographic Notes' => nil,
            'Contact Notes' => nil
          )

          expect(results[2]).to include(
            'First Name' => 'Bugs',
            'Date of Birth' => '2040-01-01',
            'Drivers License #' => nil,
            'Demographic Notes' => nil,
            'Contact Notes' => 'Call anytime!!'
          )
        end
      end

      describe 'aggregation' do
        let(:snapshot_path) do
          %w[
            spec
            fixtures
            active_record_snapshots
            two_table_query_with_aggregation.yaml
          ]
        end

        let(:snapshot) { yaml_file_read(*snapshot_path) }
        let(:query)    { Dbee::Query.make(snapshot['query']) }
        let(:model)    { Dbee::Model.make(models['Patients']) }

        it 'executes correct SQL aggregate functions' do
          sql     = described_class.new.sql(model, query)
          results = ActiveRecord::Base.connection.execute(sql)

          expect(results[0]).to include(
            'First Name' => 'Bozo',
            'Ave Payment' => 10,
            'Number of Payments' => 3,
            'Max Payment' => 15,
            'Min Payment' => 5,
            'Total Paid' => 30
          )

          expect(results[1]).to include(
            'First Name' => 'Frank',
            'Ave Payment' => 100,
            'Number of Payments' => 2,
            'Max Payment' => 150,
            'Min Payment' => 50,
            'Total Paid' => 200
          )

          expect(results[2]).to include(
            'First Name' => 'Bugs',
            'Ave Payment' => nil,
            'Number of Payments' => 0,
            'Max Payment' => nil,
            'Min Payment' => nil,
            'Total Paid' => nil
          )
        end
      end
    end
  end

  context 'the movies model' do
    before(:all) do
      connect_to_db(:sqlite)
      load_schema
      load_movie_data
    end

    describe 'subquery as a top level query as a sanity check' do
      let(:query) do
        # select theaters.name, theater_id, max(effective_date)
        # from theaters
        # left join ticket_prices on theaters.id = ticket_prices.theater_id
        # where effective_date <= '2020-01-01'
        # group by theaters.name, theater_id
        # order by theater_id;
        Dbee::Query.make(
          fields: [
            { key_path: :name },
            { key_path: :id },
            { key_path: :'ticket_prices.effective_date', aggregator: :max }
          ],
          filters: [
            {
              key_path: :'ticket_prices.effective_date',
              type: :less_than_or_equal_to,
              value: '2020-01-01'
            }
          ],
          sorters: [
            { key_path: :id }
          ],
          limit: 2
        )
      end
      let(:model) { Dbee::Model.make(models['Theaters, Members, and Movies']) }

      it 'returns the expected results' do
        sql = described_class.new.sql(model, query)

        results = ActiveRecord::Base.connection.execute(sql)
        expect(results.size).to eq(2)

        expect(results[0]).to include(
          'name' => 'Small Town Movies',
          'id' => 1,
          'ticket_prices_effective_date' => '2020-01-01'
        )

        expect(results[1]).to include(
          'name' => 'Big City Megaplex',
          'id' => 2,
          'ticket_prices_effective_date' => '2019-01-31'
        )
      end
    end

    describe 'one level of subquery' do
      let(:query) do
        # SELECT
        #   theaters.name,
        #   ticket_prices.effective_date,
        #   ticket_prices.price_usd
        # FROM
        #   theaters
        #   LEFT JOIN ticket_prices ON theaters.id = ticket_prices.theater_id
        #   LEFT JOIN (
        #     SELECT
        #       theater_id,
        #       max(effective_date) AS effective_date
        #     FROM
        #       ticket_prices
        #     WHERE
        #       effective_date <= '2020-01-01'
        #     GROUP BY
        #       theater_id
        #     ) AS effective_ticket_prices ON
        #       effective_ticket_prices.theater_id = ticket_prices.theater_id
        #       AND effective_ticket_prices.effective_date = ticket_prices.effective_date
        # WHERE
        #   effective_ticket_prices.theater_id IS NOT NULL
        # ORDER BY
        #   theaters.name,
        #   ticket_prices.effective_date;
        Dbee::Query.make(
          given: [
            {
              model: :ticket_prices,
              name: :effective_ticket_prices,
              constraints: [
                { name: :theater_id, parent: :theater_id },
                { name: :effective_date, parent: :effective_date }
              ],
              fields: [
                { key_path: :theater_id },
                { key_path: :effective_date, aggregator: :max }
              ],
              filters: [
                {
                  key_path: :effective_date,
                  type: :less_than_or_equal_to,
                  value: '2020-01-01'
                }
              ]
            }
          ],
          fields: [
            { key_path: :name },
            { key_path: :'ticket_prices.effective_date' },
            { key_path: :'ticket_prices.price_usd' }
          ],
          filters: [
            {
              key_path: :'ticket_prices.effective_ticket_prices.theater_id',
              type: :not_equals,
              value: nil
            }
          ],
          sorters: [
            { key_path: :name },
            { key_path: :'ticket_prices.effective_date' }
          ],
          limit: 2
        )
      end
      let(:model) { Dbee::Model.make(models['Theaters, Members, and Movies']) }

      # TODO: add this to snapshots
      it 'returns effective ticket prices' do
        sql = subject.sql(model, query)

        results = ActiveRecord::Base.connection.execute(sql)
        expect(results.size).to eq(2)

        expect(results[0]).to include(
          'name' => 'Big City Megaplex',
          'ticket_prices_effective_date' => '2019-01-31',
          'ticket_prices_price_usd' => 12
        )

        expect(results[1]).to include(
          'name' => 'Out of Business Theater',
          'ticket_prices_effective_date' => '2017-02-01',
          'ticket_prices_price_usd' => 14
        )
      end
    end
  end
end
