# Check an assembled graph against the declared `graph_invariants` bands

**\[stable\]**

Compares
[`graph_invariant_counts()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_invariant_counts.md)
against the bands declared in the `graph_invariants` block of
`docs/framework-invariants.yml`. Each band is a pair of inclusive
bounds; a pair with two equal bounds is an exact value. A measured
quantity outside its band raises a classed condition naming every
disagreement.

Bands are the file's claim about the pipeline's output. A value that
leaves its band is a human-review event: something upstream moved, and
the right response is to find out what before editing the number.

## Usage

``` r
assert_graph_invariants(rdf, invariants_path = NULL, declared = NULL)
```

## Arguments

- rdf:

  An rdf object.

- invariants_path:

  Character path to the invariants file. Defaults to
  `docs/framework-invariants.yml` in the source checkout.

- declared:

  Optional pre-read `graph_invariants` list, used in place of reading
  the file. Mainly for tests.

## Value

Invisibly, the tibble of measured counts.

## See also

Other Graph invariants:
[`assert_graph_identity()`](https://ryanstraight.github.io/cybedtools/dev/reference/assert_graph_identity.md),
[`graph_identity_violations()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_identity_violations.md),
[`graph_invariant_counts()`](https://ryanstraight.github.io/cybedtools/dev/reference/graph_invariant_counts.md)

## Examples

``` r
if (FALSE) { # \dontrun{
assert_graph_invariants(load_combined_ntriples_graph())
} # }
```
