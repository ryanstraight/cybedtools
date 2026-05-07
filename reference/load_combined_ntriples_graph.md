# Load the pre-combined N-Triples file into an rdflib graph

**\[stable\]**

Faster than parsing JSON-LD when the combined graph has been exported
via `scripts/025-export-ntriples.R`. Use this for iterative SPARQL work
and as the data source when publishing to a Fuseki or Blazegraph
endpoint.

## Usage

``` r
load_combined_ntriples_graph(file_path = NULL)
```

## Arguments

- file_path:

  Character path to `_combined.nt`. Defaults to the standard location
  under `data/processed/ntriples/`.

## Value

An rdf object.

## See also

Other RDF graph loading:
[`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md),
[`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md),
[`load_unified_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_unified_rdf_graph.md),
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
} # }
```
