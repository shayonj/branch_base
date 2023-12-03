# frozen_string_literal: true
require "test_helper"
require "spec_helper"

RSpec.describe(BranchBase::Sync) do
  let(:db) { BranchBase::Database.new(":memory:") }
  let(:repo_path) { "./mock_git_repo" }
  let(:repo) { BranchBase::Repository.new(repo_path.to_s) }
  let(:sync) { BranchBase::Sync.new(db, repo) }

  before do
    TestHelper.setup_mock_git_repo(repo_path)
    @repo_id = sync.sync_repository
  end

  after { TestHelper.delete_mock_git_repo(repo_path) }

  describe "#sync_repository" do
    context "when the repository does not exist in the database" do
      it "creates a new repository record and returns its ID" do
        repo_id = sync.sync_repository
        expect(repo_id).not_to be_nil

        stored_repo =
          db.execute(
            "SELECT * FROM repositories WHERE repo_id = ?",
            repo_id,
          ).first
        expect(stored_repo).not_to be_nil
        expect(stored_repo[1]).to eq(File.basename(repo_path))
        expect(stored_repo[2]).to include("mock_git_repo")
      end
    end

    context "when the repository already exists in the database" do
      it "returns the existing repository ID without creating a new record" do
        existing_repo_id = sync.sync_repository

        expect { sync.sync_repository }.not_to(
          change { db.execute("SELECT COUNT(*) FROM repositories").first[0] },
        )

        expect(sync.sync_repository).to eq(existing_repo_id)
      end
    end
  end

  describe "#sync_branches" do
    it "syncs all branches from the repository to the database" do
      sync.sync_branches(@repo_id)

      db_branches =
        db.execute("SELECT * FROM branches WHERE repo_id = ?", @repo_id)
      git_branches = repo.branches.map(&:name)

      expect(db_branches.size).to eq(git_branches.size)
      git_branches.each do |branch_name|
        expect(
          db_branches.any? { |db_branch| db_branch[2] == branch_name },
        ).to be(true)
      end
    end
  end

  describe "#sync_commits" do
    it "syncs all commits from the repository to the database" do
      sync.sync_commits(@repo_id)

      git_commits = repo.walk.to_a
      db_commits =
        db.execute("SELECT * FROM commits WHERE repo_id = ?", @repo_id)

      expect(db_commits.size).to eq(git_commits.size)
      git_commits.each do |commit|
        expect(
          db_commits.any? { |db_commit| db_commit[0] == commit.oid },
        ).to be(true)
      end
    end

    it "correctly handles batches based on BATCH_SIZE" do
      stub_const("BranchBase::Sync::BATCH_SIZE", 2)

      expect(sync).to receive(:insert_commits).and_call_original
      expect(sync).to receive(:insert_files_and_commit_files).and_call_original

      sync.sync_commits(@repo_id)
    end

    it "syncs all commits from the repository to the database" do
      sync.sync_commits(@repo_id)

      git_commits = repo.walk.to_a
      db_commits =
        db.execute("SELECT * FROM commits WHERE repo_id = ?", @repo_id)

      expect(db_commits.size).to eq(git_commits.size)
      git_commits.each do |commit|
        matched_commit =
          db_commits.find { |db_commit| db_commit[0] == commit.oid }
        expect(matched_commit).not_to be_nil
        expect(matched_commit[2]).to eq(commit.author[:name])
        expect(matched_commit[3]).to eq(commit.committer[:name])
        expect(matched_commit[4]).to eq(commit.message)
      end
    end
  end
end
