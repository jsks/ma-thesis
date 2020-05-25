all: test
.PHONY: test

test:
	@pandoc --quiet -s -t markdown --lua-filter=text_refs.lua sample.md | \
		diff -bu expected.md - && echo "text_ref: Success!"
