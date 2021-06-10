require "./api/*"
require "./drivers"

module PlaceOS::Build::Api
  class_getter builder : Build::Drivers do
    Build::Drivers.new
  end
end
