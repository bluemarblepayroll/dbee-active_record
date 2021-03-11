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
      # This class is responsible for creating Arel expressions from a
      # Dbee::Model::Derived.
      class DerivedModelBuilder # :nodoc: all
        attr_reader :expression_builder, :model

        def initialize(model, expression_builder)
          @model = model || raise(ArgumentError, 'model is required')
          @query = model.query
          @expression_builder = expression_builder \
            || raise(ArgumentError, 'expression_builder builder is required')

          freeze
        end

        def to_arel
          expression_builder.to_arel(query).as(query.name)
        end

        private

        attr_reader :query
      end
    end
  end
end
