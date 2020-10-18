# frozen_string_literal: true

#
# Copyright (c) 2019-present, Blue Marble Payroll, LLC
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

require_relative 'makers/constraint'
require_relative 'makers/order'
require_relative 'makers/select'
require_relative 'makers/where'

module Dbee
  module Providers
    class ActiveRecordProvider
      # Decorates a Dbee::Model with derived tables created from subqueries.
      # This also returns instances of
      # `Dbee::Providers::ActiveRecordProvider::Joinable` instead of
      # `Dbee::Model` as a Joinable provides a layer of abstraction over
      # physical and derived tables.
      class DerivedModel # :nodoc: all
        attr_reader :joinable_builder, :model

        def initialize(model, joinable_builder)
          @model = model || raise(ArgumentError, 'a model is required')
          @joinable_builder = joinable_builder \
            || raise(ArgumentError, 'a joinable builder is required')

          # This gets mutated as derived tables are appended. However, all of
          # the instance variables of this object should never be reassigned.
          @derived_by_path = {}

          freeze
        end

        # Appends a Joinable to the DerivedModel tree. A
        # `Dbee::Model::ModelNotFoundError` is raised if the model to append to
        # can not be found. The model to append to is based on the name of
        # Joinable#parent_model.
        def append!(joinable)
          root, *rest = joinable.parent_model_path
          check_root!(root)

          model_ancestors = model.ancestors!(rest)
          model_path = model_ancestors.keys.any? ? model_ancestors.keys.last : []
          derived_by_path.merge!(model_path + [joinable.name] => joinable)

          self
        end

        # Similar to Dbee::Model#ancestors! except that it returns results for
        # derived tables and all of the values are
        # `Dbee::Providers::ActiveRecordProvider::Joinable`s instead of
        # `Dbee::Model`s.
        def ancestors!(parts)
          derived_model = derived_by_path[parts]
          if derived_model
            # Omit the last part when searching in the model as it would not be
            # found as it is derived.
            model_ancestors_to_joinable(parts[0..-2]).merge(
              parts => derived_model
            )
          else
            model_ancestors_to_joinable(parts)
          end
        end

        private

        def check_root!(parent_model_name)
          # rubocop:disable Style/GuardClause
          # Rubocop can't have it both way. If this is converted to a
          # GuardClause then Style/MultilineIfModifier is violated.
          # TODO: see if upgrading Rubocop fixes this.
          unless parent_model_name == model.name
            raise ArgumentError, "invalid root name: '#{parent_model_name}', expected: " \
                                 "'#{model.name}''"
          end
          # rubocop:enable Style/GuardClause
        end

        def model_ancestors_to_joinable(parts)
          model.ancestors!(parts).transform_values do |current_model|
            case current_model
            when Dbee::Model::TableBased
              joinable_builder.for_model(current_model)
            when Dbee::Model::Derived
              generate_subquery_joinable(current_model)
            else
              # TODO: use the Caution illegal state error
              raise "unknown model type, '#{current_model.class}' for path #{parts}"
            end
          end
        end

        def generate_subquery_joinable(current_model)
          expression_builder = ExpressionBuilder.new(
            model,
            joinable_builder.table_alias_maker,
            # TODO: use the configured column alias maker
            SafeAliasMaker.new
          )
          SubqueryExpressionBuilder.new(expression_builder)
                                   .build(current_model.query, append_to_model: false)
                                   .first
        end

        attr_reader :derived_by_path
      end
    end
  end
end
