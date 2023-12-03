# frozen_string_literal: true
require "spec_helper"

RSpec.describe(BranchBase::Database) do
  let(:database) { BranchBase::Database.new(":memory:") }

  describe "#initialize" do
    it "initializes with the correct schema" do
      tables =
        database.execute("SELECT name FROM sqlite_master WHERE type='table'")
      expected_tables = %w[
        repositories
        commits
        branches
        files
        commit_files
        commit_parents
        sqlite_sequence
        branch_commits
      ]
      expect(tables.flatten).to match_array(expected_tables)
    end
  end

  describe "#execute" do
    it "executes a given SQL statement" do
      result =
        database.execute(
          "INSERT INTO repositories (name, url) VALUES (?, ?)",
          %w[mock_repo mock_repo/],
        )
      expect(result).to be_empty
    end
  end

  describe "#prepare" do
    it "prepares a SQL statement" do
      statement =
        database.prepare("INSERT INTO repositories (name, url) VALUES (?, ?)")
      expect(statement).to be_a(SQLite3::Statement)
    end
  end

  describe "#transaction" do
    it "executes a block within a transaction" do
      expect {
        database.transaction do
          database.execute(
            "INSERT INTO repositories (name, url) VALUES (?, ?)",
            %w[mock_repo mock_repo/],
          )
          raise "Rollback transaction"
        end
      }.to raise_error(RuntimeError, "Rollback transaction")

      count = database.execute("SELECT COUNT(*) FROM repositories").first.first
      expect(count).to eq(0)
    end
  end

  describe "#last_insert_row_id" do
    it "returns the last insert row ID" do
      database.execute(
        "INSERT INTO repositories (name, url) VALUES (?, ?)",
        %w[mock_repo mock_repo/],
      )
      expect(database.last_insert_row_id).to be > 0
    end
  end
end
