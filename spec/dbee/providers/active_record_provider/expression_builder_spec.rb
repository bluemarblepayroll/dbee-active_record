# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

describe Dbee::Providers::ActiveRecordProvider::ExpressionBuilder do
  let(:model)       { Dbee::Model.make(models['Patients']) }
  let(:alias_maker) { Dbee::Providers::ActiveRecordProvider::SafeAliasMaker.new }

  let(:id_and_average_query) do
    Dbee::Query.make(
      fields: [
        {
          key_path: :id,
          display: 'ID #'
        },
        {
          key_path: 'patient_payments.amount',
          display: 'Ave Payment',
          aggregator: :ave
        }
      ],
      sorters: [
        {
          key_path: :id
        }
      ],
      filters: [
        {
          key_path: :id,
          value: 123
        }
      ]
    )
  end

  let(:first_and_count_query) do
    Dbee::Query.make(
      fields: [
        {
          key_path: :first,
          display: 'First Name'
        },
        {
          key_path: 'patient_payments.amount',
          display: 'Number of Payments',
          aggregator: :count
        }
      ]
    )
  end

  subject { described_class.new(model, alias_maker, alias_maker) }

  before(:all) do
    connect_to_db(:sqlite)
  end

  describe '#clear' do
    it 'provides fluent interface (returns self)' do
      expect(subject.clear).to eq(subject)
    end

    it 'resets selecting, grouping, sorting, and filtering' do
      subject.add(id_and_average_query)

      sql = subject.to_sql

      expect(sql).not_to include('*')
      expect(sql).to     include('GROUP')
      expect(sql).to     include('WHERE')
      expect(sql).to     include('ORDER')

      sql = subject.clear.to_sql

      expect(sql).to     include('*')
      expect(sql).not_to include('GROUP')
      expect(sql).not_to include('WHERE')
      expect(sql).not_to include('ORDER')
    end
  end

  describe '#to_sql' do
    specify 'when called with no fields, then called with fields removes star select' do
      expect(subject.to_sql).to include('*')

      subject.add(id_and_average_query)

      expect(subject.to_sql).not_to include('*')
    end

    context 'with aggregation' do
      it 'generates the same sql when called multiple times' do
        subject.add(id_and_average_query)

        first_sql  = subject.to_sql
        second_sql = subject.to_sql

        expect(first_sql).to eq(second_sql)

        subject.add(first_and_count_query)

        first_sql  = subject.to_sql
        second_sql = subject.to_sql

        expect(first_sql).to eq(second_sql)
      end
    end
  end
end
