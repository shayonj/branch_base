# frozen_string_literal: true

require "rugged"

module BranchBase
  class Repository
    attr_reader :repo

    def initialize(repo_path)
      @repo = Rugged::Repository.new(repo_path)
    end

    def walk(branch_name = nil, &block)
      # Use the provided branch's head commit OID if a branch name is given,
      # otherwise, use the repository's HEAD commit OID.
      oid =
        if branch_name
          branch = @repo.branches[branch_name]
          raise ArgumentError, "Branch not found: #{branch_name}" unless branch
          branch.target.oid
        else
          @repo.head.target.oid
        end

      @repo.walk(oid, Rugged::SORT_TOPO, &block)
    end

    def default_branch_name
      head_ref = @repo.head.name
      head_ref.sub(%r{^refs/heads/}, "")
    rescue Rugged::ReferenceError
      nil
    end

    def path
      @repo.path
    end

    def branches
      @repo.branches
    end
  end
end
