require "./constants"
require "./placeos-build/api/*"

require "openapi-generator"
require "openapi-generator/serializable"
require "openapi-generator/providers/action-controller"
require "openapi-generator/helpers/action-controller"

OpenAPI::Generator::Helpers::ActionController.bootstrap

OpenAPI::Generator.generate(
  OpenAPI::Generator::RoutesProvider::ActionController.new,
  options: {
    output: Path[Dir.current] / "openapi.yml",
  },
  base_document: {
    info:       {title: "PlaceOS Build", version: PlaceOS::Build::VERSION},
    components: NamedTuple.new,
  }
)
