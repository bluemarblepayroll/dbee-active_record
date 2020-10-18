# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'maker'

module Dbee
  module Providers
    class ActiveRecordProvider
      # This class creates `ExpressionBuilder`s for subqueries and also appends
      # those subquery derived models to the model tree so they are available
      # to by outer queries.
      class SubqueryExpressionBuilder # :nodoc: all
        attr_reader :expression_builder

        def initialize(expression_builder)
          @expression_builder = expression_builder || raise(
            ArgumentError, 'expression_builder is required'
          )

          freeze
        end

        def build(queries, append_to_model: true)
          Array(queries).map do |subquery|
            # TODO: move this logic to Dbee and consolidate with similar logic in DerivedModel:
            _root_model, *model_path = subquery.model.to_s.split('.')

            subquery_expression = expression_builder.new_scoped_to_model_path(model_path)
            subquery_expression.add(subquery)

            subquery_expression.finalize(subquery).tap do |joinable|
              # The outer query needs to have this derived table appended to its
              # model tree so that it knows how to join to it.
              expression_builder.append_to_model(joinable) if append_to_model
            end
          end
        end
      end
    end
  end
end
