# frozen_string_literal: true

require "json"
require "yaml"

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/pub/requirement"
require "dependabot/pub/version"

module Dependabot
  module Pub
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      def latest_version
        current_dependency["latest"]
      end

      def latest_resolvable_version_with_no_unlock
        entry = current_dependency["compatible"].find { |dep| dep["name"] == dependency.name }
        Dependabot::Pub::Version.new(entry["version"]) if entry
      end

      def latest_resolvable_version
        entry = current_dependency["single-breaking"].find { |dep| dep["name"] == dependency.name }
        Dependabot::Pub::Version.new(entry["version"]) if entry
      end

      def latest_version_resolvable_with_full_unlock?
        entry = current_dependency["multi-breaking"].find { |dep| dep["name"] == dependency.name }
        if !entry
          false
        else
          latest_resolvable_version != Dependabot::Pub::Version.new(entry["version"])
        end
      end

      def updated_dependencies_after_full_unlock
        current_dependency["multi-breaking"].map do |dep|
          Dependency.new(
            name: dep["name"],
            version: dep["version"],
            previous_version: report.find { |old| old["name"] == dep["name"] } ["version"],
            package_manager: "pub"
          )
        end
      end

      def updated_requirements
        nil
      end

      private

      def report
        @report ||= SharedHelpers.in_a_temporary_directory do
          dependency_files.each do |f|
            File.write(f.name, f.content)
          end
          SharedHelpers.with_git_configured(credentials: credentials) do
            output = SharedHelpers.run_shell_command("#{command.join(' ')} report")
            JSON.parse(output)["dependencies"]
          end
        end
      end

      def current_dependency
        report.find { |dep| dep["name"] == dependency.name }
      end
    end
  end
end

Dependabot::UpdateCheckers.register("pub", Dependabot::Pub::UpdateChecker)
