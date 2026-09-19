# Domain helper: example-to-framework bindings with framework name attached

**\[stable\]**

One row per (example, framework) pair where the example is typed
`cybed:Example` (the pedagogical-scaffolding subtype reserved for
Cyber.org K-12 and CSTA "Clarification statement:" content) and its
`partOf` target is typed `cybed:Framework`. Examples without a valid
framework partOf are excluded.

Examples are a strict subset of the elements returned by
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_framework_bindings.md).
Use this helper when reporting on the Subpoint-vs-Example split for a
framework, or when constructing a "strict" native element count by
subtracting both Example counts (this helper) and Subpoint counts
([`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/subpoint_framework_bindings.md))
from the total element count.

## Usage

``` r
example_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `example`, `framework`, `framework_name`.

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
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_framework_bindings.md),
[`element_text()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_text.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/dev/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/dev/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/dev/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/subpoint_framework_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
example_framework_bindings(rdf)
} # }
```
