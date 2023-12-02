# frozen_string_literal: true

require "rugged"

module BranchBase
  class Repository
    def initialize(repo_path)
      @repo = Rugged::Repository.new(repo_path)
    end

    def walk(&block)
      @repo.walk(@repo.head.target.oid, Rugged::SORT_TOPO, &block)
    end

    def path
      @repo.path
    end

    def branches
      @repo.branches
    end
  end
end
