# Getting Started with cybedtools

## What cybedtools does

Eight cybersecurity workforce and learning frameworks (NICE, DCWF, SFIA,
ENISA ECSF, Cyber.org K-12, CSTA K-12 CS, ACM/IEEE CSEC2017, DigComp
2.2) expressed in a shared `cybed:` semantic schema. The package adds a
comparison layer over existing frameworks, not a replacement for them.

This vignette walks through the two ways to use it: install the package
and run helpers against the small built-in demo graph, or clone the
repository and run the full pipeline against staged framework sources.

Three semantic abstractions carry the work:

- **`cybed:Framework`**: a competency or learning framework.
- **`cybed:Role`**: the framework’s top-level organizing unit (work
  role, role profile, skill, grade-band concept cluster, knowledge
  area).
- **`cybed:RoleElement`**: the codable atomic statement attached to a
  Role (task, knowledge statement, skill statement, standard, learning
  outcome).

A single SPARQL query targeting `cybed:RoleElement` returns elements
across every framework in one pass.

## Installation

``` r

# Install from GitHub (not yet on CRAN)
# install.packages("remotes")
remotes::install_github("ryanstraight/cybedtools")
```

The package depends on `rdflib` for RDF/SPARQL, `jsonlite` for JSON-LD
I/O, and a small subset of the tidyverse (`dplyr`, `purrr`, `tibble`).

## Pipeline overview

The pipeline turns staged framework source files into a queryable RDF
graph through five scripts. Each stage produces an artifact the next
stage reads:

``` mermaid
flowchart TD
  src["Framework source files<br>NICE CPRT, DCWF XLSX, SFIA SQLite, ECSF JSON, ..."]
  ingest["010-ingest-*.R"]
  csv["Per-framework CSVs<br>+ provenance.yml"]
  verify["015-verify-ingestion.R<br>six invariants"]
  assemble["020-assemble-jsonld.R"]
  jsonld["JSON-LD<br>per-framework + combined"]
  ntriples["025-export-ntriples.R"]
  combined["_combined.nt"]
  rdf["rdflib graph<br>load_combined_ntriples_graph"]
  helpers["sparql_pairs, sparql_subjects<br>+ domain helpers"]
  tibbles["Tibbles<br>dplyr-friendly"]

  src --> ingest --> csv --> verify --> assemble --> jsonld --> ntriples --> combined --> rdf --> helpers --> tibbles

  classDef stage fill:#0F172A,stroke:#38BDF8,color:#E0F2FE,stroke-width:2px
  classDef artifact fill:#F8FAFC,stroke:#0F172A,color:#0F172A
  class ingest,verify,assemble,ntriples,helpers stage
  class src,csv,jsonld,combined,rdf,tibbles artifact
```

The next sections walk through each stage.

## Ingesting a framework

Each framework has a dedicated ingestion script under `scripts/` in the
repository. After installing the package, fetch the framework source
data (see `docs/framework-data-sources.md` for per-framework notes on
where to obtain each) and run the matching ingestion script.

For example, to ingest the NICE Framework:

``` bash
# Copy the NIST CPRT JSON to data/raw/nice/
cp ~/Downloads/nice-v2-framework.json data/raw/nice/

# Run the ingestion
Rscript scripts/010-ingest-nice.R
```

The script parses the source, writes tidy CSVs to
`data/raw/nice/tables/`, and generates a `data/raw/nice/provenance.yml`
manifest with SHA256, retrieval date, and licensing info.

## Verifying data integrity

Before any downstream analysis, verify the ingested data against
declared invariants:

``` bash
Rscript scripts/015-verify-ingestion.R
```

The verifier checks six invariant layers: source provenance (SHA256
match), extraction count bounds, referential integrity, text-integrity
(UTF-8 validity, non-empty, length sanity), ID uniqueness, and audit
trail. Hard failures block downstream scripts. Soft flags warn but allow
continuation.

``` r

# Typical output
# Summary: 95 pass, 0 soft flags, 0 HARD FAILURES.
# VERIFICATION PASSED (with 0 soft flags for review).
```

## Assembling JSON-LD

Once the frameworks are ingested and verified, assemble the semantic
representation:

``` bash
Rscript scripts/020-assemble-jsonld.R
```

This produces:

- One JSON-LD document per framework:
  `data/processed/jsonld/<framework>.jsonld`
- A combined multi-framework graph:
  `data/processed/jsonld/_combined.jsonld`

Each document uses the two-tier namespace architecture:

