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
helper call targeting `cybed:OrganizingUnit` returns comparable
parent-level bindings across NICE, DCWF, SFIA, ECSF, Cyber.org K-12,
CSTA, CSEC2017, and DigComp 2.2; targeting `cybed:Role` restricts to the
workforce-framework subset (NICE / DCWF / ECSF); targeting
`cybed:RoleElement` returns atomic content nodes (parents, Subpoints,
and Examples).

### What these queries surface

Three findings the package’s analytical layer produces directly from the
eight-framework graph:

- Element density per framework varies by ~12x with Cyber.org K-12 /
  CSTA pedagogical Examples included (NICE 51.6 elements per work role,
  DigComp 4.2 per competence area). Without Examples the spread widens
  to ~49x because Cyber.org K-12’s 116 cells contain only 123 numbered
  standards. Per-unit density is a comparison aid across heterogeneous
  denominators, not a quality claim.
- Jurisdictional element coverage is dominated by US frameworks (NICE,
  DCWF, Cyber.org K-12, CSTA) by an order of magnitude over EU
  frameworks (ECSF, DigComp), reflecting design-philosophy differences
  (ECSF profile-level by intent, DigComp citizen-self-assessment by
  intent) rather than corpus completeness.
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
- `organizing_unit_framework_bindings(rdf)` returns (unit, unit_name,
  framework, framework_name) for every framework’s top-level enumerated
  unit. The cross-framework cut.
- `role_framework_bindings(rdf)` returns (role, role_name, framework,
  framework_name) restricted to workforce frameworks where `cybed:Role`
  is asserted (NICE / DCWF / ECSF).
- `element_framework_bindings(rdf)` returns (element, framework,
  framework_name) for every `cybed:RoleElement`, including Subpoints and
  Examples.
- `example_framework_bindings(rdf)` returns (example, framework,
  framework_name) for the `cybed:Example` subset (Cyber.org K-12 and
  CSTA Clarification scaffolding).
- `role_element_bindings(rdf)` returns (role, element) for every
  `cybed:hasElement` triple. Excludes Examples (which are reachable only
  via `cybed:hasExample`).

Each domain helper makes one to four single-BGP queries and joins the
results via dplyr left-joins or semi-joins.

## Query families

### Family A: Structural

- **A1. Framework metadata inventory.** One row per framework with
  jurisdiction, sector, specificity. Uses
  [`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md).
- **A2. Organizing units per framework and elements per framework.**
  Aggregated in R from
  [`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
  and
  [`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md).
  For workforce-restricted aggregations, swap in
  [`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md).
- **A3. Element density.** Elements per top-level unit per framework,
  joining
  [`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md)
  with
  [`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md).
  Surfaces the cross-framework structural-density spread (with-examples
  count): NICE around 51.6 per work role, DCWF around 39.8 per work
  role, ECSF around 32.5 per role profile, CSTA around 10.2 per
  level-x-concept cell, SFIA around 5.6 per skill, CSEC2017 around 5.0
  per Knowledge Area, Cyber.org K-12 around 4.3 per
  grade-band-x-sub-concept cell, DigComp around 4.2 per competence area.
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
