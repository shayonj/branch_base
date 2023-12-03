# frozen_string_literal: true

require "logger"
require "json"
require "branch_base/version"
require "branch_base/database"
require "branch_base/repository"
require "branch_base/sync"
require "branch_base/cli"

module BranchBase
  def self.logger
    @logger ||=
      Logger
        .new($stdout)
        .tap do |log|
          log.progname = "BranchBase"

          log.level = ENV["DEBUG"] ? Logger::DEBUG : Logger::INFO

          log.formatter =
            proc do |severity, datetime, progname, msg|
              "#{datetime}: #{severity} - #{progname}: #{msg}\n"
            end
        end
  end

  def self.execute_git_wrapped_queries(database)
    queries = {
      "top_contributors_of_the_year" =>
        "SELECT author, COUNT(*) AS commit_count
         FROM commits
         WHERE substr(commits.timestamp, 1, 4) = '2023'
         GROUP BY author
         ORDER BY commit_count DESC
         LIMIT 10;",
      "commits_per_day_of_the_week" =>
        "SELECT
           CASE strftime('%w', substr(timestamp, 1, 10))
             WHEN '0' THEN 'Sunday'
             WHEN '1' THEN 'Monday'
             WHEN '2' THEN 'Tuesday'
             WHEN '3' THEN 'Wednesday'
             WHEN '4' THEN 'Thursday'
             WHEN '5' THEN 'Friday'
             WHEN '6' THEN 'Saturday'
           END as day_of_week,
           COUNT(*) as commit_count
         FROM commits
         WHERE substr(timestamp, 1, 4) = '2023'
         GROUP BY day_of_week
         ORDER BY commit_count DESC;",
      "most_active_months" =>
        "SELECT substr(commits.timestamp, 1, 7) AS month, COUNT(*) AS commit_count
         FROM commits
         WHERE substr(commits.timestamp, 1, 4) = '2023'
         GROUP BY month
         ORDER BY commit_count DESC
         LIMIT 12;",
      "commits_with_most_significant_number_of_changes" =>
        "SELECT commits.commit_hash, COUNT(commit_files.file_id) AS files_changed
         FROM commits
         JOIN commit_files ON commits.commit_hash = commit_files.commit_hash
         WHERE substr(commits.timestamp, 1, 4) = '2023'
         GROUP BY commits.commit_hash
         ORDER BY files_changed DESC
         LIMIT 10;",
      "most_edited_files" =>
        "SELECT files.file_path, COUNT(*) AS edit_count
         FROM commit_files
         JOIN files ON commit_files.file_id = files.file_id
         JOIN commits ON commit_files.commit_hash = commits.commit_hash
         WHERE substr(commits.timestamp, 1, 4) = '2023'
         GROUP BY files.file_path
         ORDER BY edit_count DESC
         LIMIT 10;",
    }

    queries.transform_values { |query| database.execute(query) }
  end

  def self.emojis_for_titles
    {
      "top_contributors_of_the_year" => "🏆",
      "commits_per_day_of_the_week" => "📅",
      "most_active_months" => "📆",
      "commits_with_most_significant_number_of_changes" => "📈",
      "most_edited_files" => "📝",
    }
  end
end
