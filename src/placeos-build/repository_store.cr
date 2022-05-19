require "git-repository"
require "file_utils"

module PlaceOS::Build
  class RepositoryStore
    def initialize
    end

    def repository_commits?(
      uri : String,
      limit : Int32,
      branch : String? = nil,
      username : String? = nil,
      password : String? = nil
    )
      repository = repository(uri, username, password)

      branch = repository.default_branch if branch.nil?

      repository.commits(branch, depth: limit)
    rescue e
      Log.error(exception: e) { "failed to fetch commits for #{uri}" }
      nil
    end

    private def repository(
      uri : String,
      username : String? = nil,
      password : String? = nil,
      branch : String? = nil
    )
      GitRepository.new(uri, branch: branch, username: username, password: password)
    end

    def file_commits?(
      file : String,
      uri : String,
      limit : Int32,
      branch : String? = nil,
      username : String? = nil,
      password : String? = nil
    )
      repository = repository(uri, username, password, branch)

      branch = repository.default_branch if branch.nil?

      requires = with_repository(uri, branch, username, password) do |downloaded_repository|
        entrypoint = downloaded_repository.path / file
        shard_lock = downloaded_repository.path / "shard.lock"
        Digest
          .requires([entrypoint.to_s])
          .unshift(shard_lock.to_s)
          .select(&.starts_with?(downloaded_repository.path.to_s))
      end

      repository.commits(branch, requires, depth: limit)
    rescue e
      Log.error(exception: e) { "failed to fetch commits for #{file} in #{uri}" }
      nil
    end

    def branches?(uri : String, username : String? = nil, password : String? = nil) : Array(String)?
      repository(uri, username, password).branches.keys
    rescue e
      Log.error(exception: e) { "failed to fetch branches for #{uri}" }
      nil
    end

    record Repository,
      path : Path,
      commit : GitRepository::Commit

    def with_repository(
      uri : String,
      ref : String,
      username : String?,
      password : String?,
      & : Repository ->
    )
      Log.trace { {
        message: "checking out repository",
        ref:     ref,
      } }

      key = UUID.random.to_s
      temporary_path = File.join(Dir.tempdir, key)

      commit = repository(uri, username, password).fetch_commit(ref, download_to_path: temporary_path)

      Log.trace { {
        message: "checked out repository",
        ref:     ref,
        hash:    commit.hash,
      } }

      # Yield temporary copy to desired commit.
      yield Repository.new(Path[temporary_path], commit)
    ensure
      temporary_path.try { |dir| FileUtils.rm_r(dir) } rescue nil
    end
  end
end
