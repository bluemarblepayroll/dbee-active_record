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
      module Makers # :nodoc: all
        # Derives Arel#where predicates.
        class Where
          include Singleton

          def make(filter, arel_column)
            # If the filter has a value of nil, then simply return an IS (NOT) NULL predicate
            return make_is_null_predicate(arel_column, filter.class) if filter.value.nil?

            values = Array(filter.value).flatten

            # This logic helps ensure that if a null exists that it translates to an IS NULL
            # predicate and does not get put into an in or not_in clause.
            predicates = if values.include?(nil)
                           [make_is_null_predicate(arel_column, filter.class)]
                         else
                           []
                         end

            predicates += make_predicates(filter, arel_column, values - [nil])

            # Chain all predicates together
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

          NULL_PREDICATE_MAP = {
            Query::Filters::Contains => Query::Filters::Equals,
            Query::Filters::Equals => Query::Filters::Equals,
            Query::Filters::GreaterThan => Query::Filters::Equals,
            Query::Filters::GreaterThanOrEqualTo => Query::Filters::Equals,
            Query::Filters::LessThan => Query::Filters::Equals,
            Query::Filters::LessThanOrEqualTo => Query::Filters::Equals,
            Query::Filters::NotContain => Query::Filters::NotEquals,
            Query::Filters::NotEquals => Query::Filters::NotEquals,
            Query::Filters::NotStartWith => Query::Filters::NotEquals,
            Query::Filters::StartsWith => Query::Filters::Equals
          }.freeze

          private_constant :FILTER_EVALUATORS, :NULL_PREDICATE_MAP

          def make_predicates(filter, arel_column, values)
            if use_in?(filter, values)
              [arel_column.in(values)]
            elsif use_not_in?(filter, values)
              [arel_column.not_in(values)]
            else
              make_or_predicates(filter, arel_column, values)
            end
          end

          def use_in?(filter, values)
            filter.is_a?(Query::Filters::Equals) && values.length > 1
          end

          def use_not_in?(filter, values)
            filter.is_a?(Query::Filters::NotEquals) && values.length > 1
          end

          def make_or_predicates(filter, arel_column, values)
            values.map do |value|
              make_predicate(arel_column, filter.class, value)
            end
          end

          def make_predicate(arel_column, filter_class, value)
            method = FILTER_EVALUATORS[filter_class]

            raise ArgumentError, "cannot compile filter: #{filter}" unless method

            method.call(arel_column, value)
          end

          def make_is_null_predicate(arel_column, requested_filter_class)
            actual_filter_class = NULL_PREDICATE_MAP[requested_filter_class]
            make_predicate(arel_column, actual_filter_class, nil)
          end
        end
      end
    end
  end
end
