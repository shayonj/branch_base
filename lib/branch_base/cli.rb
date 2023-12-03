# frozen_string_literal: true

require "thor"
require "erb"
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

    desc "git-wrapped REPO_PATH",
         "Generate Git wrapped statistics for the given repository"
    def git_wrapped(repo_path)
      BranchBase.logger.info("Generating Git wrapped for #{repo_path}...")

      full_repo_path = File.expand_path(repo_path)
      @repo_name = File.basename(full_repo_path)
      db_filename = File.join(full_repo_path, "#{@repo_name}_git_data.db")

      unless File.exist?(db_filename)
        BranchBase.logger.error("Database file not found: #{db_filename}")
        exit(1)
      end

      database = Database.new(db_filename)
      @results = BranchBase.execute_git_wrapped_queries(database)
      @emojis = BranchBase.emojis_for_titles

      json_full_path = "#{full_repo_path}/git-wrapped.json"
      File.write(json_full_path, JSON.pretty_generate(@results))
      BranchBase.logger.info("Git wrapped JSON stored in #{json_full_path}")

      gem_root = Gem::Specification.find_by_name("branch_base").gem_dir
      template_file_path =
        File.join(gem_root, "lib", "internal", "template.html.erb")
      erb = ERB.new(File.read(template_file_path))
      generated_html = erb.result(binding)

      html_full_path = "#{full_repo_path}/git-wrapped.html"
      File.write(html_full_path, generated_html)

      BranchBase.logger.info("Git wrapped HTML stored in #{html_full_path}")
    end

    desc "version", "Prints the version"
    def version
      puts BranchBase::VERSION
    end

    def self.exit_on_failure?
      true
    end
  end
end
