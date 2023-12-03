# frozen_string_literal: true
require "branch_base/cli"
require "branch_base/database"
require "branch_base/repository"
require "branch_base/sync"
require "thor"
require "rspec"

RSpec.describe(BranchBase::CLI) do
  let(:cli) { BranchBase::CLI.new }
  let(:repo_path) { "path/to/repo" }
  let(:expanded_repo_path) { File.expand_path(repo_path) }
  let(:repo_name) { File.basename(expanded_repo_path) }
  let(:db_filename) { "#{repo_name}_git_data.db" }

  describe "#sync" do
    context "when the repository path is valid" do
      before do
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with(
          "#{expanded_repo_path}/.git"
        ).and_return(true)
        allow(BranchBase::Database).to receive(:new).with(
          db_filename
        ).and_return(double("Database"))
        allow(BranchBase::Repository).to receive(:new).with(
          expanded_repo_path
        ).and_return(double("Repository"))
        allow(BranchBase::Sync).to receive(:new).and_return(
          double("Sync", run: nil)
        )
      end

      it "syncs the repository data" do
        expect { cli.sync(repo_path) }.to output(
          "Repository data synced successfully for\n"
        ).to_stdout
      end
    end

    context "when the repository path is not valid" do
      it "exits with an error message" do
        allow(File).to receive(:directory?).with(
          "#{expanded_repo_path}/.git"
        ).and_return(false)
        expect { cli.sync(repo_path) }.to output(
          "The specified path is not a valid Git repository: #{expanded_repo_path}\n"
        ).to_stdout.and raise_error(SystemExit)
      end
    end
  end
end
