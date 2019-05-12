require 'pathname'
require 'concurrent/map'
require 'dry/equalizer'
require 'dry/configurable'

module Dry
  module Validation
    module Messages
      class Abstract
        extend Dry::Configurable
        include Dry::Equalizer(:config)

        DEFAULT_PATH = Pathname(__dir__).join('../../../../config/errors.yml').realpath.freeze

        setting :paths, [DEFAULT_PATH]
        setting :root, 'errors'.freeze
        setting :lookup_options, [:root, :predicate, :rule, :val_type, :arg_type].freeze

        setting :lookup_paths, %w(
          %{root}.rules.%{rule}.%{predicate}.arg.%{arg_type}
          %{root}.rules.%{rule}.%{predicate}
          %{root}.%{predicate}.%{message_type}
          %{root}.%{predicate}.value.%{rule}.arg.%{arg_type}
          %{root}.%{predicate}.value.%{rule}
          %{root}.%{predicate}.value.%{val_type}.arg.%{arg_type}
          %{root}.%{predicate}.value.%{val_type}
          %{root}.%{predicate}.arg.%{arg_type}
          %{root}.%{predicate}
        ).freeze

        setting :arg_type_default, 'default'.freeze
        setting :val_type_default, 'default'.freeze

        setting :arg_types, Hash.new { |*| config.arg_type_default }.update(
          Range => 'range'
        )

        setting :val_types, Hash.new { |*| config.val_type_default }.update(
          Range => 'range',
          String => 'string'
        )

        CACHE_KEYS = %i[path message_type val_type arg_type locale].freeze

        def self.cache
          @cache ||= Concurrent::Map.new { |h, k| h[k] = Concurrent::Map.new }
        end

        attr_reader :config

        def initialize
          @config = self.class.config
        end

        def hash
          @hash ||= config.hash
        end

        def rule(name, options = {})
          path = "%{locale}.rules.#{name}"
          get(path, options) if key?(path, options)
        end

        def call(predicate, options = EMPTY_HASH)
          cache.fetch_or_store(cache_key(predicate, options)) do
            path, opts = lookup(predicate, options)
            get(path, opts) if path
          end
        end
        alias_method :[], :call

        if ::Hash.instance_methods.include?(:slice)
          def cache_key(predicate, options)
            [predicate, options.slice(*CACHE_KEYS)]
          end
        else
          def cache_key(predicate, options)
            [predicate, options.select { |key,| CACHE_KEYS.include?(key) }]
          end
        end

        def lookup(predicate, options = {})
          tokens = options.merge(
            root: root,
            predicate: predicate,
            arg_type: config.arg_types[options[:arg_type]],
            val_type: config.val_types[options[:val_type]],
            message_type: options[:message_type] || :failure
          )

          tokens[:rule] = predicate unless tokens.key?(:rule)

          opts = options.select { |k, _| !config.lookup_options.include?(k) }

          path = lookup_paths(tokens).detect do |key|
            key?(key, opts) && get(key, opts).is_a?(String)
          end

          [path, opts]
        end

        def lookup_paths(tokens)
          config.lookup_paths.map { |path| path % tokens }
        end

        def namespaced(namespace)
          Messages::Namespaced.new(namespace, self)
        end

        def root
          config.root
        end

        def cache
          @cache ||= self.class.cache[hash]
        end

        def default_locale
          :en
        end
      end
    end
  end
end
