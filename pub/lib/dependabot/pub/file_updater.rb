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

      def updated_dependency_files
        changes = @dependencies.map { |d| "#{d.name}:#{d.version}" }
        run_dependency_services("apply", changes)[0]
      end
    end
  end
end

Dependabot::FileUpdaters.register("pub", Dependabot::Pub::FileUpdater)
