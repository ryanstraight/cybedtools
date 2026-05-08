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

A tibble with columns `element`, `framework`, `framework_name`.

## See also

Other SPARQL helpers:
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
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
element_framework_bindings(rdf)
} # }
```
