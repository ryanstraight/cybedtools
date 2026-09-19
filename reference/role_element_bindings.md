# Domain helper: organizing-unit-to-element bindings

**\[stable\]**

One row per (parent, element) pair derived from `cybed:hasElement`
triples. Despite the "role" naming, the `role` column is NOT restricted
to `cybed:Role` subjects – `cybed:hasElement` is the universal parent-
child link used across all eleven frameworks, so this returns element
bindings for every `cybed:OrganizingUnit` (SFIA skills, Cyber.org K-12
and CSTA standards, etc.), not just NICE/DCWF/ECSF work roles. Confirmed
2026-08-14 stress test: of 428 distinct values in the `role` column,
only 127 (30%) are actual `cybed:Role` subjects. Low practical risk when
immediately joined against
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
or
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
(the mismatches drop out), but a standalone aggregate over this tibble's
`role` column (e.g. "average elements per role") will silently include
non-role parents. Filter to `cybed:Role` first via
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
if that distinction matters for your analysis.

## Usage

``` r
role_element_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `role`, `element`.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`element_text()`](https://ryanstraight.github.io/cybedtools/reference/element_text.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
role_element_bindings(rdf)
} # }
```
