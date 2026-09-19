# Validate a JSON-LD node's minimum required structure

**\[stable\]**

Checks presence of `@context` (when top-level), `@id`, `@type`. Does NOT
perform full JSON-LD 1.1 compliance checking. Use an external validator
for that.

## Usage

``` r
validate_jsonld_node(jsonld_node, require_context = FALSE)
```

## Arguments

- jsonld_node:

  A named list representing a JSON-LD node.

- require_context:

  Logical, `TRUE` if this is a top-level document.

## Value

A named list with elements `valid` (logical) and `missing_fields`
(character vector).

## Examples

``` r
good <- list(`@id` = "x", `@type` = "Y")
validate_jsonld_node(good)
#> $valid
#> [1] TRUE
#> 
#> $missing_fields
#> character(0)
#> 

bad <- list(`@id` = "x")
validate_jsonld_node(bad)
#> $valid
#> [1] FALSE
#> 
#> $missing_fields
#> [1] "@type"
#> 
```
