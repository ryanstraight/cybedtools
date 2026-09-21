# Domain helper: organizing-unit-to-element bindings

**\[stable\]**

One row per (parent, element) pair derived from `cybed:hasElement`
triples. Despite the "role" naming, the `role` column is NOT restricted
to `cybed:Role` subjects – `cybed:hasElement` is the universal parent-
child link used across every framework in the corpus, so this returns
element bindings for every `cybed:OrganizingUnit` (SFIA skills,
Cyber.org K-12 and CSTA standards, etc.), not just NICE/DCWF/ECSF work
roles. Confirmed by a 2026-08-14 stress test: most distinct values in
the `role` column are not actual `cybed:Role` subjects. Low practical
risk when immediately joined against
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
unit_element_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `role`, `element`, `framework_slug`.
`framework_slug` (added v0.4.0) is the slug of the `role` (organizing
unit) subject's own framework, taken from
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md);
a `role` with no valid `cybed:partOf` to a `cybed:Framework` carries
`NA` here rather than dropping the row, so this helper's row count is
unchanged from before v0.4.0.

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
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md),
[`unit_relation_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_relation_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
unit_element_bindings(rdf)
} # }
```
