require "uuid"

module PlaceOS::Build::Digest
  FIXTURE_DIR = "./spec/digest_fixtures"

  describe ".digest" do
    it "produces a hex digest of an entrypoint and its requires" do
      path = File.join(FIXTURE_DIR, "no_requires_0.cr")
      digests = Digest.digest([path])

      digests.should_not be_empty

      digest = digests.first
      digest.path.should eq Path[path]
      digest.hash.should eq "f5e9d0"
    end

    it "produces a different hex digest of an entrypoint if changed" do
      first_digest = Digest.digest([File.join(FIXTURE_DIR, "no_requires_0.cr")]).first
      second_digest = Digest.digest([File.join(FIXTURE_DIR, "no_requires_1.cr")]).first

      second_digest.hash.should eq "d9fd98"
      first_digest.hash.should_not eq second_digest.hash
    end

    it "allows specification of a shard.lock" do
      entrypoint = File.join(FIXTURE_DIR, "shard_require.cr")
      shard_lock = File.join(FIXTURE_DIR, "shard.lock")
      digest_with_lock = Digest.digest([entrypoint], lock_file: shard_lock).first
      digest_without_lock = Digest.digest([entrypoint]).first
      digest_with_lock.hash.should eq "ebfb62"
      digest_with_lock.hash.should_not eq digest_without_lock.hash
    end

    it "digests files with local requires" do
      digest = Digest.digest([File.join(FIXTURE_DIR, "local_require.cr")]).first
      digest.hash.should eq "e210ff"
    end

    it "digests files with local requires and missing shards" do
      digest = Digest.digest([File.join(FIXTURE_DIR, "local_require_fake_shard.cr")]).first
      digest.hash.should eq "0fe9a0"
    end

    it "digests files with missing shards" do
      digest = Digest.digest([File.join(FIXTURE_DIR, "shard_require.cr")]).first
      digest.hash.should eq "25d1bb"
    end
  end
end
