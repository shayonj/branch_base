# frozen_string_literal: true

require "thor"
require "fileutils"

module BranchBase
  class CLI < Thor
    desc "sync REPO_PATH [BRANCH_OR_TAG]",
         "Synchronize a specific branch or tag of the Git repository with the SQLite database"
    def sync(repo_path)
      full_repo_path = File.expand_path(repo_path)

      unless File.directory?(File.join(full_repo_path, ".git"))
        puts "The specified path is not a valid Git repository: #{full_repo_path}"
        exit(1)
      end

      repo_name = File.basename(full_repo_path)
      db_filename = "#{repo_name}_git_data.db"

      database = Database.new(db_filename)
      repository = Repository.new(full_repo_path)
      sync = Sync.new(database, repository)

      sync.run
      puts "Repository data synced successfully for"
    end
  end
end
