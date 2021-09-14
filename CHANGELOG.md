# Changelog

All changes are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

## [0.8.2](https://github.com/PlaceOS/build/compare/v0.8.0...v0.8.2)

### Changed

* **dependencies**: point to steve's s3 fork ([6709c7f](https://github.com/PlaceOS/build/commit/6709c7f))
* **ci**:
  - use 1.1.1 for tests ([6ff6256](https://github.com/PlaceOS/build/commit/6ff6256))
  - remove driver spec fixture ([2e58060](https://github.com/PlaceOS/build/commit/2e58060))
  - remove commented matrix ([0c18e59](https://github.com/PlaceOS/build/commit/0c18e59))
* **test**:
  - reduce logging from raven shard ([ace08ab](https://github.com/PlaceOS/build/commit/ace08ab))
  - **(api:driver)**: client handle compile errors ([b9bea2d](https://github.com/PlaceOS/build/commit/b9bea2d))
  - **(client_spec)**: fix mocking ([50e829a](https://github.com/PlaceOS/build/commit/50e829a))

### Fixed

* **client**:
  - extract `body_io` and fallback to `body` ([e24498b](https://github.com/PlaceOS/build/commit/e24498b))
  - graceful handling of build failures ([375d96d](https://github.com/PlaceOS/build/commit/375d96d))
* **s3**: url form encode before writes ([2eaabb0](https://github.com/PlaceOS/build/commit/2eaabb0))

## [0.8.0](https://github.com/PlaceOS/build/compare/v0.7.0...v0.8.0)

* **executable**: Digest before commit in filename, provides easier S3 queries ([f7316ea](https://github.com/PlaceOS/build/commit/f7316ea)) 
* **s3**: Encode key before write ([b1d86a7](https://github.com/PlaceOS/build/commit/b1d86a7)) 
* **cli:build**: Abort if no entrypoints supplied to build ([a02542e](https://github.com/PlaceOS/build/commit/a02542e))
* **logging**: add sentry ([383829f](https://github.com/PlaceOS/build/commit/383829f))

## [0.7.0](https://github.com/PlaceOS/build/compare/v0.6.0...v0.7.0)

### Changed

* Use `PLACEOS_LOCAL_BUILD` instead of `PLACEOS_BUILD_LOCAL_BUILDS` to enable local builds.

### Fixed

* **executable**:
  * Correct construction of file glob.

## [0.6.0](https://github.com/PlaceOS/build/compare/v0.5.1...v0.6.0)

### Added

* **logging**:
  * Expand trace logging ([c6015e3](https://github.com/PlaceOS/build/commit/c6015e3))
  * `PLACEOS_ENABLE_TRACE` to enable trace logging ([c6015e3](https://github.com/PlaceOS/build/commit/c6015e3))

* **cli:build**:
  * Add `--discover` to auto-discover drivers ([2e0cb79](https://github.com/PlaceOS/build/commit/2e0cb79) )

### Fixed

* **api:driver**: correct path to binary ([638e38f](https://github.com/PlaceOS/build/commit/638e38f))
* **cli:build**: extract crystal version from constants ([77aa6f4](https://github.com/PlaceOS/build/commit/77aa6f4))
* **repository_store**: ignore requires outside repository ([b2a8e38](https://github.com/PlaceOS/build/commit/b2a8e38))
* **client**: return Array(commits), not Array(String) ([d63404f](https://github.com/PlaceOS/build/commit/d63404f))
* **drivers**: configure threads for require builds ([5d81c24](https://github.com/PlaceOS/build/commit/5d81c24))

## [0.5.1](https://github.com/PlaceOS/build/compare/v0.5.0...v0.5.1)

### Changed

* **digest:**
  * Lower verbosity on digests ([ef2eea0](https://github.com/PlaceOS/build/commit/ef2eea0))

### Fixed

* **client:**
  * Add a raise to `#compile`, fixes a problem where failed requests were parsed as successful ([b6e0474](https://github.com/PlaceOS/build/commit/b6e0474))

* **openapi:**
  * Defer OpenAPI schema generation until types are known ([2b61df7](https://github.com/PlaceOS/build/commit/2b61df7))

* **drivers:**
  * Strip local path to repository in discovery ([622f510](https://github.com/PlaceOS/build/commit/622f510))

## [0.5.0](https://github.com/PlaceOS/build/compare/v0.4.0...v0.5.0)

### Added

* **compilation:**
  * add `Compilation::Success#executable` ([c7fb47b](https://github.com/PlaceOS/build/commit/c7fb47b))*

### Changed

* **compilation:**
  * Use a module instead of an alias ([1fbca94](https://github.com/PlaceOS/build/commit/1fbca94))*

## [0.4.0](https://github.com/PlaceOS/build/compare/v0.1.1...v0.4.0)

### Added

*   support local paths ([7624f6ae](https://github.com/PlaceOS/build/commit/7624f6ae))
*   source and requires ingester ([a1393ca4](https://github.com/PlaceOS/build/commit/a1393ca4))
* **api:**
  *  add discover_drivers ([edb16117](https://github.com/PlaceOS/build/commit/edb16117))
  *  included compilation time in responses ([ecb328ab](https://github.com/PlaceOS/build/commit/ecb328ab))
* **api/client:**
  *  add force_recompile argument ([906be48d](https://github.com/PlaceOS/build/commit/906be48d))
  *  add query ([8b906c49](https://github.com/PlaceOS/build/commit/8b906c49))
* **api/driver:**  implement builder api and header authentication ([faf5680d](https://github.com/PlaceOS/build/commit/faf5680d))
* **api/repositories:**  implement repository queries ([b8d5c729](https://github.com/PlaceOS/build/commit/b8d5c729))
* **api/root:**  implement healthcheck and version ([0c0fc935](https://github.com/PlaceOS/build/commit/0c0fc935))
* **cli:**
  *  add option to build from a local repo ([a5c0a820](https://github.com/PlaceOS/build/commit/a5c0a820))
  *  build a CLI on top of Clip ([f22bb4b1](https://github.com/PlaceOS/build/commit/f22bb4b1))
* **cli/build:**  implement driver compilation CLI ([547dd1cb](https://github.com/PlaceOS/build/commit/547dd1cb))
* **client:**
  *  add request_id argument ([272e9df2](https://github.com/PlaceOS/build/commit/272e9df2))
  *  implement a HTTP client ([3a048dcf](https://github.com/PlaceOS/build/commit/3a048dcf))
* **compilation:**  compilation via entrypoint works ([90131544](https://github.com/PlaceOS/build/commit/90131544))
* **compiler:**
  *  enable toggle of asdf support ([2074fb23](https://github.com/PlaceOS/build/commit/2074fb23))
  *  simplify fetching latest crystal ([cfc9c07b](https://github.com/PlaceOS/build/commit/cfc9c07b))
  *  path? to lookup crystal binary ([79073c7b](https://github.com/PlaceOS/build/commit/79073c7b))
  *  asdf compiler management ([955b052e](https://github.com/PlaceOS/build/commit/955b052e))
* **digest:**
  *  digest source without installing ([fbbed339](https://github.com/PlaceOS/build/commit/fbbed339))
  *  digest files in parallel ([387bc174](https://github.com/PlaceOS/build/commit/387bc174))
* **digest_cli:**
  *  extract requires ([dd321098](https://github.com/PlaceOS/build/commit/dd321098))
  *  add bindings to cli, drastically increase performance ([a3f33536](https://github.com/PlaceOS/build/commit/a3f33536))
* **driver_store/s3:**  implement s3 backed driver store ([f8685e88](https://github.com/PlaceOS/build/commit/f8685e88))
* **drivers:**
  *  independent compilation ([6f065935](https://github.com/PlaceOS/build/commit/6f065935))
  *  binary store interface ([35773192](https://github.com/PlaceOS/build/commit/35773192))
* **repository_sore:**  get commits for all files referenced by driver ([b21de3f2](https://github.com/PlaceOS/build/commit/b21de3f2))
* **repository_store:**  implement a simple git interface ([8d217d1c](https://github.com/PlaceOS/build/commit/8d217d1c))
* **s3:**  generate a client depedent on credentials ([940b9c8f](https://github.com/PlaceOS/build/commit/940b9c8f))

### Bug Fixes

*   default to new build method ([79da583a](https://github.com/PlaceOS/build/commit/79da583a))
*   small HTTP type issues ([2b951238](https://github.com/PlaceOS/build/commit/2b951238))
*   compilation stoppers ([92b93584](https://github.com/PlaceOS/build/commit/92b93584))
*   update `Git` interfaces ([e17c972c](https://github.com/PlaceOS/build/commit/e17c972c))
* **Dockerfile.test:**  remove build step ([0b08aa9a](https://github.com/PlaceOS/build/commit/0b08aa9a))
* **actions:**  fixup check for legacy flag ([a31d86cb](https://github.com/PlaceOS/build/commit/a31d86cb))
* **api/driver:**  remove redundant constant ([4ff02c41](https://github.com/PlaceOS/build/commit/4ff02c41))
* **api:driver:**  manually set https reponse (would be good to support merge) ([7f4ef55c](https://github.com/PlaceOS/build/commit/7f4ef55c))
* **cli:**  exit 1 on error ([3d95aa0b](https://github.com/PlaceOS/build/commit/3d95aa0b))
* **cli/build:**  pass store instead of path ([7d8dffbd](https://github.com/PlaceOS/build/commit/7d8dffbd))
* **client:**
  *  correct types for query params ([bf49bbd5](https://github.com/PlaceOS/build/commit/bf49bbd5))
  *  arg typo ([81ac5f8f](https://github.com/PlaceOS/build/commit/81ac5f8f))
  *  forward request_id for branches ([22b2b5f0](https://github.com/PlaceOS/build/commit/22b2b5f0))
  *  encode filename ([c04daa1f](https://github.com/PlaceOS/build/commit/c04daa1f))
* **config:**  add log filters for sensitive params ([4e99f1a7](https://github.com/PlaceOS/build/commit/4e99f1a7))
* **digest:**
  *  proc block syntax error ([73467d60](https://github.com/PlaceOS/build/commit/73467d60))
  *  ensure correct calls ([1dc87140](https://github.com/PlaceOS/build/commit/1dc87140))
* **digest_cli:**  bugs related to argument parsing ([98365664](https://github.com/PlaceOS/build/commit/98365664))
* **drivers:**  correct temporary directory logic ([656d5f16](https://github.com/PlaceOS/build/commit/656d5f16))

### Performance

*   use scry's graph traversal ([2287dc3c](https://github.com/PlaceOS/build/commit/2287dc3c))
