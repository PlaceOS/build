#! /usr/bin/env bash

set -eu

source $HOME/.asdf/asdf.sh

asdf install crystal 1.0.0
asdf global crystal 1.0.0

if [ -z ${GITHUB_ACTION+x} ]
then
  echo '### `crystal tool format --check`'
  crystal tool format --check

  echo '### `ameba`' crystal lib/ameba/bin/ameba.cr
  crystal lib/ameba/bin/ameba.cr
fi

CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
shards build digest --ignore-crystal-version --error-trace

watch="false"
multithreaded="false"
while [[ $# -gt 0 ]]
do
  arg="$1"
  case $arg in
    -m|--multithreaded)
    multithreaded="true"
    shift
    ;;
    -w|--watch)
    watch="true"
    shift
    ;;
  esac
done

if [[ "$multithreaded" == "true" ]]; then
  args="-Dpreview_mt"
else
  args=""
fi

if [[ "$watch" == "true" ]]; then
  CRYSTAL_WORKERS=$(nproc) watchexec -e cr -c -r -w src -w spec -- scripts/crystal-spec.sh -v ${args}
else
  CRYSTAL_WORKERS=$(nproc) scripts/crystal-spec.sh -v ${args}
fi
