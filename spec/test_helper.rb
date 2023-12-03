# frozen_string_literal: true

require "git"
require "fileutils"

class TestHelper
  def self.setup_mock_git_repo(path = "./mock_git_repo")
    FileUtils.mkdir_p(path)
    Git.init(path)

    g = Git.open(path)
    File.write(File.join(path, "README.md"), "Initial Commit\n")
    g.add(all: true)
    g.commit("Initial commit")

    File.write(File.join(path, "CONTRIBUTING.md"), "Contributing Guidelines\n")
    g.add(all: true)
    g.commit("Add contributing guidelines")

    g.branch("new_branch").checkout
    File.write(File.join(path, "new_file.md"), "New branch content\n")
    g.add(all: true)
    g.commit("New branch commit")

    g.checkout("main")
  end

  def self.delete_mock_git_repo(path = "./mock_git_repo")
    FileUtils.rm_rf(path)
  end
end
