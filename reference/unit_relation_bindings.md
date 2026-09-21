# Domain helper: unit-to-unit relation bindings

**\[experimental\]**

One row per `cybed:UnitRelation` node
([`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/reference/build_unit_relation_node.md)),
giving the related pair of organizing units plus the relation's own
framework attribution. `relation` is `NA` for a plain (unlabeled)
relation; `framework_slug` is `NA` when the relation node carries no
`cybed:partOf`, or one whose target is not typed `cybed:Framework`.

## Usage

``` r
unit_relation_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `from_unit`, `relation`, `to_unit`,
`framework_slug`.

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
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
unit_relation_bindings(rdf)
} # }
```
