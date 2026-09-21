# Domain helper: role-to-framework bindings with framework name attached

**\[stable\]**

One row per (role, framework) pair where the role is typed `cybed:Role`
and its `partOf` target is typed `cybed:Framework`. As of v0.2.0,
`cybed:Role` is reserved for workforce frameworks (NICE work roles, DCWF
work roles, ENISA ECSF profiles, CyQUAL work roles, CCSSF work roles,
OTCCF job roles); SFIA skills, Cyber.org K-12 grade-band x sub-concept
cells, CSTA level x concept cells, CSEC2017 Knowledge Areas, and DigComp
competence areas are not roles and are not returned by this helper. Use
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
for the cross-framework "top-level enumerated unit" cut that includes
every framework in the corpus.

Roles without a `cybed:partOf` triple, or whose partOf target is not
typed `cybed:Framework`, are excluded.

## Usage

``` r
role_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `role`, `role_name`, `framework`,
`framework_name`, `framework_slug` (added v0.4.0, a stable join key).

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
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md),
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md),
[`unit_relation_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_relation_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
role_framework_bindings(rdf)
} # }
```
