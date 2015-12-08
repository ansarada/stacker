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
    @resolved ||= Hash[parameters.map do |name, value|
      if value.is_a? Hash
        stack = region.GetStack value.fetch('Stack')
        value = stack.outputs.fetch value.fetch('Output')
      end
		  retval = [ name, value ]
      #the following logging message will be reformatted in the future with more elaborate detail
		  #puts "Resolver.resolved finishing with #{retval}"
        [ name, value ]
      end]
    end

  end
end
