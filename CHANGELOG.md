# Changelog

All changes are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning 2.0.0](https://semver.org/).

## [0.4.0](https://github.com/PlaceOS/build/compare/v0.1.1...v0.4.0)

## Features

*   support local paths ([7624f6ae](7624f6ae))
*   source and requires ingester ([a1393ca4](a1393ca4))
* **api:**
  *  add discover_drivers ([edb16117](edb16117))
  *  included compilation time in responses ([ecb328ab](ecb328ab))
* **api/client:**
  *  add force_recompile argument ([906be48d](906be48d))
  *  add query ([8b906c49](8b906c49))
* **api/driver:**  implement builder api and header authentication ([faf5680d](faf5680d))
* **api/repositories:**  implement repository queries ([b8d5c729](b8d5c729))
* **api/root:**  implement healthcheck and version ([0c0fc935](0c0fc935))
* **cli:**
  *  add option to build from a local repo ([a5c0a820](a5c0a820))
  *  build a CLI on top of Clip ([f22bb4b1](f22bb4b1))
* **cli/build:**  implement driver compilation CLI ([547dd1cb](547dd1cb))
* **client:**
  *  add request_id argument ([272e9df2](272e9df2))
  *  implement a HTTP client ([3a048dcf](3a048dcf))
* **compilation:**  compilation via entrypoint works ([90131544](90131544))
* **compiler:**
  *  enable toggle of asdf support ([2074fb23](2074fb23))
  *  simplify fetching latest crystal ([cfc9c07b](cfc9c07b))
  *  path? to lookup crystal binary ([79073c7b](79073c7b))
  *  asdf compiler management ([955b052e](955b052e))
* **digest:**
  *  digest source without installing ([fbbed339](fbbed339))
  *  digest files in parallel ([387bc174](387bc174))
* **digest_cli:**
  *  extract requires ([dd321098](dd321098))
  *  add bindings to cli, drastically increase performance ([a3f33536](a3f33536))
* **driver_store/s3:**  implement s3 backed driver store ([f8685e88](f8685e88))
* **drivers:**
  *  independent compilation ([6f065935](6f065935))
  *  binary store interface ([35773192](35773192))
* **repository_sore:**  get commits for all files referenced by driver ([b21de3f2](b21de3f2))
* **repository_store:**  implement a simple git interface ([8d217d1c](8d217d1c))
* **s3:**  generate a client depedent on credentials ([940b9c8f](940b9c8f))

#### Bug Fixes

*   default to new build method ([79da583a](79da583a))
*   small HTTP type issues ([2b951238](2b951238))
*   compilation stoppers ([92b93584](92b93584))
*   update `Git` interfaces ([e17c972c](e17c972c))
* **Dockerfile.test:**  remove build step ([0b08aa9a](0b08aa9a))
* **actions:**  fixup check for legacy flag ([a31d86cb](a31d86cb))
* **api/driver:**  remove redundant constant ([4ff02c41](4ff02c41))
* **api:driver:**  manually set https reponse (would be good to support merge) ([7f4ef55c](7f4ef55c))
* **cli:**  exit 1 on error ([3d95aa0b](3d95aa0b))
* **cli/build:**  pass store instead of path ([7d8dffbd](7d8dffbd))
* **client:**
  *  correct types for query params ([bf49bbd5](bf49bbd5))
  *  arg typo ([81ac5f8f](81ac5f8f))
  *  forward request_id for branches ([22b2b5f0](22b2b5f0))
  *  encode filename ([c04daa1f](c04daa1f))
* **config:**  add log filters for sensitive params ([4e99f1a7](4e99f1a7))
* **digest:**
  *  proc block syntax error ([73467d60](73467d60))
  *  ensure correct calls ([1dc87140](1dc87140))
* **digest_cli:**  bugs related to argument parsing ([98365664](98365664))
* **drivers:**  correct temporary directory logic ([656d5f16](656d5f16))

#### Performance

*   use scry's graph traversal ([2287dc3c](2287dc3c))
