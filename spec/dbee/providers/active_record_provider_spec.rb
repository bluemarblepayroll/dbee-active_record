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
    def check_pending(expectation)
      pending expectation['pending'] if expectation.is_a?(Hash) && expectation['pending']
    end

    context 'sql' do
      # Different Arel versions are annoyingly inconsistent with one or two spaces
      # after the SELECT keyword.
      def select_space_normalize(sql)
        sql.gsub(/SELECT +/, 'SELECT ')
      end

      def fixture_sql_normalizer(fixture_sql)
        leading_whitespace_trimmed = fixture_sql.to_s.chomp.gsub(/\n\s*/, ' ')
        select_space_normalized = select_space_normalize(leading_whitespace_trimmed)

        ar_major = ActiveRecord::VERSION::MAJOR
        case ar_major
        when 5
          select_space_normalized
        when 6
          select_space_normalized.gsub("'t'", '1').gsub("'f'", '0')
        else
          raise "unsupported ActiveRecord major version: #{ar_major}"
        end
      end

      # Rspec's diffing is not very helpful for long strings. It does offer
      # better support for strings with newlines. This method adds newlines
      # before major parts of the query to support better Rspec diagnostics.
      # Note that Rspec version 4 is supposed to ship with a better diffing
      # tool for long strings:
      # https://github.com/rspec/rspec-support/issues/365 .
      def newline_injector(sql)
        sql.gsub('LEFT OUTER JOIN', "\nLEFT OUTER JOIN")
           .gsub('WHERE', "\nWHERE")
           .gsub('ORDER BY', "\nORDER BY")
           .gsub('LIMIT', "\nLIMIT")
           .gsub('GROUP BY', "\nGROUP BY")
      end

      %w[sqlite mysql].each do |dbms|
        context "using #{dbms} and ActiveRecord major version #{ActiveRecord::VERSION::MAJOR}" do
          before(:all) do
            connect_to_db(dbms)
          end

          { readable: true, not_readable: false }.each_pair do |type, readable|
            context type.to_s do
              let(:key) { "#{dbms}_#{type}" }

              yaml_fixture_files('active_record_snapshots').each_pair do |filename, snapshot|
                # next unless filename =~ /one_subquery/
                specify File.basename(filename) do
                  check_pending(snapshot[key])

                  model_name = snapshot['model_name']
                  query = Dbee::Query.make(snapshot['query'])
                  model = Dbee::Model.make(models[model_name])

                  expected_sql_with_line_breaks = newline_injector(
                    fixture_sql_normalizer(snapshot[key])
                  )

                  subject = described_class.new(readable: readable)
                  actual_sql = subject.sql(model, query)
                  actual_sql_with_line_breaks = newline_injector(select_space_normalize(actual_sql))

                  expect(actual_sql_with_line_breaks).to eq expected_sql_with_line_breaks
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
                  check_pending(snapshot[key])

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

    context 'the movies model' do
      before(:all) do
        connect_to_db(:sqlite)
        load_schema
        load_movie_data
      end

      let(:snapshot) { yaml_file_read(*snapshot_path) }
      let(:query)    { Dbee::Query.make(snapshot['query']) }
      let(:model)    { Dbee::Model.make(models['Theaters, Members, and Movies']) }

      describe 'one level of subquery' do
        let(:snapshot_path) do
          %w[
            spec
            fixtures
            active_record_snapshots
            one_subquery.yaml
          ]
        end

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

      # TODO: consolidate these tests as they all have the same results:
      describe 'two level subquery' do
        let(:snapshot_path) do
          %w[
            spec
            fixtures
            active_record_snapshots
            two_level_subquery.yaml
          ]
        end

        let(:snapshot) { yaml_file_read(*snapshot_path) }
        let(:query)    { Dbee::Query.make(snapshot['query']) }
        let(:model)    { Dbee::Model.make(models['Theaters, Members, and Movies']) }

        it 'returns effective ticket prices for all theaters even if there is no price in ' \
                'effect' do
          sql = subject.sql(model, query)

          results = ActiveRecord::Base.connection.execute(sql)
          expect(results.size).to eq(2)

          expect(results[0]).to include(
            'name' => 'Big City Megaplex',
            'effective_ticket_prices_effective_date' => nil,
            'effective_ticket_prices_price_usd' => nil
          )

          expect(results[1]).to include(
            'name' => 'Out of Business Theater',
            'effective_ticket_prices_effective_date' => '2016-01-01',
            'effective_ticket_prices_price_usd' => 12
          )
        end
      end

      describe 'two level subquery defined in the model' do
        let(:snapshot_path) do
          %w[
            spec
            fixtures
            active_record_snapshots_pending
            two_level_subquery_defined_in_model.yaml
          ]
        end

        let(:snapshot) { yaml_file_read(*snapshot_path) }
        let(:query)    { Dbee::Query.make(snapshot['query']) }
        let(:model)    { Dbee::Model.make(models[snapshot['model_name']]) }

        it 'returns effective ticket prices for all theaters even if there is no price in ' \
                'effect' do
          sql = subject.sql(model, query)

          results = ActiveRecord::Base.connection.execute(sql)
          expect(results.size).to eq(2)

          expect(results[0]).to include(
            'name' => 'Big City Megaplex',
            'effective_ticket_prices_effective_date' => nil,
            'effective_ticket_prices_price_usd' => nil
          )

          expect(results[1]).to include(
            'name' => 'Out of Business Theater',
            'effective_ticket_prices_effective_date' => '2016-01-01',
            'effective_ticket_prices_price_usd' => 12
          )
        end
      end

      describe 'two level subquery defined using the Ruby DSL' do
        let(:query) do
          Dbee::Query.make({
                             fields: [
                               { key_path: :name },
                               { key_path: :'effective_ticket_prices.effective_date' },
                               { key_path: :'effective_ticket_prices.price_usd' }
                             ],
                             sorters: [
                               { key_path: :name },
                               { key_path: :'effective_ticket_prices.effective_date' }
                             ],
                             limit: 2
                           })
        end
        let(:model) { Models::Theaters.to_model(Dbee::Query.make(query).key_chain) }

        it 'returns effective ticket prices for all theaters even if there is no price in ' \
                'effect' do
          pending 'Dbee is not smart enough to handle this yet'
          puts "model: \n #{model.to_yaml}\n"
          sql = subject.sql(model, query)

          results = ActiveRecord::Base.connection.execute(sql)
          expect(results.size).to eq(2)

          expect(results[0]).to include(
            'name' => 'Big City Megaplex',
            'effective_ticket_prices_effective_date' => nil,
            'effective_ticket_prices_price_usd' => nil
          )

          expect(results[1]).to include(
            'name' => 'Out of Business Theater',
            'effective_ticket_prices_effective_date' => '2016-01-01',
            'effective_ticket_prices_price_usd' => 12
          )
        end
      end
    end
  end
end
