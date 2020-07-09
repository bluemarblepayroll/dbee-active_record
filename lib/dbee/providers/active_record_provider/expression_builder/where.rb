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
            # If the filter has a value of nil, then simply return an IS NULL predicate
            return make_is_null_predicate(arel_column) unless filter.value

            values     = Array(filter.value).flatten
            predicates = values.include?(nil) ? [make_is_null_predicate(arel_column)] : []
            predicates += make_predicates(filter, arel_column, values)

            predicates.inject(predicates.shift) do |memo, predicate|
              memo.or(predicate)
            end
          end

          private

          FILTER_EVALUATORS = {
            Query::Filters::Contains => ->(node, val) { node.matches("%#{val}%") },
            Query::Filters::Equals => ->(node, val) { node.eq(val) },
            Query::Filters::GreaterThan => ->(node, val) { node.gt(val) },
            Query::Filters::GreaterThanOrEqualTo => ->(node, val) { node.gteq(val) },
            Query::Filters::LessThan => ->(node, val) { node.lt(val) },
            Query::Filters::LessThanOrEqualTo => ->(node, val) { node.lteq(val) },
            Query::Filters::NotContain => ->(node, val) { node.does_not_match("%#{val}%") },
            Query::Filters::NotEquals => ->(node, val) { node.not_eq(val) },
            Query::Filters::NotStartWith => ->(node, val) { node.does_not_match("#{val}%") },
            Query::Filters::StartsWith => ->(node, val) { node.matches("#{val}%") }
          }.freeze

          private_constant :FILTER_EVALUATORS

          def make_predicates(filter, arel_column, values)
            values -= [nil]

            if filter.is_a?(Query::Filters::Equals) && values.length > 1
              [arel_column.in(values)]
            elsif filter.is_a?(Query::Filters::NotEquals) && values.length > 1
              [arel_column.not_in(values)]
            elsif values.length.positive?
              values.map do |value|
                make_predicate(arel_column, filter.class, value)
              end
            else
              []
            end
          end

          def make_predicate(arel_column, filter_class, value)
            method = FILTER_EVALUATORS[filter_class]

            raise ArgumentError, "cannot compile filter: #{filter}" unless method

            method.call(arel_column, value)
          end

          def make_is_null_predicate(arel_column)
            make_predicate(arel_column, Query::Filters::Equals, nil)
          end
        end
      end
    end
  end
end
