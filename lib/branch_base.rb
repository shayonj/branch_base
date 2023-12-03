# frozen_string_literal: true

require "logger"
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
end
