require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/module/delegation'
require 'aws-sdk'
require 'memoist'
require 'stacker/stack/capabilities'
require 'stacker/stack/parameters'
require 'stacker/stack/template'
require 'logger'

module Stacker
  class Stack

    class Error < StandardError; end
    class StackPolicyError < Error; end
    class DoesNotExistError < Error; end
    class MissingParameters < Error; end
    class UpToDateError < Error; end

    extend Memoist

    CLIENT_METHODS = %w[
      creation_time
      description
      exists?
      last_updated_time   
	  stack_status	
      status_reason
    ]

    SAFE_UPDATE_POLICY = <<-JSON
{
  "Statement" : [
    {
      "Effect" : "Deny",
      "Action" : ["Update:Replace", "Update:Delete"],
      "Principal" : "*",
      "Resource" : "*"
    },
    {
      "Effect" : "Allow",
      "Action" : "Update:*",
      "Principal" : "*",
      "Resource" : "*"
    }
  ]
}
JSON

    attr_reader :region, :name, :options

    def initialize region, name, options = {}
      @region, @name, @options = region, name, options
    end

    def client
	  Stacker.logger.info "[INFO] stack name is: #{name}"	
	  @client = (region.client.describe_stacks stack_name: name)[0]

	  Stacker.logger.info "[INFO] stack name is passed successfully: #{name}"
	  return @client[0]
    end

    delegate *CLIENT_METHODS, to: :client
    memoize *CLIENT_METHODS

    %w[complete failed in_progress].each do |stage|
      define_method(:"#{stage}?") { status =~ /#{stage.upcase}/ }
    end

    def template
      @template ||= Template.new self
    end

    def parameters
      @parameters ||= Parameters.new self
    end

    def capabilities
      @capabilities ||= Capabilities.new self
    end

    def outputs
	  puts "output method called"  
	  @outputs = Hash[client.outputs.map { |output| [ output.output_key, output.output_value ] }]  
	  return @outputs
      #@outputs ||= begin
      #  return {} unless complete?
	  #	puts "calling hash"
      #  Hash[client.outputs.map { |output| [ output.output_key, output.output_value ] }]
      #end
    end

    def create blocking = true
      # if exists?
        # Stacker.logger.warn 'Stack already exists'
        # return
      # end

      if parameters.missing.any?
        raise MissingParameters.new(
          "Required parameters missing: #{parameters.missing.join ', '}"
        )
      end

      Stacker.logger.info 'Creating stack'
		
	  hashParams = parameters.resolved.map { |key, value| {"parameter_key" => key, "parameter_value" => value} }
	  
	  
      region.client.create_stack(
        stack_name: name,
        template_body: template.localStr,
        parameters: hashParams,
        capabilities: capabilities.local,
        disable_rollback: true
      )

      sleep 90

      wait_while_status 'CREATE_IN_PROGRESS' if blocking
    rescue Aws::CloudFormation::Errors::ValidationError => err
      raise Error.new err.message
    end

    def update options = {}
	Stacker.logger.info 'update stack called'
      options.assert_valid_keys(:blocking, :allow_destructive)

      blocking = options.fetch(:blocking, true)
      allow_destructive = options.fetch(:allow_destructive, false)

      if parameters.missing.any?
        raise MissingParameters.new(
          "Required parameters missing: #{parameters.missing.join ', '}"
        )
      end

      Stacker.logger.info 'Updating stack'
	  
	  hashParams = parameters.resolved.map { |key, value| {"parameter_key" => key, "parameter_value" => value} }
	  
	   update_params = {
	     stack_name: name,
         template_body: template.localStr,
         parameters: hashParams,
         capabilities: capabilities.local
       }

      unless allow_destructive
        update_params[:stack_policy_during_update_body] = SAFE_UPDATE_POLICY
      end

	  region.client.update_stack(update_params)

      sleep 30

      wait_while_status 'UPDATE_IN_PROGRESS' if blocking
    rescue Aws::CloudFormation::Errors::ValidationError => err
      case err.message
      when /does not exist/
        raise DoesNotExistError.new err.message
      when /No updates/
        raise UpToDateError.new err.message
      else
        raise Error.new err.message
      end
    end

    private

    def report_status
	  Stacker.logger.info "[INFO] report_status called"	
      case stack_status
      when /_COMPLETE$/
        Stacker.logger.info "#{name} Status => #{stack_status}"
      when /ROLLBACK_IN_PROGRESS$/, /_FAILED$/
        failure_event = client.events.enum(limit: 30).find do |event|
          event.resource_status =~ /_FAILED$/
        end
        failure_reason = failure_event.nil? ? "Unknown failure reason" : failure_event.resource_status_reason
        if failure_reason =~ /stack policy/
          raise StackPolicyError.new failure_reason
        else
          Stacker.logger.fatal "#{name} Status => #{stack_status}"
          raise Error.new "Failure Reason: #{failure_reason}"
        end
      else
        Stacker.logger.debug "#{name} Status => #{stack_status}"
      end
    end

    def wait_while_status wait_status 
      while flush_cache(:stack_status) && ((region.client.describe_stacks stack_name: name)[0])[0].stack_status == wait_status
		report_status
        sleep 15
      end
      report_status
    end

  end
end

