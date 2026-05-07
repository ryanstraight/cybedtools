# Load a single framework's JSON-LD into a new rdflib graph

**\[stable\]**

Loads exactly one framework, used when per-framework diagnostics or
isolated SPARQL queries are needed.

## Usage

``` r
load_single_framework_graph(framework_slug, jsonld_dir = NULL)
```

## Arguments

- framework_slug:

  Character, one of `"nice"`, `"sfia"`, `"dcwf"`, `"ecsf"`,
  `"cyberorg-k12"`, `"csta"`, `"csec2017"`, or `"digcomp"`.

- jsonld_dir:

  Character path to the directory containing per-framework JSON-LD
  files. Defaults to `data/processed/jsonld/`.

## Value

An rdf object.

## See also

Other RDF graph loading:
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md),
[`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md),
[`load_unified_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_unified_rdf_graph.md),
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_single_framework_graph("ecsf")
} # }
```
