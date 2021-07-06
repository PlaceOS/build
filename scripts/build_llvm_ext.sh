#! /usr/bin/env bash

CRYSTAL_PATH=${CRYSTAL_PATH:/usr/share/crystal/src}
LLVM_CONFIG=$(${CRYSTAL_PATH}/llvm/ext/find-llvm-config)

cc -c -g -O3 "$CRYSTAL_PATH/llvm/ext/llvm_ext.cc"  -o "$CRYSTAL_PATH/llvm/ext/llvm_ext.o" $($LLVM_CONFIG --cxxflags)
