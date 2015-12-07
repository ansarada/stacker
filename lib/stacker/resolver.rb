module Stacker
  class Resolver

    attr_reader :region, :parameters

    def initialize region, parameters
      @region, @parameters = region, parameters
    end

    def dependencies
      @dependencies ||= parameters.select { |_, value|
        value.is_a?(Hash)
      }.map { |_, value|
        "#{value.fetch('Stack')}.#{value.fetch('Output')}"
      }
    end

    def resolved
	  puts "Resolver.resolved called"
	  puts "parameters are #{parameters}"
      @resolved ||= Hash[parameters.map do |name, value|
        if value.is_a? Hash
          stack = region.GetStack value.fetch('Stack')
          value = stack.outputs.fetch value.fetch('Output')
        end
		retval = [ name, value ]
		puts "Resolver.resolved finishing with #{retval}"
        [ name, value ]
      end]
    end

  end
end
