require "clip"
require "log"

require "../constants"
require "./cli/*"
require "./driver_store/s3"

module PlaceOS::Build
  def self.run
    if (command = Cli.parse).is_a? Clip::Mapper::Help
      puts command.help
      exit 1
    end

    command.run
  rescue e : Clip::Error
    puts e
    exit 1
  end

  @[Clip::Doc("A program to build PlaceOS Drivers")]
  abstract struct Cli
    include Clip::Mapper

    macro inherited
      include Clip::Mapper
      Log = ::Log.for({{ @type }})
    end

    @[Clip::Doc("Display the application version")]
    @[Clip::Option("-v", "--version")]
    getter version : Bool = false

    @[Clip::Doc("List the application environment")]
    @[Clip::Option("-e", "--env")]
    getter environment : Bool = false

    # AWS configuration
    getter aws_region : String? = AWS_REGION
    getter aws_key : String? = AWS_KEY
    getter aws_secret : String? = AWS_SECRET
    getter aws_s3_bucket : String? = AWS_S3_BUCKET

    def aws_credentials : S3::Credentials?
      S3.credentials(
        aws_region: aws_region,
        aws_key: aws_key,
        aws_secret: aws_secret,
        aws_s3_bucket: aws_s3_bucket
      )
    end

    Clip.add_commands({
      "build"  => Build,
      "server" => Server,
    })

    def run
      run_version
      run_environment
    end

    protected def run_version
      return unless version
      puts "#{APP_NAME} v#{VERSION}"
      exit 0
    end

    protected def run_environment
      return unless environment
      ENV.accessed.sort.each &->puts(String)
      exit 0
    end
  end
end
