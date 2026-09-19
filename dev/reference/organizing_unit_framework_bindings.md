# Domain helper: organizing-unit-to-framework bindings with framework name attached

**\[stable\]**

One row per (organizing unit, framework) pair across all eleven
frameworks. Queries on the cross-framework abstract type
`cybed:OrganizingUnit`, which every framework's top-level enumerated
unit asserts (work roles, work profiles, skills, grade-band x
sub-concept cells, level x concept cells, Knowledge Areas, competence
areas). Use this helper for cross-framework parent-level analysis. Use
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_framework_bindings.md)
when the question is workforce-specific (NICE work roles, DCWF work
roles, ENISA ECSF profiles only).

Units without a `cybed:partOf` triple, or whose partOf target is not
typed `cybed:Framework`, are excluded.

## Usage

``` r
organizing_unit_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `unit`, `unit_name`, `framework`,
`framework_name`.

## Note

The `framework` column holds the framework's full URI. Avoid naming a
local variable or function parameter `framework` in code that filters or
mutates this tibble – dplyr's data masking silently resolves a bare
`framework` reference inside
[`filter()`](https://dplyr.tidyverse.org/reference/filter.html)/[`mutate()`](https://dplyr.tidyverse.org/reference/mutate.html)
to this COLUMN rather than your same-named variable, with no error and
no warning, only a wrong (often zero-row) result surfacing later.
Confirmed 2026-08-14: a helper written as
`function(framework, ...) filter(units, str_detect(framework_name, framework))`
silently returned zero rows every time.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_framework_bindings.md),
[`element_text()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_text.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/dev/reference/framework_metadata.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/dev/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/dev/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/subpoint_framework_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
organizing_unit_framework_bindings(rdf)
} # }
```
