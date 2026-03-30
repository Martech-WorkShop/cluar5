# Example Makefile snippet for the Builder stage
prod-static:
	# Compile Gambit logic to C
	gsc -link -o logic_bundle.c logic.scm
	
	# Compile everything to a single static binary using musl-gcc
	musl-gcc -static -O3 -o my-app \
		main.c \
		logic_bundle.c \
		-luajit -lgambit \
		-I/usr/include/luajit-2.1 \
		-I/usr/include/gambit