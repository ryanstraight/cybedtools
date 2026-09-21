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
`specificity`, `framework_slug`. One row per framework typed as
`cybed:Framework`. `framework_slug` is added (v0.4.0) as a stable join
key across frameworks; every existing column is unchanged and row order
is unchanged.

## Note

The `framework` column holds the framework's full URI. Avoid naming a
local variable or function parameter `framework` in code that filters or
mutates this tibble – dplyr's data masking silently resolves a bare
`framework` reference inside
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html)/[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
to this COLUMN rather than your same-named variable, with no error and
no warning, only a wrong (often zero-row) result surfacing later.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`element_text()`](https://ryanstraight.github.io/cybedtools/reference/element_text.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md),
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md),
[`unit_relation_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_relation_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
framework_metadata(rdf)
} # }
```
