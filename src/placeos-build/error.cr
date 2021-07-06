require "exec_from"

class PlaceOS::Build::Error < Exception
  def initialize(io : IO, **args)
    super(io.to_s, **args)
  end

  def initialize(message : String?, **args)
    super
  end

  class AlreadyCompiling < Error
  end

  class UnsignedWrite < Error
    def initialize(**args)
      @message = "Attempting to write a file to s3 via an unsigned client.\nEnsure the following environment variables are set... AWS_REGION, AWS_KEY, AWS_SECRET, AWS_BUCKET"
    end
  end
end
