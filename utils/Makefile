CFLAGS = -Wall -Wextra -march=x86-64 -O2 -pipe

all: select
.PHONY: clean debug

debug: clean
debug: CFLAGS += -DDEBUG -g -fsanitize=address -fno-omit-frame-pointer
debug: select

select: select.c
	gcc $(CFLAGS) $< -o $@

clean:
	rm -rf select
