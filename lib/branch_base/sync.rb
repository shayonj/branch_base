# frozen_string_literal: true

module BranchBase
  class Sync
    BATCH_SIZE = 10_000 # Adjust this based on performance testing

    def initialize(database, repository)
      @db = database
      @repo = repository
    end

    def run
      # Disable foreign key checks for performance
      @db.execute("PRAGMA foreign_keys = OFF")

      # @db.transaction do
      repo_id = sync_repository
      sync_branches(repo_id)
      sync_commits(repo_id)
      # end

      # Re-enable foreign key checks
      @db.execute("PRAGMA foreign_keys = ON")
    end

    private

    def sync_repository
      repo_path = @repo.path.chomp(".git/")
      repo_name = File.basename(repo_path)

      existing_repo_id =
        @db.execute(
          "SELECT repo_id FROM repositories WHERE url = ?",
          [repo_path],
        ).first
      return existing_repo_id[0] if existing_repo_id

      @db.execute(
        "INSERT INTO repositories (name, url) VALUES (?, ?)",
        [repo_name, repo_path],
      )
      @db.last_insert_row_id
    end

    def sync_branches(repo_id)
      batched_branches = []

      @repo.branches.each do |branch|
        next if branch.name.nil? || branch.target.nil?

        commit_oid =
          (
            if branch.target.respond_to?(:oid)
              branch.target.oid
            else
              branch.target.target.oid
            end
          )
        batched_branches << [repo_id, branch.name, commit_oid]

        if batched_branches.size >= BATCH_SIZE
          insert_branches(batched_branches)
          batched_branches.clear
        end
      end

      insert_branches(batched_branches) unless batched_branches.empty?
    end

    def sync_commits(repo_id)
      batched_commits = []
      batched_files = []

      @repo.walk do |commit|
        next if commit_exists?(commit.oid)

        batched_commits << [
          commit.oid,
          repo_id,
          commit.author[:name],
          commit.committer[:name],
          commit.message,
          commit.time.to_s,
        ]

        if batched_commits.size >= BATCH_SIZE
          insert_commits(batched_commits)
          batched_commits.clear
        end

        commit.diff.each_patch do |patch|
          file_path = patch.delta.new_file[:path]
          batched_files << [repo_id, file_path, commit.oid, patch.to_s]

          if batched_files.size >= BATCH_SIZE
            insert_files_and_commit_files(batched_files)
            batched_files.clear
          end
        end

        insert_commit_parents(commit)
      end

      insert_commits(batched_commits) unless batched_commits.empty?
      insert_files_and_commit_files(batched_files) unless batched_files.empty?
    end

    def commit_exists?(commit_hash)
      @db.execute(
        "SELECT COUNT(*) FROM commits WHERE commit_hash = ?",
        [commit_hash],
      ).first[
        0
      ].positive?
    end

    def insert_commit_files(commit, repo_id)
      commit.diff.each_patch do |patch|
        file_path = patch.delta.new_file[:path]
        @db.execute(
          "INSERT OR IGNORE INTO files (repo_id, file_path, latest_commit) VALUES (?, ?, ?)",
          [repo_id, file_path, commit.oid],
        )
        file_id = @db.last_insert_row_id
        @db.execute(
          "INSERT INTO commit_files (commit_hash, file_id, changes) VALUES (?, ?, ?)",
          [commit.oid, file_id, patch.to_s],
        )
      end
    end

    def insert_commit_parents(commit)
      commit.parent_ids.each do |parent_id|
        @db.execute(
          "INSERT INTO commit_parents (commit_hash, parent_hash) VALUES (?, ?)",
          [commit.oid, parent_id],
        )
      end
    end

    def insert_branches(batched_branches)
      @db.transaction do
        batched_branches.each do |data|
          @db.execute(
            "INSERT OR IGNORE INTO branches (repo_id, name, head_commit) VALUES (?, ?, ?)",
            data,
          )
        end
      end
    end

    def insert_commits(batched_commits)
      @db.transaction do
        batched_commits.each do |data|
          @db.execute(
            "INSERT INTO commits (commit_hash, repo_id, author, committer, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)",
            data,
          )
        end
      end
    end

    def insert_files_and_commit_files(batched_data)
      @db.transaction do
        batched_data.each do |data|
          repo_id, file_path, commit_hash, changes = data
          @db.execute(
            "INSERT OR IGNORE INTO files (repo_id, file_path, latest_commit) VALUES (?, ?, ?)",
            [repo_id, file_path, commit_hash],
          )
          file_id = @db.last_insert_row_id
          @db.execute(
            "INSERT INTO commit_files (commit_hash, file_id, changes) VALUES (?, ?, ?)",
            [commit_hash, file_id, changes],
          )
        end
      end
    end
  end
end
