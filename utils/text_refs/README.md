# `text_refs` - Pandoc lua filter

This introduces bookdown's [text
references](http://bookdown.org/yihui/bookdown/markdown-extensions-by-bookdown.html#fn5)
for simple text substitution in plain pandoc making it easier, for
example, to write long figure captions in Rmarkdown codeblocks.

To invoke the filter when using Rmarkdown add the pandoc argument to
the yaml header.

```yaml
output:
    pdf_documents:
        pandoc_args: ["--lua-filter", "path/to/text_refs.lua"]
```

Usage within the document is then fairly straightforward.

````rmarkdown
(ref:example) Text to be inserted

```{r fig.cap = "(ref:example)"}
plot(x, y)
```

````

## Caveats

Bookdown text references have a terrible syntax which make it
impossible to start a paragraph with a reference since that would
start a definition. Also, when defining a text reference, if there
isn't at least one space between the reference key and the definition,
then the text reference will not be parsed.

One bonus though to using a lua filter is that, unlike bookdown, text
references here can span multiple lines.
