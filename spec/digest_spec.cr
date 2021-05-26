require "uuid"

module PlaceOS::Build::Digest
  FIXTURE = "./spec/digest_fixture.cr"

  class_getter! temp_path : String

  Spec.before_each do
    @@temp_path = (Path[Dir.tempdir] / UUID.random.to_s).to_s
    File.copy(FIXTURE, temp_path)
  end

  Spec.after_each do
    @@temp_path.try(&->File.delete(String)) rescue nil
  end

  describe ".digest" do
    it "produces a hex digest of an entrypoint and its requires" do
      digests = Digest.digest([temp_path])

      digests.should_not be_empty

      digest = digests.first
      digest.path.should eq temp_path
      digest.hash.should eq "e799f9a88998e804656b3c1fd74d59326d268e88"
    end

    it "produces a different hex digest of an entrypoint if changed" do
      first_digest = Digest.digest([temp_path]).first
      File.open(temp_path, mode: "a+") { |f| f << %(\nputs "hello again") }
      second_digest = Digest.digest([temp_path]).first

      second_digest.hash.should eq "e12245c8a7c56cb3d34aa4ed0d70d50f29d59d16"
      first_digest.path.should eq second_digest.path
      first_digest.hash.should_not eq second_digest.hash
    end
  end
end
