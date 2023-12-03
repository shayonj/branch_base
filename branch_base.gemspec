# frozen_string_literal: true
require_relative "lib/branch_base/version"

Gem::Specification.new do |spec|
  spec.name = "branch_base"
  spec.version = BranchBase::VERSION
  spec.authors = ["Shayon Mukherjee"]
  spec.email = ["shayonj@gmail.com"]

  spec.summary = "Sync Git Repository into a SQLite Database"
  spec.description =
    "BranchBase provides a CLI to synchronize a Git repository into a SQLite database."
  spec.homepage = "https://github.com/shayonj/branch_base"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.files =
    `git ls-files -z`.split("\x0")
      .reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = "scripts"
  spec.executables = ["branch_base"]
  spec.require_paths = ["lib"]

  spec.add_dependency("rugged")
  spec.add_dependency("sqlite3")
  spec.add_dependency("thor", "~> 1.0")

  spec.metadata = { "rubygems_mfa_required" => "true" }

  spec.add_development_dependency("git")
  spec.add_development_dependency("prettier_print")
  spec.add_development_dependency("pry")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("rspec")
  spec.add_development_dependency("rubocop")
  spec.add_development_dependency("rubocop-packaging")
  spec.add_development_dependency("rubocop-performance")
  spec.add_development_dependency("rubocop-rake")
  spec.add_development_dependency("rubocop-rspec")
  spec.add_development_dependency("syntax_tree")
  spec.add_development_dependency("syntax_tree-haml")
  spec.add_development_dependency("syntax_tree-rbs")
end
