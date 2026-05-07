# Write a JSON-LD document to file

**\[stable\]**

Writes a JSON-LD document with pretty-printing and `auto_unbox = TRUE`,
the convention used throughout the cybedtools pipeline. Creates the
parent directory if it does not exist.

## Usage

``` r
write_jsonld_document(jsonld_document, file_path)
```

## Arguments

- jsonld_document:

  A named list with `@context` and `@graph` (or a single node with
  `@context` and `@id`).

- file_path:

  Character path.

## Value

Invisibly returns `file_path`.

## See also

Other File I/O:
[`read_jsonld_document()`](https://ryanstraight.github.io/cybedtools/reference/read_jsonld_document.md)

## Examples

``` r
tmp <- tempfile(fileext = ".jsonld")
doc <- list(
  `@context` = build_jsonld_context("nice"),
  `@graph`   = list(build_framework_node(
    framework_id     = "nice-v2",
    framework_name   = "NICE",
    framework_prefix = "nice",
    version          = "2.0.0",
    publisher        = "NIST",
    jurisdiction     = "US",
    sector           = "civilian",
    specificity      = "cybersecurity-specific"
  ))
)
write_jsonld_document(doc, tmp)
#> JSON-LD written: /tmp/RtmpQG7VTZ/file1b247361e8cf.jsonld
file.exists(tmp)
#> [1] TRUE
unlink(tmp)
```
