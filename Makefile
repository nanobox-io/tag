.PHONY: test

test:
	luvi . -m ./test/run.lua

libs:
	gcc -fPIC -c ./lib/store/basic/compare.c
	gcc -shared -o ./lib/store/basic/OSX_x64/libcompare.so ./lib/store/basic/compare.c