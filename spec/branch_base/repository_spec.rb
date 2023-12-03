# frozen_string_literal: true
require "branch_base/repository"
require "rugged"
require "rspec"
require "test_helper"

RSpec.describe(BranchBase::Repository) do
  let(:repo_path) { "./mock_git_repo" }
  let(:repository) { BranchBase::Repository.new(repo_path) }

  before { TestHelper.setup_mock_git_repo(repo_path) }

  after { TestHelper.delete_mock_git_repo(repo_path) }

  describe "#initialize" do
    it "initializes with a given repository path" do
      expect(repository).to be_a(BranchBase::Repository)
    end
  end

  describe "#walk" do
    it "iterates over the specific commits in the repository" do
      commit_messages = []
      repository.walk { |commit| commit_messages << commit.message.strip }
      expect(commit_messages).to contain_exactly(
        "Add contributing guidelines",
        "Initial commit"
      )
    end
  end

  describe "#path" do
    it "returns the path of the repository" do
      expect(repository.path).to include("mock_git_repo/.git/")
    end
  end

  describe "#branches" do
    it "returns the specific branches in the repository" do
      branch_names = repository.branches.map(&:name)
      expect(branch_names).to include("main", "new_branch")
    end
  end
end
