# frozen_string_literal: true

require "json"
require "open3"
require "digest"

require "dependabot/errors"
require "dependabot/shared_helpers"
require "dependabot/pub/requirement"

module Dependabot
  module Pub
    module Helpers
      def run_dependency_services(command, args = [], dependency_changes: nil)
        SharedHelpers.in_a_temporary_directory do
          dependency_files.each do |f|
            FileUtils.mkdir_p File.dirname(f.name)
            File.write(f.name, f.content)
          end
          SharedHelpers.with_git_configured(credentials: credentials) do
            stdout, stderr, status = Open3.capture3(
              {
                "CI" => "true",
                "PUB_ENVIRONMENT" => "dependabot",
                "FLUTTER_ROOT" => "/opt/dart/flutter"
              },
              "dart",
              "pub",
              "global",
              "run",
              "pub:dependency_services",
              command,
              *args,
              stdin_data: dependencies_to_json(dependency_changes)
            )
            raise Dependabot::DependabotError, "dart pub failed: #{stderr}" unless status.success?

            updated_files = dependency_files.map do |f|
              updated_file = f.dup
              updated_file.content = File.read(f.name)
              updated_file
            end
            return updated_files, JSON.parse(stdout)["dependencies"]
          end
        end
      end

      def run_dependency_services_report
        sha256 = Digest::SHA256.new
        dependency_files.each do |f|
          sha256 << f.path + "\n" + f.content + "\n"
        end
        hash = sha256.hexdigest

        cache_file = "/tmp/report-#{hash}-pid-#{Process.pid}.json"
        return JSON.parse(File.read(cache_file)) if File.file?(cache_file)

        report = run_dependency_services("report")[1]
        File.write(cache_file, JSON.generate(report))
        report
      end

      def to_dependency(json)
        params = {
          name: json["name"],
          version: Dependabot::Pub::Version.new(json["version"]),
          package_manager: "pub",
          requirements: []
        }
        if json["kind"] != "transitive" && !json["constraint"].nil?
          constraint = json["constraint"]
          params[:requirements] << {
            requirement: Pub::Requirement.new(constraint, raw_constraint: constraint),
            groups: [json["kind"]],
            source: nil, # TODO: Expose some information about the source
            file: "pubspec.yaml" # TODO: Figure out how to handle mono-repos
          }
        end
        if json["previousVersion"]
          params = {
            **params,
            previous_version: Dependabot::Pub::Version.new(json["previousVersion"]),
            previous_requirements: []
          }
          if json["kind"] != "transitive" && !json["previousConstraint"].nil?
            constraint = json["previousConstraint"]
            params[:previous_requirements] << {
              requirement: Pub::Requirement.new(constraint, raw_constraint: constraint),
              groups: [json["kind"]],
              source: nil, # TODO: Expose some information about the source
              file: "pubspec.yaml"
            }
          end
        end
        Dependency.new(**params)
      end

      def dependencies_to_json(dependencies)
        if dependencies.nil?
          nil
        else
          deps = dependencies.map do |d|
            obj = {
              "name" => d.name,
              "version" => d.version
            }
            unless d.requirements.nil? && d.requirements.length > 1
              obj["constraint"] = d.requirements[0].requirement.to_s
            end
            obj
          end
          JSON.generate({
            "dependencyChanges" => deps
          })
        end
      end
    end
  end
end
