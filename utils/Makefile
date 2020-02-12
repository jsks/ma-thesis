CFLAGS = -Wall -Wextra -march=x86-64 -O2 -pipe

all: extract
.PHONY: clean debug

debug: clean
debug: CFLAGS += -DDEBUG -g -fsanitize=address -fno-omit-frame-pointer
debug: extract

extract: extract.c
	gcc $(CFLAGS) $< -o $@

clean:
	rm -rf extract
