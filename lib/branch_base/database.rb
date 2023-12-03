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

        CREATE TABLE IF NOT EXISTS branches (
          branch_id INTEGER PRIMARY KEY AUTOINCREMENT,
          repo_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          FOREIGN KEY (repo_id) REFERENCES repositories (repo_id)
        );

        CREATE TABLE IF NOT EXISTS branch_commits (
          branch_id INTEGER NOT NULL,
          commit_hash TEXT NOT NULL,
          PRIMARY KEY (branch_id, commit_hash),
          FOREIGN KEY (branch_id) REFERENCES branches (branch_id),
          FOREIGN KEY (commit_hash) REFERENCES commits (commit_hash)
        );

        CREATE TABLE IF NOT EXISTS files (
          file_id INTEGER PRIMARY KEY AUTOINCREMENT,
          repo_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          latest_commit TEXT NOT NULL,
          FOREIGN KEY (repo_id) REFERENCES repositories (repo_id),
          FOREIGN KEY (latest_commit) REFERENCES commits (commit_hash)
        );

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

        CREATE INDEX IF NOT EXISTS idx_commits_repo_id ON commits (repo_id);
        CREATE INDEX IF NOT EXISTS idx_commits_author ON commits (author);
        CREATE INDEX IF NOT EXISTS idx_commits_committer ON commits (committer);
        CREATE INDEX IF NOT EXISTS idx_branches_repo_id ON branches (repo_id);
        CREATE INDEX IF NOT EXISTS idx_files_repo_id ON files (repo_id);
        CREATE INDEX IF NOT EXISTS idx_files_file_path ON files (file_path);
        CREATE INDEX IF NOT EXISTS idx_commit_parents_commit_hash ON commit_parents (commit_hash);
        CREATE INDEX IF NOT EXISTS idx_commit_parents_parent_hash ON commit_parents (parent_hash);
      SQL
    end
  end
end
