# Measure the counts that `graph_invariants` declares

**\[stable\]**

Computes, from an assembled graph, every quantity the `graph_invariants`
block of `docs/framework-invariants.yml` declares a band for: the
combined totals, and the per-framework element split into parents,
sub-points and examples. The strict-inflation ratio is derived here
rather than declared, so the file and the graph cannot disagree about
how it is computed.

## Usage

``` r
graph_invariant_counts(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `scope` (`"combined"` or a framework's local
name), `measure` and `value`.

## See also

Other Graph invariants:
[`assert_graph_identity()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_identity.md),
[`assert_graph_invariants()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_invariants.md),
[`graph_identity_violations()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_identity_violations.md)

## Examples

``` r
if (FALSE) { # \dontrun{
graph_invariant_counts(load_combined_ntriples_graph())
} # }
```
