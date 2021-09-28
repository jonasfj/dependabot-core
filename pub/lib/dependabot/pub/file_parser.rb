# frozen_string_literal: true

require "dependabot/dependency"
require "dependabot/pub/version"
require "dependabot/pub/helpers"

module Dependabot
  module Pub
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"
      include Dependabot::Pub::Helpers

      def parse
        dependency_set = DependencySet.new
        list.map do |d|
          dependency_set << Dependabot::Pub::Helpers.to_dependency(d)
        end
        dependency_set
      end

      def check_required_files
        raise "No pubspec.yaml!" unless get_original_file("pubspec.yaml")
      end

      private

      def list
        @list ||= run_dependency_services("list")[1]
      end
    end
  end
end

Dependabot::FileParsers.register("pub", Dependabot::Pub::FileParser)
