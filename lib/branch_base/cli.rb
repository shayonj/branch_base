# frozen_string_literal: true

require "thor"
require "fileutils"

module BranchBase
  class CLI < Thor
    desc "sync REPO_PATH", "Synchronize a Git directory to a SQLite database"
    def sync(repo_path)
      BranchBase.logger.info("Starting sync process for #{repo_path}...")

      full_repo_path = File.expand_path(repo_path)

      unless File.directory?(File.join(full_repo_path, ".git"))
        BranchBase.logger.error(
          "The specified path is not a valid Git repository: #{full_repo_path}",
        )
        exit(1)
      end

      repo_name = File.basename(full_repo_path)
      db_directory = full_repo_path
      db_filename = File.join(db_directory, "#{repo_name}_git_data.db")

      database = Database.new(db_filename)
      repository = Repository.new(full_repo_path)
      start_time = Time.now
      sync = Sync.new(database, repository)

      sync.run
      elapsed_time = Time.now - start_time
      BranchBase.logger.info(
        "Repository data synced successfully in #{db_filename} in #{elapsed_time.round(2)} seconds",
      )
    end
  end
end
