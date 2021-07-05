require "../../../helper.cr"

require "./responses"

module PlaceOS::Build
  describe S3::Unsigned do
    client = S3::Unsigned.new("placeos-drivers", "ap-southeast-2")

    describe "#read" do
      it "returns an object" do
        WebMock.allow_net_connect = false
        WebMock.stub(:get, "https://placeos-drivers.s3.ap-southeast-2.amazonaws.com/test.html")
               .to_return(body_io: IO::Memory.new)

        client.read("test.html") do |io|
          io.gets_to_end.should be_empty
        end
      end
    end

    describe "#list" do
      it "lists objects in the bucket" do
        WebMock.allow_net_connect = false
        WebMock.reset
        WebMock
          .stub(:get, "https://placeos-drivers.s3.ap-southeast-2.amazonaws.com")
          .to_return(body: LIST_XML)

        client.list.should_not be_empty
      end
    end

    describe "#write" do
      it "is not supported" do
        expect_raises Error::UnsignedWrite do
          client.write("key", IO::Memory.new)
        end
      end
    end

    describe "#copy" do
      it "is not supported" do
        expect_raises Error::UnsignedWrite do
          client.copy("src", "destination")
        end
      end
    end
  end
end
