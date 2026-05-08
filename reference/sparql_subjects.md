# Run a single-BGP SPARQL select with fixed predicate and object

**\[stable\]**

Issues a `SELECT ?s WHERE { ?s P O }` query where `P` and `O` are the
supplied predicate and object. Useful when the object is a known type
(e.g., `predicate = "a"`, `object = "cybed:Framework"`).

## Usage

``` r
sparql_subjects(rdf, predicate, object)
```

## Arguments

- rdf:

  An rdf object.

- predicate:

  Character SPARQL predicate.

- object:

  Character SPARQL object (either prefixed-URI or literal).

## Value

A tibble with column `s` (character).

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
sparql_subjects(rdf, "a", "cybed:Framework")
} # }
```
