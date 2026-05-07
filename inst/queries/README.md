# SPARQL Queries

This directory ships with the package and is reserved for user-supplied SPARQL queries. The package's own analytical queries live in R, not here. See `R/sparql-helpers.R` for the helper functions (`framework_metadata()`, `role_framework_bindings()`, `element_framework_bindings()`, `role_element_bindings()`) that compose into the analytical results written by `scripts/040-run-sparql.R`.

## Why aren't there .rq files for the package's named analyses?

The `librdf` backend that `rdflib` wraps exhibits poor performance and silent zero-row results on conjunctive triple patterns at this graph's scale. Multi-pattern joins via shared variables hang for many minutes. Multi-property selects on a single subject silently return no rows. Single basic graph patterns (one triple match per SPARQL call) execute fast and correctly.

The package's design discipline is therefore:

1. SPARQL queries are single basic graph patterns: one triple match, no joins.
2. Joins, multi-property assembly, and aggregation happen in R via dplyr.

This discipline is implemented by the helpers in `R/sparql-helpers.R`. The runner (`scripts/040-run-sparql.R`) calls those helpers and writes the analytical CSVs to `data/processed/query-results/`.

## Conventions for user-supplied queries

If you place your own `.rq` files in this directory, follow the single-BGP discipline:

- Filename: `q<NN>-<short-slug>.rq` (e.g., `q20-my-custom-query.rq`).
- Body: one triple pattern (one `?subject <predicate> ?object` line inside a single `WHERE { ... }`).
- Use the `sparql_pairs()` or `sparql_subjects()` primitives from `R/sparql-helpers.R` to invoke from R, then aggregate or join in dplyr.

Example:

```sparql
PREFIX cybed: <https://w3id.org/cybed/ontology#>

SELECT ?role ?framework
WHERE {
  ?role cybed:partOf ?framework .
}
```

```r
library(cybedtools)
rdf <- load_combined_ntriples_graph()
pairs <- sparql_pairs(rdf, "cybed:partOf")
# Then join, filter, aggregate in dplyr.
```

## See also

- `R/sparql-helpers.R`, the helper functions implementing the single-BGP discipline.
- The `sparql-strategy` pkgdown article, for the overall query strategy.
- The `namespace-architecture` pkgdown article, for the namespace structure the queries assume.
- `vignettes/cross-framework-analysis.Rmd`, worked examples.
