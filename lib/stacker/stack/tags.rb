require 'memoist'
require 'stacker/differ'
require 'stacker/resolver'
require 'stacker/stack/component'

module Stacker
  class Stack
    class Tags < Component

      extend Memoist

      # everything required by the template
      def template_definitions
        stack.template.local.fetch 'Tags', {}
      end

      def region_defaults
        stack.region.defaults.fetch 'tags', {}
      end

      # template defaults merged with region and stack-specific overrides
      def local
        region_defaults = stack.region.defaults.fetch 'tags', {}

        template_defaults = Hash[
          template_definitions.select { |_, opts|
            opts.key?('Default')
          }.map { |name, opts|
            [name, opts['Default']]
          }
        ]

        available = template_defaults.merge(
          region_defaults.merge(
            stack.options.fetch 'tags', {}
          )
        )
      end

      def missing
        template_definitions.keys - local.keys
      end

      def remote
        Hash[(((stack.region.client.describe_stacks stack_name: client.stack_name)[0])[0]).tags.map { |tag| [ tag.key, tag.value ] }]
      end
      memoize :remote

      def resolved
        resolver.resolved
      end
      memoize :resolved

      def resolver
        Resolver.new stack.region, local
      end
      memoize :resolver

      def diff *args
        Differ.yaml_diff Hash[resolved.sort], Hash[remote.sort], *args
      end
      memoize :diff

    end
  end
end
