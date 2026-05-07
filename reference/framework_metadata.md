# Domain helper: tibble of framework metadata

**\[stable\]**

Calls one single-BGP query per metadata property and inner-joins on the
framework URI. The set of frameworks is anchored by the `rdf:type`
triple (`?s a cybed:Framework`), so frameworks missing any property
still appear in the output (with `NA` in the missing column) thanks to
`left_join`.

## Usage

``` r
framework_metadata(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `framework`, `name`, `jurisdiction`, `sector`,
`specificity`. One row per framework typed as `cybed:Framework`.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
framework_metadata(rdf)
} # }
```
