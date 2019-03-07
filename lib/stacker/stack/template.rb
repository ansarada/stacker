require 'active_support/core_ext/string/inflections'
require 'json'
require 'memoist'
require 'stacker/differ'
require 'stacker/stack/component'

module Stacker
  class Stack
    class Template < Component

      FORMAT_VERSION = '2010-09-09'

      extend Memoist

      def exists?
        File.exists? path
      end

      def local
        @local ||= begin
          if exists?
            Stacker.logger.info "path: #{path}"
            template = JSON.parse File.read path
            template['AWSTemplateFormatVersion'] ||= FORMAT_VERSION
            Stacker.logger.info "template: #{template}"
            template
          else
            {}
          end
        end
      end
	  
	  def localStr
        JSONFormatter.format(local)
      end

      def remote
		@remote ||= JSON.parse (stack.region.client.get_template stack_name: client.stack_name).template_body
      rescue AwS::CloudFormation::Errors::ValidationError => err
        if err.message =~ /does not exist/
          raise DoesNotExistError.new err.message
        else
          raise Error.new err.message
        end
      end

      def diff *args
        Differ.json_diff local, remote, *args
      end
      memoize :diff

      def write value = local
        File.write path, JSONFormatter.format_prety(value)
      end

      def dump
        write remote
      end

      private

      def path
        @path ||= File.join(
          stack.region.templates_path,
          "#{stack.options.fetch('template_name', stack.name)}.json"
        )
      end

      class JSONFormatter
        STR = '\"[^\"]+\"'

        def self.format object
          formatted = JSON.generate object

          # put empty arrays on a single line
          formatted.gsub! /: \[\s*\]/m, ': []'

          # put { "Ref": ... } on a single line
          formatted.gsub! /\{\s+\"Ref\"\:\s+(?<ref>#{STR})\s+\}/m,
            '{ "Ref": \\k<ref> }'

          # put { "Fn::GetAtt": ... } on a single line
          formatted.gsub! /\{\s+\"Fn::GetAtt\"\: \[\s+(?<key>#{STR}),\s+(?<val>#{STR})\s+\]\s+\}/m,
            '{ "Fn::GetAtt": [ \\k<key>, \\k<val> ] }'

          formatted + "\n"
        end

        def self.format_prety object
          formatted = JSON.pretty_generate object

          # put empty arrays on a single line
          formatted.gsub! /: \[\s*\]/m, ': []'

          # put { "Ref": ... } on a single line
          formatted.gsub! /\{\s+\"Ref\"\:\s+(?<ref>#{STR})\s+\}/m,
            '{ "Ref": \\k<ref> }'

          # put { "Fn::GetAtt": ... } on a single line
          formatted.gsub! /\{\s+\"Fn::GetAtt\"\: \[\s+(?<key>#{STR}),\s+(?<val>#{STR})\s+\]\s+\}/m,
            '{ "Fn::GetAtt": [ \\k<key>, \\k<val> ] }'

          formatted + "\n"
        end
      end

    end
  end
end
