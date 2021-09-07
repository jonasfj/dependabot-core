# frozen_string_literal: true

require "cgi"
require "excon"
require "nokogiri"
require "open3"
require "yaml"
require "dependabot/dependency"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/git_commit_checker"
require "dependabot/errors"

module Dependabot
  module Pub
    class FileParser < Dependabot::FileParsers::Base
      @command = %w(dart pub __dependency-services)

      def parse
        SharedHelpers.in_a_temporary_directory do
          dependency_files.each do |f|
            File.write(f.name, f.content)
          end
          SharedHelpers.with_git_configured(credentials: credentials) do
            output = SharedHelpers.run_shell_command("#{command.join(' ')} list")
            JSON.parse(output)["dependencies"].map do |dep|
              Dependency.new(
                name: dep["name"],
                version: dep["version"],
                package_manager: "pub"
              )
            end
          end
        end
      end
    end
  end
end

Dependabot::FileParsers.
  register("pub", Dependabot::Pub::FileParser)
