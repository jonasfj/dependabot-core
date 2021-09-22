# frozen_string_literal: true

require "dependabot/metadata_finders"
require "dependabot/metadata_finders/base"
require "dependabot/shared_helpers"

module Dependabot
  module Pub
    class MetadataFinder < Dependabot::MetadataFinders::Base
      private

      def look_up_source
        # TODO: Find a link to changelog on pub.dev when possible.
        nil
      end
    end
  end
end

Dependabot::MetadataFinders.register("pub", Dependabot::Pub::MetadataFinder)
