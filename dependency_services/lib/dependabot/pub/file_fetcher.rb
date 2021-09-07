# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module Pub
    class FileFetcher < Dependabot::FileFetchers::Base
      @required_files = [
        "pubspec.yaml"
      ]
      @optional_files = [
        "pubspec.lock"
      ]

      def self.required_files_in?(filenames)
        required_files.all? { |name| filenames.include?(name) }
      end

      def self.required_files_message
        "Repo must contain: #{@required_files.join(', ')}."
      end

      private

      def fetch_files
        files = []

        @required_files.each do |f|
          files << fetch_file_from_host(f)
        end
        @optional_files.each do |f|
          file = fetch_file_from_host(f)
          files << file if file
        end

        files
      end
    end
  end
end

Dependabot::FileFetchers.
  register("pub", Dependabot::Pub::FileFetcher)
