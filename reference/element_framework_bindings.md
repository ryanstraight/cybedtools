# Domain helper: element-to-framework bindings with framework name attached

**\[stable\]**

One row per (element, framework) pair where the element is typed
`cybed:RoleElement` (which includes parent elements, `cybed:Subpoint`
children, and `cybed:Example` children) and its `partOf` target is typed
`cybed:Framework`. Elements without a `cybed:partOf` triple, or whose
partOf target is not a Framework, are excluded.

This helper is the broad cut. Use
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
when you need only the `cybed:Example` subset (e.g., for the
"with-examples" counting column in `framework_summary`).

## Usage

``` r
element_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `element`, `framework`, `framework_name`,
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
[`element_text()`](https://ryanstraight.github.io/cybedtools/reference/element_text.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
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
element_framework_bindings(rdf)
} # }
```
