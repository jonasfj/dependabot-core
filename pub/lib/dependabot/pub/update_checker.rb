# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"

module Dependabot
  module Pub
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      include Dependabot::Pub::Helpers

      def latest_version
        Dependabot::Pub::Version.new(current_report["latest"])
      end

      def latest_resolvable_version_with_no_unlock
        # Version we can get if we're not allowed to change pubspec.yaml, but we
        # allow changes in the pubspec.lock file.
        entry = current_report["compatible"].find { |d| d["name"] == dependency.name }
        Dependabot::Pub::Version.new(entry["version"]) if entry
      end

      def latest_resolvable_version
        # Latest version we can get if we're allowed to unlock the current
        # package in pubspec.yaml
        entry = current_report["single-breaking"].find { |d| d["name"] == dependency.name }
        Dependabot::Pub::Version.new(entry["version"]) if entry
      end

      def updated_requirements
        # Requirements that need to be changed, if obtain:
        # latest_resolvable_version
        entry = current_report["single-breaking"].find { |d| d["name"] == dependency.name }
        return unless entry

        to_dependency(entry).requirements
      end

      def latest_version_resolvable_with_full_unlock?
        entry = current_report["multi-breaking"].find { |d| d["name"] == dependency.name }
        # This a bit dumb, but full-unlock is only considered if we can get the
        # latest version!
        entry && latest_version != Dependabot::Pub::Version.new(entry["version"])
      end

      def updated_dependencies_after_full_unlock
        # We only expose direct-dependencies here...
        direct_deps = current_report["multi-breaking"].reject do |d|
          d["kind"] == "transitive"
        end
        direct_deps.map do |d|
          to_dependency(d)
        end
      end

      private

      def report
        @report ||= run_dependency_services_report
      end

      def current_report
        report.find { |d| d["name"] == dependency.name }
      end
    end
  end
end

Dependabot::UpdateCheckers.register("pub", Dependabot::Pub::UpdateChecker)
