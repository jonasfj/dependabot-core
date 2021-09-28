# frozen_string_literal: true

module Dependabot
  module Pub
    class FileUpdater < Dependabot::FileUpdaters::Base
      include Dependabot::Pub::Helpers

      def self.updated_files_regex
        [
          /^pubspec\.yaml$/,
          /^pubspec\.lock$/
        ]
      end

      def check_required_files
        raise "No pubspec.yaml!" unless get_original_file("pubspec.yaml")
      end

      def updated_dependency_files
        run_dependency_services("apply", dependency_changes: @dependencies)[0]
      end
    end
  end
end

Dependabot::FileUpdaters.register("pub", Dependabot::Pub::FileUpdater)
