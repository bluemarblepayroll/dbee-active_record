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
        # Derives Arel#project predicates.
        class Select # :nodoc: all
          attr_reader :alias_maker

          def initialize(alias_maker)
            @alias_maker = alias_maker

            freeze
          end

          def star(arel_table)
            arel_table[Arel.star]
          end

          def make(field, arel_key_nodes_to_filters, arel_value_node)
            column_alias = quote(alias_maker.make(field.display))
            predicate    = expression(field, arel_key_nodes_to_filters, arel_value_node)
            predicate    = aggregate(field, predicate)

            predicate.as(column_alias)
          end

          private

          AGGREGRATOR_EVALUATORS = {
            nil => ->(arel_node) { arel_node },
            Query::Field::Aggregator::AVE => ->(node) { Arel::Nodes::Avg.new([node]) },
            Query::Field::Aggregator::COUNT => ->(node) { Arel::Nodes::Count.new([node]) },
            Query::Field::Aggregator::MAX => ->(node) { Arel::Nodes::Max.new([node]) },
            Query::Field::Aggregator::MIN => ->(node) { Arel::Nodes::Min.new([node]) },
            Query::Field::Aggregator::SUM => ->(node) { Arel::Nodes::Sum.new([node]) }
          }.freeze

          private_constant :AGGREGRATOR_EVALUATORS

          def quote(value)
            ActiveRecord::Base.connection.quote(value)
          end

          def aggregate(field, predicate)
            AGGREGRATOR_EVALUATORS[field.aggregator].call(predicate)
          end

          def expression(field, arel_key_nodes_to_filters, arel_value_node)
            if field.filters?
              case_statement   = Arel::Nodes::Case.new
              filter_predicate = make_filter_predicate(arel_key_nodes_to_filters)

              case_statement.when(filter_predicate).then(arel_value_node)
            else
              arel_value_node
            end
          end

          def make_filter_predicate(arel_key_nodes_to_filters)
            predicates = arel_key_nodes_to_filters.map do |arel_key_node, filter|
              Where.instance.make(filter, arel_key_node)
            end

            predicates.inject(predicates.shift) do |memo, predicate|
              memo.and(predicate)
            end
          end
        end
      end
    end
  end
end
