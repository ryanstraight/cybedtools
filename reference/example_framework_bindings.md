# Domain helper: example-to-framework bindings with framework name attached

**\[stable\]**

One row per (example, framework) pair where the example is typed
`cybed:Example` (the pedagogical-scaffolding subtype reserved for
Cyber.org K-12 and CSTA "Clarification statement:" content) and its
`partOf` target is typed `cybed:Framework`. Examples without a valid
framework partOf are excluded.

Examples are a strict subset of the elements returned by
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md).
Use this helper when reporting on the Subpoint-vs-Example split for a
framework, or when constructing a "strict" element count (parent +
Subpoint, no Example) by subtracting Example counts from total element
counts.

## Usage

``` r
example_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `example`, `framework`, `framework_name`.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
example_framework_bindings(rdf)
} # }
```
