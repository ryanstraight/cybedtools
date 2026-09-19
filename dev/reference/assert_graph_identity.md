# Stop the build when an assembled graph fuses a unit with a statement

**\[stable\]**

Calls
[`graph_identity_violations()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_identity_violations.md)
and raises a classed condition when it returns any row. The message
names each affected framework, how many IRIs it contributes, and the
first few of them, so the offending framework is identifiable without
re-querying the graph.

The remedy is to declare a `unit_iri_prefix` for that framework in
`docs/framework-invariants.yml` and let the assembler mint its unit IRIs
with it. See
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md).

## Usage

``` r
assert_graph_identity(rdf, examples = 3L)
```

## Arguments

- rdf:

  An rdf object.

- examples:

  Integer, how many offending IRIs to name per framework.

## Value

Invisibly `TRUE` when the graph is clean.

## See also

Other Graph invariants:
[`assert_graph_invariants()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_invariants.md),
[`graph_identity_violations()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_identity_violations.md),
[`graph_invariant_counts()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_invariant_counts.md)

## Examples

``` r
if (FALSE) { # \dontrun{
assert_graph_identity(load_combined_ntriples_graph())
} # }
```
