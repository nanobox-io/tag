LUAJIT_OS=$(shell luajit -e "print(require('ffi').os)")
LUAJIT_ARCH=$(shell luajit -e "print(require('ffi').arch)")
TARGET_DIR=$(LUAJIT_OS)-$(LUAJIT_ARCH)

.PHONY: test

test:
	luvi . -m ./test/run.lua

libs:
	mkdir -p ./lib/${TARGET_DIR}
	gcc -shared -o ./lib/${TARGET_DIR}/libcompare.so ./lib/store/basic/compare.c