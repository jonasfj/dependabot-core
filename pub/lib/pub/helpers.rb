# frozen_string_literal: true

require "json"
require "open3"

require "dependabot/errors"
require "dependabot/shared_helpers"
require "dependabot/pub/requirement"

module Dependabot
  module Pub
    module Helpers
      def run_dependency_services(command, args = [])
        SharedHelpers.in_a_temporary_directory do
          dependency_files.each do |f|
            File.write(f.name, f.content)
          end
          SharedHelpers.with_git_configured(credentials: credentials) do
            stdout, stderr, status = Open3.capture3(
              {
                "CI" => "true",
                "PUB_ENVIRONMENT" => "dependabot",
                "FLUTTER_ROOT" => nil # TODO: Configure FLUTTE_ROOT for all packages
              },
              [
                "dart",
                "pub",
                "__dependency_service",
                command,
                *args
              ]
            )
            raise Dependabot::DependabotError, "dart pub failed: #{stderr}" unless status.success?

            updated_files = dependency_files.each do |f|
              updated_file(f, File.read(f.name))
            end
            return updated_files, JSON.parse(stdout)["dependencies"]
          end
        end
      end

      def self.to_dependency(json)
        params = {
          name: json["name"],
          version: Dependabot::Pub::Version.new(json["version"]),
          package_manager: "pub",
          requirements: []
        }
        if json["kind"] != "transitive"
          constraint = json["constraint"]
          params[:requirements] << {
            requirement: Pub::Requirement.new(constraint, raw_constraint: constraint),
            groups: [json["kind"]],
            source: nil, # TODO: Expose some information about the source
            file: "pubspec.yaml"
          }
        end
        if json["previous"]
          params = {
            **params,
            previous_version: Dependabot::Pub::Version.new(json["previous"]),
            previous_requirements: []
          }
          if json["kind"] != "transitive"
            constraint = json["previousConstraint"]
            params[:previous_requirements] << {
              requirement: Pub::Requirement.new(constraint, raw_constraint: constraint),
              groups: [json["kind"]],
              source: nil, # TODO: Expose some information about the source
              file: "pubspec.yaml" # TODO: Figure out how to handle mono-repos
            }
          end
        end
        Dependency.new(**params)
      end
    end
  end
end
