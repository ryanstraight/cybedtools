# Read a JSON-LD document from file

**\[stable\]**

Reads a JSON-LD document via
[`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
without simplifying nested vectors. Preserves the JSON-LD
list-of-objects structure.

## Usage

``` r
read_jsonld_document(file_path)
```

## Arguments

- file_path:

  Character path.

## Value

Named list.

## See also

Other File I/O:
[`write_jsonld_document()`](https://ryanstraight.github.io/cybedtools/reference/write_jsonld_document.md)

## Examples

``` r
tmp <- tempfile(fileext = ".jsonld")
write_jsonld_document(
  list(`@context` = build_jsonld_context("nice"), `@graph` = list()),
  tmp
)
#> JSON-LD written: /tmp/RtmpTTnLGf/file1b181222c4a2.jsonld
read_jsonld_document(tmp)
#> $`@context`
#> $`@context`$schema
#> [1] "http://schema.org/"
#> 
#> $`@context`$skos
#> [1] "http://www.w3.org/2004/02/skos/core#"
#> 
#> $`@context`$rdfs
#> [1] "http://www.w3.org/2000/01/rdf-schema#"
#> 
#> $`@context`$cybed
#> [1] "https://w3id.org/cybed/ontology#"
#> 
#> $`@context`$nice
#> [1] "https://nice.nist.gov/framework/terms#"
#> 
#> 
#> $`@graph`
#> list()
#> 
unlink(tmp)
```
