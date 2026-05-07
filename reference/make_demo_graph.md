# Build a small in-memory demo RDF graph

**\[stable\]**

Returns an `rdf` object containing a synthetic two-framework graph with
the structural shape the package's helpers expect: 2 frameworks
(US/civilian/cybersecurity-specific and EU/general/general-IT), 3 roles
bound to those frameworks, and 5 elements distributed across them. The
graph is small enough to execute every helper in milliseconds and is
provided so first-time users can run
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
etc. without staging upstream framework source data.

Use this to:

- Verify the package is installed and SPARQL execution works on your
  system (helpful when troubleshooting `librdf` system-library issues).

- Try out the domain helpers before running the full pipeline.

- Develop new helpers or queries against a graph small enough to reason
  about by hand.

For real cross-framework analysis, use
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md)
against a graph assembled from staged framework sources.

## Usage

``` r
make_demo_graph()
```

## Value

An `rdf` object containing roughly 30 triples.

## See also

Other RDF graph loading:
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md),
[`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md),
[`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md),
[`load_unified_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_unified_rdf_graph.md)

## Examples

``` r
rdf <- make_demo_graph()
framework_metadata(rdf)
#> # A tibble: 2 × 5
#>   framework                                name  jurisdiction sector specificity
#>   <chr>                                    <chr> <chr>        <chr>  <chr>      
#> 1 https://w3id.org/cybed/ontology#framewo… Demo… EU           gener… general-IT 
#> 2 https://w3id.org/cybed/ontology#framewo… Demo… US           civil… cybersecur…
role_framework_bindings(rdf)
#> # A tibble: 3 × 4
#>   role                                        framework role_name framework_name
#>   <chr>                                       <chr>     <chr>     <chr>         
#> 1 https://w3id.org/cybed/ontology#role/demo-… https://… IT Gener… Demo Framewor…
#> 2 https://w3id.org/cybed/ontology#role/demo-… https://… Incident… Demo Framewor…
#> 3 https://w3id.org/cybed/ontology#role/demo-… https://… Security… Demo Framewor…
sparql_pairs(rdf, "cybed:jurisdiction")
#> # A tibble: 2 × 2
#>   s                                                   o    
#>   <chr>                                               <chr>
#> 1 https://w3id.org/cybed/ontology#framework/demo-fw-b EU   
#> 2 https://w3id.org/cybed/ontology#framework/demo-fw-a US   
```
