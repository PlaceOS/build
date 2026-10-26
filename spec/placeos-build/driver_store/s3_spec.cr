require "../../helper.cr"

require "./s3/responses"

module PlaceOS::Build
  describe S3 do
    before_all do
      WebMock.allow_net_connect = false
      WebMock.reset
    end

    after_all do
      WebMock.allow_net_connect = true
    end

    describe "when the bucket denies access" do
      store = S3.new(
        Filesystem.new(File.tempname("s3-spec")),
        S3::Unsigned.new("placeos-drivers", "ap-southeast-2"),
      )
      executable = Model::Executable.new("drivers/place/private_helper.cr", "commit", "digest", "1.0.0")

      before_each do
        WebMock
          .stub(:get, "https://placeos-drivers.s3.ap-southeast-2.amazonaws.com")
          .to_return(status: 403, body: ACCESS_DENIED_XML)
      end

      it "#exists? is a cache miss" do
        store.exists?(executable).should be_false
      end

      it "#query is a cache miss" do
        store.query(executable.entrypoint, executable.commit, executable.digest, executable.crystal_version.to_s).should be_empty
      end
    end
  end
end
