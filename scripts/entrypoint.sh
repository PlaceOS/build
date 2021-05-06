#! /usr/bin/bash

set -eu

source /app/.asdf/asdf.sh

/app/bin/build "$@"
