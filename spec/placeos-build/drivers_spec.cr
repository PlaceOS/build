module PlaceOS::Build
  describe Drivers do
    it "compiles a crystal binary specified by an entrypoint" do
      Drivers.new.compile(
        repository_uri: "https://github.com/place-labs/exec_from",
        entrypoint: "src/app.cr",
        commit: "da824d2a59f7e29eea6525f472ffc67c294a48cf",
        crystal_version: "1.4.1",
      )
    end
  end
end
