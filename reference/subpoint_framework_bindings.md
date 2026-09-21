# Domain helper: subpoint-to-framework bindings with framework name attached

**\[stable\]**

One row per (subpoint, framework) pair where the subpoint is typed
`cybed:Subpoint` (the generic enumeration-list-splitting subtype – "such
as X, Y, and Z" / "including A and B" – parsed out of a single native
unit's text at JSON-LD assembly time, applied uniformly across the
corpus) and its `partOf` target is typed `cybed:Framework`. Subpoints
without a valid framework partOf are excluded.

Subpoints are a strict subset of the elements returned by
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
and a distinct subtype from
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)'s
`cybed:Example` (the Cyber.org K-12 / CSTA Clarification-statement
pedagogical-scaffolding subtype specifically). Use this helper together
with
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
when constructing a "strict" native element count by subtracting both
Subpoint and Example counts from the total element count – see
`framework_summary`'s `element_count_strict` column, which does exactly
this.

## Usage

``` r
subpoint_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `subpoint`, `framework`, `framework_name`,
`framework_slug` (added v0.4.0, a stable join key).

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
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md),
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md),
[`unit_relation_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_relation_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
subpoint_framework_bindings(rdf)
} # }
```
