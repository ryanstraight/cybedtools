# Domain helper: element-to-framework bindings with framework name attached

**\[stable\]**

One row per (element, framework) pair where the partOf target is itself
typed as `cybed:Framework`. Elements without a `cybed:partOf` triple, or
whose partOf target is not a Framework, are excluded.

## Usage

``` r
element_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `element`, `framework`, `framework_name`.

## See also

Other SPARQL helpers:
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
element_framework_bindings(rdf)
} # }
```
