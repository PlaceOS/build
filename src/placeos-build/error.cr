class PlaceOS::Build::Error < Exception
  def initialize(io : IO, **args)
    super(io.to_s, **args)
  end

  def initialize(message : String?, **args)
    super
  end
end
