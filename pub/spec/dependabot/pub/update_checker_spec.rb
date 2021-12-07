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
        "type" => "hosted",
        "host" => "pub.dartlang.org",
        "username" => "x-access-token",
        "password" => "token"
      }],
      ignored_versions: ignored_versions,
      pub_hosted_url: "http://localhost:#{@server[:Port]}",
    )
  end

  let(:ignored_versions) { [] }

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      # This version is ignored by dependency_services, but will be seen by base
      version: "0.0.0",
      requirements: requirements,
      package_manager: "pub"
    )
  end

  let(:dependency_name) { "retry" }
  let(:requirements) { [] }

  let(:dependency_files) do
    files = project_dependency_files(project)
    files.each do |file|
      # Simulate that the lockfile was from localhost:
     file.content.gsub!("https://pub.dartlang.org", "http://localhost:#{@server[:Port]}")
    end
    files
  end
  let(:project) { "can_update" }

  let(:can_update) { checker.can_update?(requirements_to_unlock: requirements_to_unlock) }
  let(:updated_requirements) { checker.updated_requirements }

  context "given an outdated dependency, not requiring unlock" do
    let(:dependency_name) { "collection" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end

    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end
  end
  context "given an outdated dependency, requiring unlock" do
    let(:dependency_name) { "retry" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end

    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end
  end
  context "given an outdated dependency, requiring full unlock" do
    let(:dependency_name) { "protobuf" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      it "can update" do
        expect(can_update).to be_truthy
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end

    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end
  end
  context "given an up-to-date dependency" do
    let(:dependency_name) { "path" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end

    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(can_update).to be_falsey
      end
    end
  end

  # TODO(sigurdm): more tests
end
