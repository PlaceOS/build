require "placeos-compiler/git"

module PlaceOS::Build
  class RepositoryStore
    getter store_path : String

    alias Git = PlaceOS::Compiler::Git

    def self.uri_to_directory(uri)
      Base64.urlsafe_encode(uri)
    end

    def self.directory_to_uri(key)
      Base64.decode_string(key)
    end

    def initialize(@store_path : String = Path["./repositories"].expand.to_s)
      Dir.mkdir_p @store_path
    end

    def branches?(uri : String) : Array(String)
      with_repository(uri, "shard.yml", "HEAD") do |repository_path|
        run_git(repository_path, {"branch", "-r"})
          .output
          .to_s
          .lines
          .compact_map { |l| l.strip.lchop("origin/") unless l =~ /HEAD/ }
          .sort!
          .uniq!
      end
    rescue e
      Log.error(exception: e) { "failed to fetch branches for #{uri}" }
      nil
    end

    def with_repository(uri : String, file : String, commit : String, & : String ->)
      key = clone(uri)

      # Copy repository to a temporary directory
      repository_path = File.join(store_path, key)
      key = UUID.random.to_s
      temporary_path = File.join(Dir.tempdir, key)
      FileUtils.cp_r(repository_path, temporary_path)
      repository_path = temporary_path

      # Checkout temporary copy to desired commit.
      Git.checkout_file(file, key, Dir.tempdir, commit) do
        yield repository_path
      end
    ensure
      temporary_path.try { |dir| FileUtils.rm_r(dir) } rescue nil
    end

    protected def clone(uri : String) : String
      key = self.class.uri_to_directory(uri)

      # Ensure repository exists
      if Dir.exists?(File.join(store_path, key))
        Git.fetch(
          repository: key,
          working_directory: store_path,
        )
      else
        Git.clone(
          repository: key,
          repository_uri: uri,
          working_directory: store_path,
          raises: true,
        )
      end

      key
    end
  end
end
