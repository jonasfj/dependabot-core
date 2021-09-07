# frozen_string_literal: true

# TODO: File and specs need to be updated

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"
require "dependabot/errors"

module Dependabot
  module Pub
    class FileUpdater < Dependabot::FileUpdaters::Base
      def self.updated_files_regex
        [/^pubspec\.yaml$/, /^pubspec\.lock$/]
      end

      def updated_dependency_files
        SharedHelpers.in_a_temporary_directory do
          dependency_files.each do |f|
            File.write(f.name, f.content)
          end
          SharedHelpers.with_git_configured(credentials: credentials) do
            args = dependencies.map { |dep| dep["name"] + ":" + dep["version"] }
            SharedHelpers.run_shell_command("#{command.join(' ')} apply #{args.join(' ')}")

            dependency_files.map.each do |_f|
              // Read the dependency files back...
            end
          end
        end
      end
    end
  end
end

Dependabot::FileUpdaters.
  register("pub", Dependabot::Pub::FileUpdater)
