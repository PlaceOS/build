require "uuid"
require "../../helper"

module PlaceOS::Build
  describe Api::Driver do
    broken_repository_path = "spec/repository_fixtures/broken"
    broken_entrypoint = "drivers/place/broken.cr"
    with_server do
      describe "POST ../:file" do
        it "gracefully handles malformed driver" do
          tempdir = Dir.tempdir
          temporary_repository = File.join(tempdir, Path[broken_repository_path].basename)
          FileUtils.cp_r(broken_repository_path, tempdir)
          Build.support_local_builds = true
          Client.client(URI.parse("http://localhost:6000")) do |client|
            client.repository_path = temporary_repository
            client.compile(
              file: broken_entrypoint,
              url: "local",
              commit: "abcde",
            ) do
              # This should not be called
              true.should be_false
            end
          end
        end
      end
    end
  end
end
