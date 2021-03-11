# frozen_string_literal: true

#
# Copyright (c) 2020-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require 'spec_helper'
require 'db_helper'

# rubocop:disable Layout/LineLength
# Disable the line length cop beause there are some lengthy 'expected' SQL strings in spec which
# cannot be shortened.
describe Dbee::Providers::ActiveRecordProvider::Makers::Where do
  before(:all) { connect_to_db(:sqlite) }

  let(:subject) { described_class.instance }
  let(:column) { Arel::Table.new(:test)[:foo] }

  describe 'equals' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" = 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[("test"."foo" IS NULL OR "test"."foo" IN ('a', 'c'))]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::Equals.new(key_path: :foo, value: %w[a b c])
      expect(subject.make(filter, column).to_sql).to eq %q["test"."foo" IN ('a', 'b', 'c')]
    end
  end

  describe 'not equals' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::NotEquals.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" != 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::NotEquals.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NOT NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::NotEquals.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[("test"."foo" IS NOT NULL OR "test"."foo" NOT IN ('a', 'c'))]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::NotEquals.new(key_path: :foo, value: %w[a b c])
      expect(subject.make(filter, column).to_sql).to eq %q["test"."foo" NOT IN ('a', 'b', 'c')]
    end
  end

  describe 'contains' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::Contains.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" LIKE '%bar%')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::Contains.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::Contains.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" LIKE '%a%') OR "test"."foo" LIKE '%c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::Contains.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" LIKE '%a%' OR "test"."foo" LIKE '%b%') OR "test"."foo" LIKE '%c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'not contains' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::NotContain.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" NOT LIKE '%bar%')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::NotContain.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NOT NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::NotContain.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NOT NULL OR "test"."foo" NOT LIKE '%a%') OR "test"."foo" NOT LIKE '%c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::NotContain.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" NOT LIKE '%a%' OR "test"."foo" NOT LIKE '%b%') OR "test"."foo" NOT LIKE '%c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'starts with' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::StartsWith.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" LIKE 'bar%')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::StartsWith.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::StartsWith.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" LIKE 'a%') OR "test"."foo" LIKE 'c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::StartsWith.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" LIKE 'a%' OR "test"."foo" LIKE 'b%') OR "test"."foo" LIKE 'c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'not start with' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::NotStartWith.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" NOT LIKE 'bar%')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::NotStartWith.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NOT NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::NotStartWith.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NOT NULL OR "test"."foo" NOT LIKE 'a%') OR "test"."foo" NOT LIKE 'c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::NotStartWith.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" NOT LIKE 'a%' OR "test"."foo" NOT LIKE 'b%') OR "test"."foo" NOT LIKE 'c%')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'greater than' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::GreaterThan.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" > 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::GreaterThan.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::GreaterThan.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" > 'a') OR "test"."foo" > 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::GreaterThan.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" > 'a' OR "test"."foo" > 'b') OR "test"."foo" > 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'greater than or equal to' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::GreaterThanOrEqualTo.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" >= 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::GreaterThanOrEqualTo.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::GreaterThanOrEqualTo.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" >= 'a') OR "test"."foo" >= 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::GreaterThanOrEqualTo.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" >= 'a' OR "test"."foo" >= 'b') OR "test"."foo" >= 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'less than' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::LessThan.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" < 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::LessThan.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::LessThan.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" < 'a') OR "test"."foo" < 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::LessThan.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" < 'a' OR "test"."foo" < 'b') OR "test"."foo" < 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end

  describe 'less than or equal to' do
    specify 'a string value' do
      filter = Dbee::Query::Filters::LessThanOrEqualTo.new(key_path: :foo, value: 'bar')
      expect(subject.make(filter, column).to_sql).to eq %q("test"."foo" <= 'bar')
    end

    specify 'a null value' do
      filter = Dbee::Query::Filters::LessThanOrEqualTo.new(key_path: :foo, value: nil)
      expect(subject.make(filter, column).to_sql).to eq '"test"."foo" IS NULL'
    end

    specify 'a set with a null value' do
      filter = Dbee::Query::Filters::LessThanOrEqualTo.new(key_path: :foo, value: ['a', nil, 'c'])
      expected = %q[(("test"."foo" IS NULL OR "test"."foo" <= 'a') OR "test"."foo" <= 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end

    specify 'a set without a null value' do
      filter = Dbee::Query::Filters::LessThanOrEqualTo.new(key_path: :foo, value: %w[a b c])
      expected = %q[(("test"."foo" <= 'a' OR "test"."foo" <= 'b') OR "test"."foo" <= 'c')]
      expect(subject.make(filter, column).to_sql).to eq expected
    end
  end
end
# rubocop:enable Layout/LineLength
