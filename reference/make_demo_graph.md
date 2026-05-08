# Build a small in-memory demo RDF graph

**\[stable\]**

Returns an `rdf` object containing a synthetic two-framework graph with
the structural shape the package's helpers expect under the v0.2.0
vocabulary:

- **Framework A** (US, civilian, cybersecurity-specific) is
  workforce-shaped: its 2 organizing units are typed `cybed:Role` and
  `cybed:OrganizingUnit`, mirroring NICE / DCWF / ENISA ECSF.

- **Framework B** (EU, general, general-IT) is non-workforce-shaped: its
  1 organizing unit is typed `cybed:OrganizingUnit` only, mirroring SFIA
  / Cyber.org K-12 / CSTA / CSEC2017 / DigComp 2.2.

The graph also includes 5 atomic elements (typed `cybed:RoleElement`),
one `cybed:Subpoint` (an enumerated child of an element, reachable via
the role's `cybed:hasElement`), and one `cybed:Example` (a pedagogical-
scaffolding child, reachable only via the parent element's
`cybed:hasExample` and excluded from default `cybed:hasElement`
traversals). This is enough to exercise the cross-framework pivots
(`cybed:OrganizingUnit`), the workforce-only pivots (`cybed:Role`), the
Subpoint vs Example separation, and the per-framework pivots in a single
small graph.

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

An `rdf` object containing roughly 50 triples.

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
organizing_unit_framework_bindings(rdf)   # all three units, both frameworks
#> # A tibble: 3 × 4
#>   unit                                        framework unit_name framework_name
#>   <chr>                                       <chr>     <chr>     <chr>         
#> 1 https://w3id.org/cybed/ontology#role/demo-… https://… IT Gener… Demo Framewor…
#> 2 https://w3id.org/cybed/ontology#role/demo-… https://… Incident… Demo Framewor…
#> 3 https://w3id.org/cybed/ontology#role/demo-… https://… Security… Demo Framewor…
role_framework_bindings(rdf)              # only the two workforce-shaped units
#> # A tibble: 2 × 4
#>   role                                        framework role_name framework_name
#>   <chr>                                       <chr>     <chr>     <chr>         
#> 1 https://w3id.org/cybed/ontology#role/demo-… https://… Incident… Demo Framewor…
#> 2 https://w3id.org/cybed/ontology#role/demo-… https://… Security… Demo Framewor…
sparql_pairs(rdf, "cybed:hasExample")     # the parent -> example link
#> # A tibble: 1 × 2
#>   s                                                  o                          
#>   <chr>                                              <chr>                      
#> 1 https://w3id.org/cybed/ontology#element/demo-el-b1 https://w3id.org/cybed/ont…
```
