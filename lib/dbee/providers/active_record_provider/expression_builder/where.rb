# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

module Dbee
  module Providers
    class ActiveRecordProvider
      class ExpressionBuilder
        # Derives Arel#where predicates.
        class Where
          include Singleton

          def make(filter, arel_column)
            values = normalize(filter.value)

            if filter.is_a?(Query::Filters::Equals) && values.length > 1
              arel_column.in(values)
            elsif filter.is_a?(Query::Filters::NotEquals) && values.length > 1
              arel_column.not_in(values)
            else
              use_or(filter, arel_column)
            end
          end

          private

          FILTER_EVALUATORS = {
            Query::Filters::Contains => ->(column, val) { column.matches("%#{val}%") },
            Query::Filters::Equals => ->(column, val) { column.eq(val) },
            Query::Filters::GreaterThan => ->(column, val) { column.gt(val) },
            Query::Filters::GreaterThanOrEqualTo => ->(column, val) { column.gteq(val) },
            Query::Filters::LessThan => ->(column, val) { column.lt(val) },
            Query::Filters::LessThanOrEqualTo => ->(column, val) { column.lteq(val) },
            Query::Filters::NotContain => ->(column, val) { column.does_not_match("%#{val}%") },
            Query::Filters::NotEquals => ->(column, val) { column.not_eq(val) },
            Query::Filters::NotStartWith => ->(column, val) { column.does_not_match("#{val}%") },
            Query::Filters::StartsWith => ->(column, val) { column.matches("#{val}%") }
          }.freeze

          private_constant :FILTER_EVALUATORS

          def normalize(value)
            value ? Array(value).flatten : [nil]
          end

          def use_or(filter, arel_column)
            predicates = normalize(filter.value).map do |coerced_value|
              method = FILTER_EVALUATORS[filter.class]

              raise ArgumentError, "cannot compile filter: #{filter}" unless method

              method.call(arel_column, coerced_value)
            end

            predicates.inject(predicates.shift) do |memo, predicate|
              memo.or(predicate)
            end
          end
        end
      end
    end
  end
end
