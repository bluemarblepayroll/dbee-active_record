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
        # Can derive constraints for Arel table JOIN statements.
        class Constraint # :nodoc: all
          include Singleton

          def make(constraints, table, previous_table)
            constraints.inject(nil) do |memo, constraint|
              method = CONSTRAINT_RESOLVERS[constraint.class]

              raise ArgumentError, "constraint unhandled: #{constraint.class.name}" unless method

              method.call(constraint, memo, table, previous_table)
            end
          end

          CONCAT_METHOD = lambda do |on, arel_column, value|
            on ? on.and(arel_column.eq(value)) : arel_column.eq(value)
          end

          CONSTRAINT_RESOLVERS = {
            Model::Constraints::Reference => lambda do |constraint, on, table, previous_table|
              name    = constraint.name
              parent  = constraint.parent

              CONCAT_METHOD.call(on, table[name], previous_table[parent])
            end,
            Model::Constraints::Static => lambda do |constraint, on, table, previous_table|
              value = constraint.value

              unless constraint.name.empty?
                column_name = constraint.name
                on = CONCAT_METHOD.call(on, table[column_name], value)
              end

              unless constraint.parent.empty?
                column_name = constraint.parent
                on = CONCAT_METHOD.call(on, previous_table[column_name], value)
              end

              on
            end
          }.freeze

          private_constant :CONSTRAINT_RESOLVERS
        end
      end
    end
  end
end
