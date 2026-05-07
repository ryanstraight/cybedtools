# Load the pre-assembled combined multi-framework JSON-LD into an rdflib graph

**\[stable\]**

Wraps
[`rdflib::rdf_parse()`](https://docs.ropensci.org/rdflib/reference/rdf_parse.html)
with a sensible default path under
`data/processed/jsonld/_combined.jsonld`. Errors with a classed
condition (`cybedtools_file_not_found`) when the file is absent so
callers can branch on it.

## Usage

``` r
load_combined_rdf_graph(file_path = NULL)
```

## Arguments

- file_path:

  Character path to `_combined.jsonld`. Defaults to the standard
  location under `data/processed/jsonld/`.

## Value

An rdf object from the rdflib package.

## See also

Other RDF graph loading:
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md),
[`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md),
[`load_unified_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_unified_rdf_graph.md),
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_rdf_graph()
} # }
```
