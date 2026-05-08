# Domain helper: organizing-unit-to-framework bindings with framework name attached

**\[stable\]**

One row per (organizing unit, framework) pair across all eight
frameworks. Queries on the cross-framework abstract type
`cybed:OrganizingUnit`, which every framework's top-level enumerated
unit asserts (work roles, work profiles, skills, grade-band concepts,
level-concept buckets, Knowledge Areas, competence areas). Use this
helper for cross-framework parent-level analysis. Use
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
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

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
organizing_unit_framework_bindings(rdf)
} # }
```
