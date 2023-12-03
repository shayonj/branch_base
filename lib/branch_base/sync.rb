# frozen_string_literal: true

module BranchBase
  class Sync
    # TODO acctualy see if bulk inserts are faster
    BATCH_SIZE = 1000

    def initialize(database, repository)
      @db = database
      @repo = repository
    end

    def run
      @db.execute("PRAGMA foreign_keys = OFF")

      repo_id = sync_repository
      sync_branches(repo_id)
      sync_commits(repo_id)

      @db.execute("PRAGMA foreign_keys = ON")
    end

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
      BranchBase.logger.debug("Syncing branches for repository ID: #{repo_id}")

      default_branch_name = @repo.default_branch_name
      return unless default_branch_name

      @repo.branches.each do |branch|
        next if branch.name.nil? || branch.target.nil?

        branch_id = insert_branch(repo_id, branch.name)

        if branch.name == default_branch_name
          insert_branch_commits(branch_id, branch)
        end
      end
    end

    def insert_branch(repo_id, branch_name)
      existing_branch_id =
        @db.execute(
          "SELECT branch_id FROM branches WHERE name = ? AND repo_id = ?",
          [branch_name, repo_id],
        ).first
      return existing_branch_id[0] if existing_branch_id

      @db.execute(
        "INSERT INTO branches (repo_id, name) VALUES (?, ?)",
        [repo_id, branch_name],
      )
      @db.last_insert_row_id
    end

    def insert_branch_commits(branch_id, branch)
      BranchBase.logger.debug("Syncing branch commits for: #{branch.name}")

      head_commit = branch.target
      walker = Rugged::Walker.new(@repo.repo)
      walker.push(head_commit)

      walker.each do |commit|
        next if commit_exists?(commit.oid)

        @db.execute(
          "INSERT OR IGNORE INTO branch_commits (branch_id, commit_hash) VALUES (?, ?)",
          [branch_id, commit.oid],
        )
      end
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

    private

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
      BranchBase.logger.debug(
        "Inserting parent commits for repository: #{@repo.path}",
      )

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
      BranchBase.logger.debug(
        "Inserting commits for repository ID: #{@repo.path}",
      )

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
