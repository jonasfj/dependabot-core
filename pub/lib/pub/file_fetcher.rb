# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"
require "dependabot/cargo/file_parser"

# For details on pub packages, see:
# https://dart.dev/tools/pub/package-layout#the-pubspec
module Dependabot
  module Pub
    class FileFetcher < Dependabot::FileFetchers::Base
      def self.required_files_in?(filenames)
        filenames.include?("pubspec.yaml")
      end

      def self.required_files_message
        "Repo must contain a pubspec.yaml."
      end

      private

      def fetch_files
        fetched_files = []
        fetched_files << pubspec_yaml
        fetched_files << pubspec_lock if cargo_lock
        fetched_files.uniq
      end

      def pubspec_yaml
        @pubspec_yaml ||= fetch_file_from_host("pubspec.yaml")
      end

      def pubspec_lock
        @pubspec_lock ||= fetch_file_from_host("pubspec.lock")
      end
    end
  end
end

Dependabot::FileFetchers.register("pub", Dependabot::Pub::FileFetcher)
