module Artisanal::Model
  class Attribute < Module
    attr_reader :name, :type, :options

    def initialize(name, coercer=nil, **options)
      @name = name
      @type = coercer || options[:type]
      @options = options

      if options.has_key? :from
        @name, options[:as] = options[:from], name
      end

      raise ArgumentError.new("type missing for attribute #{name}") if type.nil?
    end

    def included(base)
      # Create dry-initializer option
      base.option(name, type_builder(type), **options)

      # Create writer method
      define_writer(base, name) if options[:writer]
    end

    protected

    def define_writer(base, target)
      define_method("#{target}=") do |value|
        artisanal_model.schema[target].type.call(value).tap do |result|
          instance_variable_set("@#{target}", result)
        end
      end

      # Scope writer to protected or private
      if [:protected, :private].include? options[:writer]
        base.send(options[:writer], "#{target}=")
      end
    end

    def type_builder(type)
      case type
      when Class
        ->(value) { type.new(value) }
      when Enumerable
        coercer = type_builder(type.first)
        ->(collection) { type.class.new(collection.map { |value| coercer.call(value) }) }
      else
        type
      end
    end
  end
end