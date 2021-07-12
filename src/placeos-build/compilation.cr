module PlaceOS::Build
  module Compilation
    alias Result = Success | Failure | NotFound

    record NotFound
    record Success, path : String
    record Failure, error : String do
      include JSON::Serializable
    end
  end
end
