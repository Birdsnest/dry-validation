# frozen_string_literal: true

require 'dry/schema'
require 'dry/schema/messages'
require 'dry/schema/path'
require 'dry/schema/key_map'

require 'dry/validation/constants'
require 'dry/validation/macros'
require 'dry/validation/schema_ext'

module Dry
  module Validation
    class Contract
      # Contract's class interface
      #
      # @see Contract
      #
      # @api public
      module ClassInterface
        include Macros::Registrar

        # @api private
        def inherited(klass)
          super
          klass.instance_variable_set('@config', config.dup)
        end

        # Configuration
        #
        # @example
        #   class MyContract < Dry::Validation::Contract
        #     config.messages.backend = :i18n
        #   end
        #
        # @return [Config]
        #
        # @api public
        def config
          @config ||= Validation::Config.new
        end

        # Return macros registered for this class
        #
        # @return [Macros::Container]
        #
        # @api public
        def macros
          config.macros
        end

        # Define a params schema for your contract
        #
        # This type of schema is suitable for HTTP parameters
        #
        # @return [Dry::Schema::Params,NilClass]
        # @see https://dry-rb.org/gems/dry-schema/params/
        #
        # @api public
        def params(external_schema = nil, &block)
          define(:Params, external_schema, &block)
        end

        # Define a JSON schema for your contract
        #
        # This type of schema is suitable for JSON data
        #
        # @return [Dry::Schema::JSON,NilClass]
        # @see https://dry-rb.org/gems/dry-schema/json/
        #
        # @api public
        def json(external_schema = nil, &block)
          define(:JSON, external_schema, &block)
        end

        # Define a plain schema for your contract
        #
        # This type of schema does not offer coercion out of the box
        #
        # @return [Dry::Schema::Processor,NilClass]
        # @see https://dry-rb.org/gems/dry-schema/
        #
        # @api public
        def schema(external_schema = nil, &block)
          define(:schema, external_schema, &block)
        end

        # Define a rule for your contract
        #
        # @example using a symbol
        #   rule(:age) do
        #     failure('must be at least 18') if values[:age] < 18
        #   end
        #
        # @example using a path to a value and a custom predicate
        #   rule('address.street') do
        #     failure('please provide a valid street address') if valid_street?(values[:street])
        #   end
        #
        # @return [Rule]
        #
        # @api public
        def rule(*keys, &block)
          ensure_valid_keys(*keys) if __schema__

          Rule.new(keys: keys, block: block).tap do |rule|
            rules << rule
          end
        end

        # A shortcut that can be used to define contracts that won't be reused or inherited
        #
        # @example
        #   my_contract = Dry::Validation::Contract.build do
        #     params do
        #       required(:name).filled(:string)
        #     end
        #   end
        #
        #   my_contract.call(name: "Jane")
        #
        # @return [Contract]
        #
        # @api public
        def build(options = EMPTY_HASH, &block)
          Class.new(self, &block).new(options)
        end

        # @api private
        def __schema__
          @__schema__ if defined?(@__schema__)
        end

        # Return rules defined in this class
        #
        # @return [Array<Rule>]
        #
        # @api private
        def rules
          @rules ||= EMPTY_ARRAY
            .dup
            .concat(superclass.respond_to?(:rules) ? superclass.rules : EMPTY_ARRAY)
        end

        # Return messages configured for this class
        #
        # @return [Dry::Schema::Messages]
        #
        # @api private
        def messages
          @messages ||= Schema::Messages.setup(config.messages)
        end

        private

        # @api private
        # rubocop:disable Metrics/AbcSize
        def ensure_valid_keys(*keys)
          valid_paths = key_map.to_dot_notation.map { |value| Schema::Path[value] }

          invalid_keys = keys
            .map { |key|
              [key, Schema::Path[key]]
            }
            .map { |(key, path)|
              if (last = path.last).is_a?(Array)
                last.map { |last_key|
                  path_key = [*path.to_a[0..-2], last_key]
                  [path_key, Schema::Path[path_key]]
                }
              else
                [[key, path]]
              end
            }
            .flatten(1)
            .reject { |(_, path)|
              valid_paths.any? { |valid_path| valid_path.include?(path) }
            }
            .map(&:first)

          return if invalid_keys.empty?

          raise InvalidKeysError, <<~STR.strip
            #{name}.rule specifies keys that are not defined by the schema: #{invalid_keys.inspect}
          STR
        end
        # rubocop:enable Metrics/AbcSize

        # @api private
        def key_map
          __schema__.key_map
        end

        # @api private
        def core_schema_opts
          { parent: superclass&.__schema__, config: config }
        end

        # @api private
        def define(method_name, external_schema, &block)
          return __schema__ if external_schema.nil? && block.nil?

          unless __schema__.nil?
            raise ::Dry::Validation::DuplicateSchemaError, 'Schema has already been defined'
          end

          schema_opts = core_schema_opts

          schema_opts.update(parent: external_schema) if external_schema

          case method_name
          when :schema
            @__schema__ = Schema.define(schema_opts, &block)
          when :Params
            @__schema__ = Schema.Params(schema_opts, &block)
          when :JSON
            @__schema__ = Schema.JSON(schema_opts, &block)
          end
        end
      end
    end
  end
end
