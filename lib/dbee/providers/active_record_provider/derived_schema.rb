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
      # Decorates a Dbee::Schema with derived tables created from subqueries.
      # Also, unlike a Dbee::Schema, this class deals with
      # `Dbee::Providers::ActiveRecordProvider::Joinable` instead of
      # `Dbee::Model` as a Joinable provides a layer of abstraction over
      # physical and derived tables.
      class DerivedSchema # :nodoc: all
        attr_reader :dbee_schema, :table_alias_maker

        def initialize(dbee_schema, table_alias_maker: SafeAliasMaker.new)
          @dbee_schema = dbee_schema || raise(ArgumentError, 'dbee_schema is required')
          @table_alias_maker = table_alias_maker || \
                               raise(ArgumentError, 'table_alias_maker is required')

          @appended_joinables_by_name = {}
        end

        def expand_query_path(joinable, key_path)
          dbee_schema.expand_query_path(joinable.model, key_path).map do |relationship, model|
            [relationship, joinable(model)]
          end
        end

        def joinable_for_model_name!(model_name)
          appended_joinables_by_name[model_name.to_s] || \
            joinable(dbee_schema.model_for_name!(model_name))
        end

        def append_subquery(subquery)
          name_exists?(subquery.name) && raise(ArgumentError,
                                               "a model named '#{subquery.name}' already exists")
          joinable = subquery_joinable(subquery)
          appended_joinables_by_name[joinable.name.to_s] = joinable
        end

        private

        def joinable(model)
          Joinable.new(model, table_alias_maker: table_alias_maker)
        end

        def subquery_joinable(subquery)
          joinable(Dbee::Model::Derived.new(name: subquery.name, query: subquery))
        end

        def name_exists?(model_name)
          appended_joinables_by_name[model_name.to_s] || dbee_schema.model_for_name(model_name)
        end

        attr_reader :appended_joinables_by_name
      end
    end
  end
end