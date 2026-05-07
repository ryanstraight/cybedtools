# Domain helper: role-to-framework bindings with framework name attached

**\[stable\]**

One row per (role, framework) pair where the partOf target is itself
typed as `cybed:Framework`. Roles without a `cybed:partOf` triple, or
whose partOf target is not a Framework, are excluded.

## Usage

``` r
role_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `role`, `role_name`, `framework`,
`framework_name`.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
role_framework_bindings(rdf)
} # }
```
