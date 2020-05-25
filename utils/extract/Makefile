CFLAGS = -Wall -Wextra -march=x86-64 -O2 -pipe

all: extract
.PHONY: clean debug test

clean:
	rm -rf extract

debug: clean
debug: CFLAGS += -DDEBUG -g -fsanitize=address -fno-omit-frame-pointer
debug: extract

extract: extract.c
	gcc $(CFLAGS) $< -o $@

test: debug
	@test_dir=$$(mktemp -d); \
		echo "Running tests in $$test_dir"; \
		Rscript test_data.R $$test_dir && \
		./test.sh $$test_dir; \
		rv=$$?; \
		rm -rf $$test_dir; \
		exit $$rv
