# Deprecated alias for [`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md)

**\[deprecated\]**

`role_element_bindings()` is deprecated as of cybedtools 0.4.0 in favor
of
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md),
which returns the identical result (all organizing units, not just
`cybed:Role` subjects) under a name that doesn't overstate the role
restriction. This alias will be removed in a future minor version;
update call sites to
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md).

## Usage

``` r
role_element_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

See
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md).

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
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md),
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md),
[`unit_relation_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_relation_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
role_element_bindings(rdf)
} # }
```
