# Changelog

All changes are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

## [0.4.0](https://github.com/PlaceOS/build/compare/v0.1.1...v0.4.0)

## Features


https://github.com/PlaceOS/rest-api/commit/

*   support local paths ([7624f6ae](https://github.com/PlaceOS/rest-api/commit/7624f6ae))
*   source and requires ingester ([a1393ca4](https://github.com/PlaceOS/rest-api/commit/a1393ca4))
* **api:**
  *  add discover_drivers ([edb16117](https://github.com/PlaceOS/rest-api/commit/edb16117))
  *  included compilation time in responses ([ecb328ab](https://github.com/PlaceOS/rest-api/commit/ecb328ab))
* **api/client:**
  *  add force_recompile argument ([906be48d](https://github.com/PlaceOS/rest-api/commit/906be48d))
  *  add query ([8b906c49](https://github.com/PlaceOS/rest-api/commit/8b906c49))
* **api/driver:**  implement builder api and header authentication ([faf5680d](https://github.com/PlaceOS/rest-api/commit/faf5680d))
* **api/repositories:**  implement repository queries ([b8d5c729](https://github.com/PlaceOS/rest-api/commit/b8d5c729))
* **api/root:**  implement healthcheck and version ([0c0fc935](https://github.com/PlaceOS/rest-api/commit/0c0fc935))
* **cli:**
  *  add option to build from a local repo ([a5c0a820](https://github.com/PlaceOS/rest-api/commit/a5c0a820))
  *  build a CLI on top of Clip ([f22bb4b1](https://github.com/PlaceOS/rest-api/commit/f22bb4b1))
* **cli/build:**  implement driver compilation CLI ([547dd1cb](https://github.com/PlaceOS/rest-api/commit/547dd1cb))
* **client:**
  *  add request_id argument ([272e9df2](https://github.com/PlaceOS/rest-api/commit/272e9df2))
  *  implement a HTTP client ([3a048dcf](https://github.com/PlaceOS/rest-api/commit/3a048dcf))
* **compilation:**  compilation via entrypoint works ([90131544](https://github.com/PlaceOS/rest-api/commit/90131544))
* **compiler:**
  *  enable toggle of asdf support ([2074fb23](https://github.com/PlaceOS/rest-api/commit/2074fb23))
  *  simplify fetching latest crystal ([cfc9c07b](https://github.com/PlaceOS/rest-api/commit/cfc9c07b))
  *  path? to lookup crystal binary ([79073c7b](https://github.com/PlaceOS/rest-api/commit/79073c7b))
  *  asdf compiler management ([955b052e](https://github.com/PlaceOS/rest-api/commit/955b052e))
* **digest:**
  *  digest source without installing ([fbbed339](https://github.com/PlaceOS/rest-api/commit/fbbed339))
  *  digest files in parallel ([387bc174](https://github.com/PlaceOS/rest-api/commit/387bc174))
* **digest_cli:**
  *  extract requires ([dd321098](https://github.com/PlaceOS/rest-api/commit/dd321098))
  *  add bindings to cli, drastically increase performance ([a3f33536](https://github.com/PlaceOS/rest-api/commit/a3f33536))
* **driver_store/s3:**  implement s3 backed driver store ([f8685e88](https://github.com/PlaceOS/rest-api/commit/f8685e88))
* **drivers:**
  *  independent compilation ([6f065935](https://github.com/PlaceOS/rest-api/commit/6f065935))
  *  binary store interface ([35773192](https://github.com/PlaceOS/rest-api/commit/35773192))
* **repository_sore:**  get commits for all files referenced by driver ([b21de3f2](https://github.com/PlaceOS/rest-api/commit/b21de3f2))
* **repository_store:**  implement a simple git interface ([8d217d1c](https://github.com/PlaceOS/rest-api/commit/8d217d1c))
* **s3:**  generate a client depedent on credentials ([940b9c8f](https://github.com/PlaceOS/rest-api/commit/940b9c8f))

#### Bug Fixes

*   default to new build method ([79da583a](https://github.com/PlaceOS/rest-api/commit/79da583a))
*   small HTTP type issues ([2b951238](https://github.com/PlaceOS/rest-api/commit/2b951238))
*   compilation stoppers ([92b93584](https://github.com/PlaceOS/rest-api/commit/92b93584))
*   update `Git` interfaces ([e17c972c](https://github.com/PlaceOS/rest-api/commit/e17c972c))
* **Dockerfile.test:**  remove build step ([0b08aa9a](https://github.com/PlaceOS/rest-api/commit/0b08aa9a))
* **actions:**  fixup check for legacy flag ([a31d86cb](https://github.com/PlaceOS/rest-api/commit/a31d86cb))
* **api/driver:**  remove redundant constant ([4ff02c41](https://github.com/PlaceOS/rest-api/commit/4ff02c41))
* **api:driver:**  manually set https reponse (would be good to support merge) ([7f4ef55c](https://github.com/PlaceOS/rest-api/commit/7f4ef55c))
* **cli:**  exit 1 on error ([3d95aa0b](https://github.com/PlaceOS/rest-api/commit/3d95aa0b))
* **cli/build:**  pass store instead of path ([7d8dffbd](https://github.com/PlaceOS/rest-api/commit/7d8dffbd))
* **client:**
  *  correct types for query params ([bf49bbd5](https://github.com/PlaceOS/rest-api/commit/bf49bbd5))
  *  arg typo ([81ac5f8f](https://github.com/PlaceOS/rest-api/commit/81ac5f8f))
  *  forward request_id for branches ([22b2b5f0](https://github.com/PlaceOS/rest-api/commit/22b2b5f0))
  *  encode filename ([c04daa1f](https://github.com/PlaceOS/rest-api/commit/c04daa1f))
* **config:**  add log filters for sensitive params ([4e99f1a7](https://github.com/PlaceOS/rest-api/commit/4e99f1a7))
* **digest:**
  *  proc block syntax error ([73467d60](https://github.com/PlaceOS/rest-api/commit/73467d60))
  *  ensure correct calls ([1dc87140](https://github.com/PlaceOS/rest-api/commit/1dc87140))
* **digest_cli:**  bugs related to argument parsing ([98365664](https://github.com/PlaceOS/rest-api/commit/98365664))
* **drivers:**  correct temporary directory logic ([656d5f16](https://github.com/PlaceOS/rest-api/commit/656d5f16))

#### Performance

*   use scry's graph traversal ([2287dc3c](https://github.com/PlaceOS/rest-api/commit/2287dc3c))
