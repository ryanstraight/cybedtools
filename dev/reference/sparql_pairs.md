# Run a single-BGP SPARQL select returning subject-object pairs

**\[stable\]**

Issues a `SELECT ?s ?o WHERE { ?s P ?o }` query where `P` is the
supplied predicate. The predicate position is constant. Both subject and
object are bound. This is a single triple match, the only pattern shape
librdf reliably plans on graphs of cybedtools' scale.

## Usage

``` r
sparql_pairs(rdf, predicate)
```

## Arguments

- rdf:

  An rdf object from
  [`rdflib::rdf_parse()`](https://docs.ropensci.org/rdflib/reference/rdf_parse.html)
  or
  [`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/dev/reference/load_combined_ntriples_graph.md).

- predicate:

  Character. A SPARQL predicate (e.g., `"cybed:partOf"`,
  `"schema:name"`, `"a"`). Use the prefixed form. `default_prefixes()`
  supplies cybed, schema, rdfs, and skos.

## Value

A tibble with columns `s` (character, subject URI) and `o` (character,
object value, either URI or literal).

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_framework_bindings.md),
[`element_text()`](https://ryanstraight.github.io/cybedtools/dev/reference/element_text.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/dev/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/role_framework_bindings.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/dev/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/dev/reference/subpoint_framework_bindings.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
sparql_pairs(rdf, "cybed:jurisdiction")
} # }
```
