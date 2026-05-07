# Load every framework's JSON-LD into a unified rdflib graph

**\[experimental\]**

Iterates the standard framework set and parses each into a shared rdf
object. Functionally equivalent to
[`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md)
but useful when per-framework diagnostics are needed. Marked
experimental because the default slug list will track
NICE/SFIA/DCWF/ECSF/CSEC/etc. as they revise.

## Usage

``` r
load_unified_rdf_graph(
  framework_slugs = c("nice", "sfia", "dcwf", "ecsf", "cyberorg-k12", "csta", "csec2017",
    "digcomp"),
  jsonld_dir = NULL
)
```

## Arguments

- framework_slugs:

  Character vector of framework slugs.

- jsonld_dir:

  Character path.

## Value

An rdf object.

## See also

Other RDF graph loading:
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md),
[`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md),
[`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md),
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_unified_rdf_graph()
} # }
```
