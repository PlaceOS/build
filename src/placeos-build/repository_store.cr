require "placeos-compiler/git"
require "file_utils"

module PlaceOS::Build
  class RepositoryStore
    alias Git = ::PlaceOS::Compiler::Git

    getter store_path : String

    def self.uri_to_directory(uri)
      Base64.urlsafe_encode(uri)
    end

    def self.directory_to_uri(key)
      Base64.decode_string(key)
    end

    def initialize(store_path : String = "./repositories")
      @store_path = Path[store_path].expand.to_s
      Dir.mkdir_p @store_path
    end

    def repository_commits?(
      uri : String,
      limit : Int32,
      branch : String? = nil,
      username : String? = nil,
      password : String? = nil
    )
      with_repository(uri, "shard.yml", "HEAD", branch, username, password) do |repository_path|
        Git.repository_commits(repository_path.basename, repository_path.parent.to_s, limit)
      end
    rescue e
      Log.error(exception: e) { "failed to fetch commits for #{uri}" }
      nil
    end

    def file_commits?(
      file : String,
      uri : String,
      limit : Int32,
      branch : String? = nil,
      username : String? = nil,
      password : String? = nil
    )
      with_repository(uri, file, "HEAD", branch, username, password) do |repository_path|
        entrypoint = repository_path / file
        shard_lock = repository_path / "shard.lock"
        requires = Digest
          .requires([entrypoint.to_s])
          .unshift(shard_lock.to_s)
          .select(&.starts_with?(repository_path.to_s))
        Git.commits(requires, repository_path.basename, repository_path.parent.to_s, limit)
      end
    rescue e
      Log.error(exception: e) { "failed to fetch commits for #{file} in #{uri}" }
      nil
    end

    def branches?(uri : String, username : String? = nil, password : String? = nil) : Array(String)?
      with_repository(uri, "shard.yml", "HEAD", branch: nil, username: username, password: password) do |repository_path|
        Git.branches(repository_path.basename, repository_path.parent.to_s)
      end
    rescue e
      Log.error(exception: e) { "failed to fetch branches for #{uri}" }
      nil
    end

    def link_existing(uri, path)
      key = self.class.uri_to_directory(uri)
      link_path = File.join(store_path, key)
      FileUtils.cp_r(path, link_path)
    end

    def with_repository(
      uri : String,
      file : String,
      commit : String,
      branch : String?,
      username : String?,
      password : String?,
      & : Path ->
    )
      key = clone(uri, branch, username, password)

      # Copy repository to a temporary directory
      repository_path = File.join(store_path, key)
      key = UUID.random.to_s
      temporary_path = File.join(Dir.tempdir, key)
      FileUtils.cp_r(repository_path, temporary_path)
      repository_path = temporary_path

      # Checkout temporary copy to desired commit.
      Git.checkout_file(file, key, Dir.tempdir, commit) do
        yield Path[repository_path]
      end
    ensure
      temporary_path.try { |dir| FileUtils.rm_r(dir) } rescue nil
    end

    protected def clone(
      uri : String,
      branch : String?,
      username : String?,
      password : String?
    ) : String
      key = self.class.uri_to_directory(uri)
      path = File.join(store_path, key)

      args = {
        repository:        key,
        working_directory: store_path,
        branch:            branch.presence || "master",
        raises:            true,
      }

      if Dir.exists?(path)
        # Pull if repository already exists
        Git.pull(**args)
      else
        Git.clone(**args.merge(
          username: username,
          password: password,
          repository_uri: uri,
        ))
      end

      key
    end
  end
end
