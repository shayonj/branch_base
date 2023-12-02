# frozen_string_literal: true

require "sqlite3"

module BranchBase
  class Database
    def initialize(db_path)
      @db = SQLite3::Database.new(db_path)
      setup_schema
    end

    def execute(query, *params)
      @db.execute(query, *params)
    end

    def prepare(statement)
      @db.prepare(statement)
    end

    def transaction(&block)
      @db.transaction(&block)
    end

    def last_insert_row_id
      @db.last_insert_row_id
    end

    def commit_exists?(commit_hash)
      query = "SELECT COUNT(*) FROM commits WHERE commit_hash = ?"
      execute(query, commit_hash).first[0].positive?
    end

    def insert_commit(repo_id, commit)
      return if commit_exists?(commit.oid)

      query =
        "INSERT INTO commits (commit_hash, repo_id, author, committer, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)"
      execute(
        query,
        commit.oid,
        repo_id,
        commit.author[:name],
        commit.committer[:name],
        commit.message,
        commit.time.to_s
      )
    end

    def get_or_insert_repo_id(name, path)
      query = "SELECT repo_id FROM repositories WHERE url = ?"
      result = execute(query, path).first
      return result[0] if result

      execute("INSERT INTO repositories (name, url) VALUES (?, ?)", name, path)
      last_insert_row_id
    end

    private

    def setup_schema
      @db.execute_batch(<<-SQL)
        CREATE TABLE IF NOT EXISTS repositories (
          repo_id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS commits (
          commit_hash TEXT PRIMARY KEY,
          repo_id INTEGER NOT NULL,
          author TEXT NOT NULL,
          committer TEXT NOT NULL,
          message TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          FOREIGN KEY (repo_id) REFERENCES repositories (repo_id)
        );

        CREATE INDEX IF NOT EXISTS idx_commits_repo_id ON commits (repo_id);
        CREATE INDEX IF NOT EXISTS idx_commits_author ON commits (author);
        CREATE INDEX IF NOT EXISTS idx_commits_committer ON commits (committer);

        CREATE TABLE IF NOT EXISTS branches (
          branch_id INTEGER PRIMARY KEY AUTOINCREMENT,
          repo_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          head_commit TEXT NOT NULL,
          FOREIGN KEY (repo_id) REFERENCES repositories (repo_id),
          FOREIGN KEY (head_commit) REFERENCES commits (commit_hash)
        );

        CREATE INDEX IF NOT EXISTS idx_branches_repo_id ON branches (repo_id);
        CREATE INDEX IF NOT EXISTS idx_branches_head_commit ON branches (head_commit);

        CREATE TABLE IF NOT EXISTS files (
          file_id INTEGER PRIMARY KEY AUTOINCREMENT,
          repo_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          latest_commit TEXT NOT NULL,
          FOREIGN KEY (repo_id) REFERENCES repositories (repo_id),
          FOREIGN KEY (latest_commit) REFERENCES commits (commit_hash)
        );

        CREATE INDEX IF NOT EXISTS idx_files_repo_id ON files (repo_id);
        CREATE INDEX IF NOT EXISTS idx_files_file_path ON files (file_path);

        CREATE TABLE IF NOT EXISTS commit_files (
          commit_hash TEXT NOT NULL,
          file_id INTEGER NOT NULL,
          changes TEXT NOT NULL,
          PRIMARY KEY (commit_hash, file_id),
          FOREIGN KEY (commit_hash) REFERENCES commits (commit_hash),
          FOREIGN KEY (file_id) REFERENCES files (file_id)
        );

        CREATE TABLE IF NOT EXISTS commit_parents (
          commit_hash TEXT NOT NULL,
          parent_hash TEXT NOT NULL,
          PRIMARY KEY (commit_hash, parent_hash),
          FOREIGN KEY (commit_hash) REFERENCES commits (commit_hash),
          FOREIGN KEY (parent_hash) REFERENCES commits (commit_hash)
        );

        CREATE INDEX IF NOT EXISTS idx_commit_parents_commit_hash ON commit_parents (commit_hash);
        CREATE INDEX IF NOT EXISTS idx_commit_parents_parent_hash ON commit_parents (parent_hash);
      SQL
    end
  end
end
