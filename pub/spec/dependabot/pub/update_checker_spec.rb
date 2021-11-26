# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/pub/update_checker"
require "webrick"

require_common_spec "update_checkers/shared_examples_for_update_checkers"

RSpec.describe Dependabot::Pub::UpdateChecker do
  it_behaves_like "an update checker"

  before(:all) do
    # Because we do the networking in dependency_services we have to run an
    # actual web server.
    @server = WEBrick::HTTPServer.new({ Port: 0, AccessLog: [] })
    Thread.new do
      @server.start
    end
  end

  after(:all) do
    @server.shutdown
  end

  before do
    sample_files.each do |f|
      package = File.basename(f, ".json")
      @server.mount_proc "/api/packages/#{package}" do |_req, res|
        res.body = File.read(File.join("..", "..", f))
      end
    end
  end

  after do
    sample_files.each do |f|
      package = File.basename(f, ".json")
      @server.unmount "/api/packages/#{package}"
    end
  end

  let(:sample_files) { Dir.glob(File.join("spec", "fixtures", "pub_dev_responses", sample, "*")) }
  let(:sample) { "simple" }

  let(:checker) do
    described_class.new(
      dependency: dependency,
      dependency_files: dependency_files,
      credentials: [{
        "type" => "git_source",
        "host" => "github.com",
        "username" => "x-access-token",
        "password" => "token"
      }],
      ignored_versions: ignored_versions,
      pub_hosted_url: "http://localhost:#{@server[:Port]}"
    )
  end

  let(:ignored_versions) { [] }

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: "2.0.0",
      requirements: requirements,
      package_manager: "pub"
    )
  end

  let(:dependency_name) { "retry" }
  let(:requirements) { [] }

  let(:dependency_files) do
    project_dependency_files(project)
  end

  describe "#can_update?" do
    subject { checker.can_update?(requirements_to_unlock: :own) }

    context "given an outdated dependency" do
      let(:project) { "hat_version_can_update" }
      it { is_expected.to be_truthy }
    end

    context "given an up-to-date dependency" do
      let(:project) { "hat_version_up_to_date" }
      it { is_expected.to be_falsey }
    end
  end

  # TODO(sigurdm): more tests
end
