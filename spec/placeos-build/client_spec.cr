require "../helper"

module PlaceOS::Build
  describe Client do
    before_each do
      WebMock.allow_net_connect = false
    end

    after_each do
      WebMock.reset
    end

    after_all do
      WebMock.allow_net_connect = true
    end

    pending "#branches" do
    end

    describe "#compile" do
      it "compiles and downloads a driver" do
        path = "drivers/test.cr"
        url = "https://github.com/placeos/drivers"
        commit = "abcdef"
        executable = Model::Executable.new(path, commit, "d1g3s7", "1.1.1")
        expected = Compilation::Success.new(executable.filename, 0)

        WebMock
          .stub(:post, "http://localhost:3000/api/build/v1/driver/drivers%2Ftest.cr?url=https%3A%2F%2Fgithub.com%2Fplaceos%2Fdrivers&commit=abcdef&force_recompile=false")
          .to_return(status: 200, body_io: IO::Memory.new("binary"), headers: expected.to_http_headers)

        response = Client.client do |client|
          client.compile(path, url, commit) do |key, io|
            # This block should be called
            key.should eq executable.filename
            io.to_s.should eq "binary"
          end
        end

        response.should be_a(Compilation::Success)
        response.success?.should be_true
      end

      it "handles compilation failure" do
        path = "drivers/test.cr"
        url = "https://github.com/placeos/drivers"
        commit = "abcdef"

        WebMock
          .stub(:post, "http://localhost:3000/api/build/v1/driver/drivers%2Ftest.cr?url=https%3A%2F%2Fgithub.com%2Fplaceos%2Fdrivers&commit=abcdef&force_recompile=false")
          .to_return(status: 422, body: Compilation::Failure.new("failed to compile").to_json)

        response = Client.client do |client|
          client.compile(path, url, commit) do
            # This block should not be called
            true.should be_false
          end
        end

        response.should be_a(Compilation::Failure)
        response.success?.should be_false
      end

      pending "handles missing driver" do
      end
    end

    describe "#compiled" do
      it "returns the driver name for a compiled driver" do
        path = "drivers/test.cr"
        url = "https://github.com/placeos/drivers"
        commit = "abcdef"
        expected_driver_name = "compiled_driver_name"

        WebMock
          .stub(:get, "http://localhost:3000/api/build/v1/driver/drivers%2Ftest.cr/compiled?url=https%3A%2F%2Fgithub.com%2Fplaceos%2Fdrivers&commit=abcdef")
          .to_return(status: 200, body: {filename: expected_driver_name}.to_json)

        response = Client.client do |client|
          client.compiled(path, url, commit)
        end

        response.should be_a String
        response.should eq expected_driver_name
      end

      it "returns nil if the driver doesn't exist" do
        path = "drivers/test.cr"
        url = "https://github.com/placeos/drivers"
        commit = "abcdef"

        WebMock
          .stub(:get, "http://localhost:3000/api/build/v1/driver/drivers%2Ftest.cr/compiled?url=https%3A%2F%2Fgithub.com%2Fplaceos%2Fdrivers&commit=abcdef")
          .to_return(status: 404)

        response = Client.client do |client|
          client.compiled(path, url, commit)
        end

        response.should be_nil
      end
    end

    pending "#discover_drivers" do
    end

    pending "#documentation" do
    end

    pending "#file_commits" do
    end

    describe "#healthcheck" do
      it "checks if service is reachable" do
        WebMock
          .stub(:get, "http://localhost:3000/api/build/v1/")
          .to_return(status: 200)
        Client.client(&.healthcheck).should be_true
      end

      it "checks if service is not reachable" do
        WebMock
          .stub(:get, "http://localhost:3000/api/build/v1/")
          .to_return(status: 500)
        Client.client(&.healthcheck).should be_false
      end
    end

    pending "#metadata" do
    end

    pending "#query" do
    end

    pending "#repository_commits" do
    end

    pending "#version" do
    end
  end
end
