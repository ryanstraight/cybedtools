# SPARQL query strategy

The queries operate against the unified RDF graph produced by
`scripts/030-load-rdf-graph.R` and, for query execution, the combined
N-Triples file produced by `scripts/025-export-ntriples.R`.

## Design choices

The package supports two kinds of question:

- **Within-framework questions** (such as “which task statements in NICE
  involve cloud or container technologies?”).
- **Across-framework questions** (such as “how do role and element
  counts vary by jurisdiction or sector?”).

The cybed: base vocabulary is the selection path for both. A single
helper call targeting `cybed:RoleElement` or `cybed:Role` returns
comparable bindings across NICE, DCWF, SFIA, ECSF, Cyber.org K-12, CSTA,
CSEC2017, and DigComp 2.2.

### What these queries surface

Three findings the package’s analytical layer produces directly from the
eight-framework graph:

- Element density per framework varies by 50x (NICE 51.5 elements per
  role, Cyber.org K-12 1.1).
- Jurisdictional element coverage is dominated by US frameworks 13 to 1
  (5,299 elements US vs. 395 EU).
- The five highest-element-load NICE work roles concentrate
  disproportionate competency specification (Security Control Assessment
  307, Secure Systems Development 232, Cybersecurity Architecture 219,
  Defensive Cybersecurity 206, Systems Security Management 204).

See the
[`cross-framework-analysis`](https://ryanstraight.github.io/cybedtools/articles/cross-framework-analysis.md)
vignette for the worked R that produces them.

### Why single-BGP queries with R-side joins

The `librdf` C library that `rdflib` wraps exhibits poor performance and
silent zero-row results on conjunctive triple patterns at this graph’s
scale. Multi-pattern SPARQL joins via shared variables hang for many
minutes. Multi-property selects on a single subject silently return no
rows. Single basic graph patterns (one triple match per SPARQL call)
execute fast and correctly.

The package’s discipline is therefore:

1.  SPARQL queries are single basic graph patterns. One triple match per
    call.
2.  Joins, multi-property assembly, and aggregation happen in R via
    dplyr.

This is implemented by the helpers in `R/sparql-helpers.R`:

- `sparql_pairs(rdf, predicate)` returns subject-object pairs for all
  triples with a given predicate.
- `sparql_subjects(rdf, predicate, object)` returns subjects of triples
  whose predicate and object are fixed.

Domain-level helpers compose these primitives:

- `framework_metadata(rdf)` returns a tibble of (framework, name,
  jurisdiction, sector, specificity).
- `role_framework_bindings(rdf)` returns (role, role_name, framework,
  framework_name).
- `element_framework_bindings(rdf)` returns (element, framework,
  framework_name).
- `role_element_bindings(rdf)` returns (role, element).

Each domain helper makes one to four single-BGP queries and joins the
results via dplyr left-joins or semi-joins.

## Query families

### Family A: Structural

- **A1. Framework metadata inventory.** One row per framework with
  jurisdiction, sector, specificity. Uses
  [`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md).
- **A2. Roles per framework and elements per framework.** Aggregated in
  R from
  [`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
  and
  [`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md).
- **A3. Element density.** Elements per role per framework, joining
  [`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md)
  with
  [`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md).
  Surfaces the structural-density spread (DCWF averages around 40
  elements per role, DigComp around 4 per area, Cyber.org K-12 near
  1:1).
- **A4. Missing required properties.** Quality control. Surface
  RoleElement subjects without `cybed:elementText` (use
  [`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)
  and dplyr `anti_join`).

### Family B: Cross-framework pivots

- **B1. Element volume by jurisdiction.** Join
  [`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md)
  to `framework_metadata()$jurisdiction` and aggregate.
- **B2. Element volume by sector.** Same shape, on
  `framework_metadata()$sector`.
- **B3. Element volume by specificity.** Same shape, on
  `framework_metadata()$specificity`.
- **B4. Framework-vs-framework structural comparison.** Filter
  [`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
  to two frameworks and compare role counts, element-per-role
  distributions.

The runner (`scripts/040-run-sparql.R`) implements six named analyses
(q10 through q15) that map onto these families and write one CSV per
analysis to `data/processed/query-results/`.

## Implementation notes

- The package’s analytical queries live in R, not in `.rq` files. The
  `inst/queries/` directory is reserved for user-supplied custom
  queries. See its `README.md`.
- Direct SPARQL access remains available via
  `rdflib::rdf_query(rdf, query_text)` for users who need it. Stick to
  single basic graph patterns for reliability.
- For aggregation, never use `COUNT`, `GROUP BY`, or `HAVING` in SPARQL.
  librdf’s SPARQL 1.1 aggregate support is unreliable. Aggregate in
  dplyr.
- A future release may add an Apache Jena Fuseki backend for full SPARQL
  1.1 support. This would relax the single-BGP discipline for users
  running against a Fuseki endpoint.
