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
        # Derives Arel#order predicates.
        class Order
          include Singleton

          def make(sorter, arel_column)
            method = SORTER_EVALUATORS[sorter.class]

            raise ArgumentError, "cannot compile sorter: #{sorter}" unless method

            method.call(arel_column)
          end

          SORTER_EVALUATORS = {
            Query::Sorters::Ascending => ->(column) { column },
            Query::Sorters::Descending => ->(column) { column.desc }
          }.freeze

          private_constant :SORTER_EVALUATORS
        end
      end
    end
  end
end