- **Tier 1 (`cybed:`):** framework-agnostic base vocabulary.
- **Tier 2 (per-framework: `nice:`, `sfia:`, `dcwf:`, etc.):**
  per-framework subclasses of Tier 1 types.

## Running the analytical queries

The package’s six named analyses are implemented in R, not as `.rq`
files. They use single-BGP SPARQL primitives
([`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md))
composed via dplyr. See the `cross-framework-analysis` vignette for the
full design rationale and the helper functions exposed.

Run all six against the combined graph:

``` bash
Rscript scripts/040-run-sparql.R
```

Each analysis writes one CSV to `data/processed/query-results/`:

- `q10-roles-per-framework.csv`, role count per framework.
- `q11-elements-per-framework.csv`, element count per framework.
- `q12-framework-metadata.csv`, jurisdiction, sector, specificity per
  framework.
- `q13-elements-by-jurisdiction.csv`, element count per jurisdiction.
- `q14-elements-by-sector.csv`, element count per sector.
- `q15-largest-roles.csv`, top 20 roles by element count.

A `_run-summary.csv` records row counts and timings.

Direct SPARQL access remains available via
[`rdflib::rdf_query()`](https://docs.ropensci.org/rdflib/reference/rdf_query.html)
for ad-hoc queries. Stick to single basic graph patterns (one triple
match per query) and join in dplyr.

## Try it without staging any data

If you just installed the package and want to confirm it works before
staging real framework sources,
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
returns a small in-memory two-framework graph that exercises every
domain helper:

``` r

library(cybedtools)
library(dplyr)

# Synthetic two-framework graph; works without staging any framework data.
rdf <- make_demo_graph()

# One row per framework with jurisdiction, sector, and specificity attached.
framework_metadata(rdf) |>
  arrange(jurisdiction, name)
#> # A tibble: 2 × 5
#>   framework                                name  jurisdiction sector specificity
#>   <chr>                                    <chr> <chr>        <chr>  <chr>      
#> 1 https://w3id.org/cybed/ontology#framewo… Demo… EU           gener… general-IT 
#> 2 https://w3id.org/cybed/ontology#framewo… Demo… US           civil… cybersecur…
```

``` r

# Count how many roles each framework declares.
role_framework_bindings(rdf) |>
  count(framework_name, name = "role_count")
#> # A tibble: 2 × 2
#>   framework_name   role_count
#>   <chr>                 <int>
#> 1 Demo Framework A          2
#> 2 Demo Framework B          1
```

This is enough to verify your `librdf` system library is functional and
the SPARQL helpers compose correctly on your machine. It is not a
substitute for real framework data. For cross-framework analysis use
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md)
against a graph you assembled from staged sources.

## A minimal end-to-end example with real data

``` r

library(cybedtools)
library(dplyr)

# 1. Load the assembled combined graph. N-Triples is the recommended backend
#    (parses fast, executes the package's single-BGP queries correctly).
rdf <- load_combined_ntriples_graph()

# 2. Get framework metadata via the domain helper. Internally this issues
#    several single-BGP queries and joins them in dplyr. See
#    R/sparql-helpers.R and the cross-framework-analysis vignette for
#    why the package avoids multi-pattern SPARQL on this graph.
results <- framework_metadata(rdf) |>
  arrange(jurisdiction, name)

# 3. Inspect the result. One row per framework, columns for name,
#    jurisdiction, sector, specificity. This metadata frame is the
#    foundation for every cross-framework pivot the package supports.
print(results)
```

This returns one row per framework with jurisdiction, sector, and
specificity, the metadata foundation for cross-framework pivots.

## Next steps

- See the vignette **“Cross-framework analysis”** for worked examples of
  structural and analytical queries across frameworks.
- See the vignette **“Adding a new framework”** for how to extend the
  package with a framework beyond the current eight.
- See the
  [namespace-architecture](https://ryanstraight.github.io/cybedtools/articles/namespace-architecture.md)
  article for the two-tier schema design.
- See the
  [data-integrity](https://ryanstraight.github.io/cybedtools/articles/data-integrity.md)
  article for the verification contract.
- See the
  [sparql-strategy](https://ryanstraight.github.io/cybedtools/articles/sparql-strategy.md)
  article for query design rationale.

## License

The package code is MIT-licensed. Framework content staged in
`data/raw/` retains its upstream license per framework. The package does
not redistribute framework text. See `LICENSE.md` for the layered
licensing structure.
