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
    dev_null = WEBrick::Log.new("/dev/null", 7)
    @server = WEBrick::HTTPServer.new({ Port: 0, AccessLog: [], Logger: dev_null })
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
      options: {
        pub_hosted_url: "http://localhost:#{@server[:Port]}"
      },
      raise_on_ignored: raise_on_ignored,
      requirements_update_strategy: requirements_update_strategy
    )
  end

  let(:ignored_versions) { [] }
  let(:raise_on_ignored) { false }

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      # This version is ignored by dependency_services, but will be seen by base
      version: dependency_version,
      requirements: requirements,
      package_manager: "pub"
    )
  end
  let(:dependency_version) { "0.0.0" }

  let(:requirements_update_strategy) { nil } # nil means "auto".
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
  let(:directory) { nil }

  let(:can_update) { checker.can_update?(requirements_to_unlock: requirements_to_unlock) }
  let(:updated_dependencies) do
    checker.updated_dependencies(requirements_to_unlock: requirements_to_unlock).map(&:to_h)
  end

  context "given an outdated dependency, not requiring unlock" do
    let(:dependency_name) { "collection" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      it "can update" do
        expect(can_update).to be_truthy
        expect(updated_dependencies).to eq [
          { "name" => "collection",
            "package_manager" => "pub",
            "previous_requirements" => [{
              file: "pubspec.yaml", groups: ["direct"], requirement: "^1.14.13", source: nil
            }],
            "previous_version" => "1.14.13",
            "requirements" => [{
              file: "pubspec.yaml", groups: ["direct"], requirement: "^1.15.0", source: nil
            }],
            "version" => "1.15.0" }
        ]
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      context "with auto-strategy" do
        context "app (no version)" do
          it "can update" do
            expect(can_update).to be_truthy
            expect(updated_dependencies).to eq [
              { "name" => "collection",
                "package_manager" => "pub",
                "previous_requirements" => [],
                # Dependabot lifts this from the original dependency.
                "previous_version" => "0.0.0",
                "requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^1.15.0", source: nil
                }],
                "version" => "1.15.0" }
            ]
          end
        end
        context "library (has version)" do
          let(:project) { "can_update_library" }

          it "can update" do
            expect(can_update).to be_truthy
            expect(updated_dependencies).to eq [
              { "name" => "collection",
                "package_manager" => "pub",
                "previous_requirements" => [],
                # Dependabot lifts this from the original dependency.
                "previous_version" => "0.0.0",
                "requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^1.14.13", source: nil
                }],
                "version" => "1.15.0" }
            ]
          end
        end
      end
      context "with bump_versions strategy" do
        let(:requirements_update_strategy) { "bump_versions" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "collection",
              "package_manager" => "pub",
              "previous_requirements" => [],
              # Dependabot lifts this from the original dependency.
              "previous_version" => "0.0.0",
              "requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^1.15.0", source: nil
              }],
              "version" => "1.15.0" }
          ]
        end
      end
      context "with bump_versions_if_necessary strategy" do
        let(:requirements_update_strategy) { "bump_versions_if_necessary" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "collection",
              "package_manager" => "pub",
              "previous_requirements" => [],
              # Dependabot lifts this from the original dependency.
              "previous_version" => "0.0.0",
              "requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^1.14.13", source: nil
              }],
              "version" => "1.15.0" }
          ]
        end
      end
      context "with widen_ranges strategy" do
        let(:requirements_update_strategy) { "widen_ranges" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "collection",
              "package_manager" => "pub",
              "previous_requirements" => [],
              # Dependabot lifts this from the original dependency.
              "previous_version" => "0.0.0",
              "requirements" => [{
                # No widening needed for this update.
                file: "pubspec.yaml", groups: ["direct"], requirement: "^1.14.13", source: nil
              }],
              "version" => "1.15.0" }
          ]
        end
      end
    end

    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(can_update).to be_truthy
        expect(updated_dependencies).to eq [
          { "name" => "collection",
            "package_manager" => "pub",
            "previous_requirements" => [],
            # Dependabot lifts this from the original dependency.
            "previous_version" => "0.0.0",
            "requirements" => [],
            "version" => "1.15.0" }
        ]
      end
    end

    context "will not upgrade to ignored version" do
      let(:requirements_to_unlock) { :none }
      let(:ignored_versions) { ["1.15.0"] }
      it "cannot update" do
        expect(can_update).to be_falsey
      end
    end
  end
  context "given an outdated dependency, requiring unlock" do
    let(:dependency_name) { "retry" }

    context "unlocking all" do
      let(:requirements_to_unlock) { :all }
      context "with auto-strategy" do
        context "app (no version)" do
          it "can update" do
            expect(can_update).to be_truthy
            expect(updated_dependencies).to eq [
              { "name" => "retry",
                "package_manager" => "pub",
                "previous_requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
                }],
                "previous_version" => "2.0.0",
                "requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^3.1.0", source: nil
                }],
                "version" => "3.1.0" }
            ]
          end
        end
        context "app (version but publish_to: none)" do
          let(:project) { "can_update_publish_to_none" }
          it "can update" do
            expect(can_update).to be_truthy
            expect(updated_dependencies).to eq [
              { "name" => "retry",
                "package_manager" => "pub",
                "previous_requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
                }],
                "previous_version" => "2.0.0",
                "requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^3.1.0", source: nil
                }],
                "version" => "3.1.0" }
            ]
          end
        end
        context "library (has version)" do
          let(:project) { "can_update_library" }
          it "can update" do
            expect(can_update).to be_truthy
            expect(updated_dependencies).to eq [
              { "name" => "retry",
                "package_manager" => "pub",
                "previous_requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
                }],
                "previous_version" => "2.0.0",
                "requirements" => [{
                  file: "pubspec.yaml", groups: ["direct"], requirement: ">=2.0.0 <4.0.0", source: nil
                }],
                "version" => "3.1.0" }
            ]
          end
        end
      end
      context "with bump_versions strategy" do
        let(:requirements_update_strategy) { "bump_versions" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "retry",
              "package_manager" => "pub",
              "previous_requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
              }],
              "previous_version" => "2.0.0",
              "requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^3.1.0", source: nil
              }],
              "version" => "3.1.0" }
          ]
        end
      end
      context "with bump_versions_if_necessary strategy" do
        let(:requirements_update_strategy) { "bump_versions_if_necessary" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "retry",
              "package_manager" => "pub",
              "previous_requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
              }],
              "previous_version" => "2.0.0",
              "requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^3.1.0", source: nil
              }],
              "version" => "3.1.0" }
          ]
        end
      end
      context "with widen_ranges strategy" do
        let(:requirements_update_strategy) { "widen_ranges" }
        it "can update" do
          expect(can_update).to be_truthy
          expect(updated_dependencies).to eq [
            { "name" => "retry",
              "package_manager" => "pub",
              "previous_requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: "^2.0.0", source: nil
              }],
              "previous_version" => "2.0.0",
              "requirements" => [{
                file: "pubspec.yaml", groups: ["direct"], requirement: ">=2.0.0 <4.0.0", source: nil
              }],
              "version" => "3.1.0" }
          ]
        end
      end
    end

    context "unlocking own" do
      let(:requirements_to_unlock) { :own }
      it "can update" do
        expect(can_update).to be_truthy
        expect(updated_dependencies).to eq [
          { "name" => "retry",
            "package_manager" => "pub",
            "previous_requirements" => [],
            "previous_version" => "0.0.0",
            "requirements" => [{
              file: "pubspec.yaml", groups: ["direct"], requirement: "^3.1.0", source: nil
            }],
            "version" => "3.1.0" }
        ]
      end
    end

    context "will not upgrade to ignored version" do
      let(:requirements_to_unlock) { :own }
      let(:ignored_versions) { ["3.1.0"] }
      it "cannot update" do
        expect(can_update).to be_falsey
        # Ideally we could update to 3.0.0 here. This is currently a limitation
        # of the pub dependency_services.
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
        expect(updated_dependencies).to eq [
          {
            "name" => "protobuf",
            "version" => "2.0.0",
            "requirements" => [{ requirement: "^2.0.0", groups: ["direct"], source: nil, file: "pubspec.yaml" }],
            "previous_version" => "1.1.4",
            "previous_requirements" => [{
              requirement: "1.1.4", groups: ["direct"], source: nil, file: "pubspec.yaml"
            }],
            "package_manager" => "pub"
          },
          {
            "name" => "fixnum",
            "version" => "1.0.0",
            "requirements" => [{ requirement: "^1.0.0", groups: ["direct"], source: nil, file: "pubspec.yaml" }],
            "previous_version" => "0.10.11",
            "previous_requirements" => [{
              requirement: "0.10.11", groups: ["direct"], source: nil, file: "pubspec.yaml"
            }],
            "package_manager" => "pub"
          }

        ]
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

  context "mono repo" do
    let(:project) { "mono_repo_main_at_root" }
    let(:dependency_name) { "dep" }
    context "unlocking none" do
      let(:requirements_to_unlock) { :none }
      it "can update" do
        expect(checker.latest_version.to_s).to eq "1.0.0"
        expect(can_update).to be_falsey
      end
    end
  end

  context "when raise_on_ignored is true" do
    let(:raise_on_ignored) { true }

    context "when later versions are allowed" do
      let(:dependency_name) { "collection" }
      let(:dependency_version) { "1.14.13" }
      let(:ignored_versions) { ["< 1.14.13"] }

      it "doesn't raise an error" do
        expect { checker.latest_version }.to_not raise_error
      end
    end

    context "when the user is on the latest version" do
      let(:dependency_name) { "path" }
      let(:dependency_version) { "1.8.0" }
      let(:ignored_versions) { ["> 1.8.0"] }

      it "doesn't raise an error" do
        expect { checker.latest_version }.to_not raise_error
      end
    end

    context "when the user is on the latest version but it's ignored" do
      let(:dependency_name) { "path" }
      let(:dependency_version) { "1.8.0" }
      let(:ignored_versions) { [">= 0"] }

      it "doesn't raise an error" do
        expect { checker.latest_version }.to_not raise_error
      end
    end

    context "when the user is ignoring all later versions" do
      let(:dependency_name) { "collection" }
      let(:dependency_version) { "1.14.13" }
      let(:ignored_versions) { ["> 1.14.13"] }
      let(:raise_on_ignored) { true }

      it "raises an error" do
        expect { checker.latest_version }.to raise_error(Dependabot::AllVersionsIgnored)
      end
    end
  end
end
