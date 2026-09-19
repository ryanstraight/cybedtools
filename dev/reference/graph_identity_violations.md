# Find organizing units that are also statements, and self-referential links

**\[stable\]**

Two graph-level identity checks, both run over an assembled graph:

1.  No IRI may be typed both `cybed:OrganizingUnit` and
    `cybed:RoleElement`. An IRI that is both is one node standing for
    two different things, a unit and a statement, because the framework
    numbers them out of one id space.

2.  No `cybed:hasElement` triple may have the same subject and object. A
    unit that is its own element is the same defect seen from the edge
    rather than from the node.

The report is data.
[`assert_graph_identity()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_identity.md)
is the gate.

## Usage

``` r
graph_identity_violations(rdf)
```

## Arguments

- rdf:

  An rdf object from
  [`rdflib::rdf_parse()`](https://docs.ropensci.org/rdflib/reference/rdf_parse.html)
  or
  [`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/dev/reference/load_combined_ntriples_graph.md).

## Value

A tibble with one row per violation and three columns: `check`
(`"unit_element_collision"` or `"has_element_self_loop"`), `iri`, and
`framework` (the local name of the framework the IRI declares with
`cybed:partOf`, or `"(no framework)"`). Zero rows when the graph is
clean.

## See also

Other Graph invariants:
[`assert_graph_identity()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_identity.md),
[`assert_graph_invariants()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_invariants.md),
[`graph_invariant_counts()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_invariant_counts.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
graph_identity_violations(rdf)
} # }
```
