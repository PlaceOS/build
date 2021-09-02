require "../../helper"

module PlaceOS::Build
  describe Api::Driver do
    broken_repository_path = "spec/repository_fixtures/broken"
    broken_entrypoint = "drivers/place/broken.cr"
    with_server do
      describe "POST ../:file", focus: true do
        it "gracefully handles malformed driver" do
          Build.support_local_builds = true
          Client.client(URI.parse("http://localhost:6000")) do |client|
            client.repository_path = broken_repository_path
            client.compile(
              file: broken_entrypoint,
              url: "local",
              commit: "abcde",
            ) do |key, io|
              true.should be_false
            end
          end
        end
      end
    end
  end
end
