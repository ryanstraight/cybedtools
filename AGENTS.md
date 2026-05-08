# AGENTS.md

Agentic-tool guidance for `cybedtools`. Conforms to the vendor-neutral
[agents.md](https://agents.md) convention. Read by Cursor, Claude Code,
OpenAI Codex, Aider, and similar tools. Web-fetching agents that follow
the `/llms.txt` convention should additionally pull
<https://ryanstraight.github.io/cybedtools/llms.txt> for the full
reference index.

## What this package is

R package providing a reproducible JSON-LD + SPARQL pipeline for
analyzing cybersecurity workforce competency frameworks (NICE, DCWF,
SFIA, ENISA ECSF) and pedagogical/learning-standards frameworks
(Cyber.org K-12, CSTA K-12 CS, ACM/IEEE CSEC2017, JRC DigComp 2.2). The
intellectual contribution is a framework-agnostic schema (`cybed:`) that
lets one query operate across heterogeneous frameworks. The
implementation enforces the schema and provides analytical helpers.

It does not propose a replacement framework or attempt to re-author
framework content. Existing frameworks retain their structure and
vocabulary. The package adds a comparison layer over them. Agents
generating example outputs from this package should not frame those
outputs as competing with or replacing NICE, SFIA, or any other upstream
framework.

## First thing to run (sanity check)

After install, one line confirms the package + its `librdf` system
dependency are functional:

``` r

library(cybedtools)
rdf <- make_demo_graph()
framework_metadata(rdf)
```

If
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md)
returns a 2-row tibble with US and EU jurisdictions, the install is
sound and you can move to real data. If it errors with an
`rdflib`/`librdf` message, the system library is missing. Linux:
`apt-get install librdf0-dev libraptor2-dev librasqal3-dev`. macOS:
`brew install librdf`. Windows: ships with the rdflib binary, no extra
step usually required.

## Setup

``` sh
# In the repo (clone, or already there):
Rscript -e "install.packages(c('devtools', 'roxygen2', 'pkgdown'))"
Rscript -e "devtools::install_deps('.', dependencies = TRUE)"
```

For real-data work, the framework source files do not ship with the
repo. Stage them under `data/raw/<slug>/` per
`docs/framework-data-sources.md`.

## Test, document, build

``` sh
# Run the test suite (53+ tests, ~7 seconds)
Rscript -e "devtools::test()"

# Regenerate man/ + NAMESPACE after roxygen comment changes
Rscript -e "roxygen2::roxygenise(roclets = c('rd', 'namespace'))"

# Build the source tarball
Rscript -e "pkgbuild::build('.', dest_path = '..')"

# Run R CMD check --as-cran on the built tarball
R CMD check --as-cran --no-manual ../cybedtools_*.tar.gz

# Build the pkgdown site (output -> _pkgdown_site/)
Rscript -e "pkgdown::build_site(new_process = FALSE, install = TRUE)"

# Spell-check
Rscript -e "devtools::spell_check()"
```

## Critical design constraint: single-BGP SPARQL discipline

The `librdf` C library that `rdflib` wraps has serious correctness AND
performance bugs on conjunctive triple patterns at this graph’s scale.

**Multi-pattern SPARQL queries**:

- Joins via shared variables (`?s P1 ?o1. ?s P2 ?o2`) hang for many
  minutes.
- Multi-property selects on a single subject silently return zero rows.

**Single basic graph patterns** (one triple match per query) execute
correctly in milliseconds.

The package’s design discipline is therefore:

1.  SPARQL queries are single basic graph patterns.
2.  Joins, multi-property assembly, and aggregation happen in R via
    dplyr.

This is implemented by `R/sparql-helpers.R`. The two primitives
(`sparql_pairs`, `sparql_subjects`) issue exactly one triple match; the
four domain helpers (`framework_metadata`, `role_framework_bindings`,
`element_framework_bindings`, `role_element_bindings`) compose multiple
single-BGP calls and join in R.

**If you, the agent, are asked to write a multi-pattern SPARQL query
against this package’s graphs: don’t. Decompose into single-BGP calls
and join in dplyr.** A future v0.2+ release may add an Apache Jena
Fuseki backend that lifts this constraint.

## Error handling

All package errors use
[`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html) with
classed conditions, so you can branch on class instead of regex-matching
messages:

| Class | Raised by |
|----|----|
| `cybedtools_unknown_prefix` | [`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md) on an unknown framework prefix |
| `cybedtools_file_not_found` | [`read_jsonld_document()`](https://ryanstraight.github.io/cybedtools/reference/read_jsonld_document.md), `load_combined_*_graph()` when missing |
| `cybedtools_framework_not_found` | [`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md) on an unknown slug |

Recovery pattern:

``` r

result <- tryCatch(
  load_combined_ntriples_graph(),
  cybedtools_file_not_found = function(cnd) {
    message("Run scripts/025-export-ntriples.R first.")
    NULL
  }
)
```

## Architecture pointers

Where to look for what:

- `R/jsonld-helpers.R`: JSON-LD constructors, `cybed:` namespace
  definitions, validation, file I/O.
- `R/sparql-helpers.R`: single-BGP primitives plus domain helpers. The
  query layer.
- `R/rdf-graph.R`: graph loaders for staged data (`load_*_graph`).
- `R/demo-graph.R`:
  [`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
  synthetic two-framework fixture for sanity checks.
- `R/cybedtools-package.R`:
  [`?cybedtools`](https://ryanstraight.github.io/cybedtools/reference/cybedtools-package.md)
  package-level help.
- `scripts/`: pipeline scripts (excluded from the package build via
  `.Rbuildignore`). Run from a clone, not from an installed package.
  `scripts/000-build.R` orchestrates everything.
- `tests/testthat/helper-fixture-graph.R`: synthetic graph encoding the
  structural invariants the SPARQL helpers must satisfy. Read this when
  adding helpers, then mirror the pattern.
- `vignettes/articles/namespace-architecture.Rmd`: two-tier `cybed:`
  schema design (rendered as a pkgdown article).
- `docs/framework-data-sources.md`: per-framework source URLs,
  licensing, staging path.
- `docs/framework-invariants.yml`: declared count bounds per framework
  (used by `scripts/015-verify-ingestion.R`).
- `vignettes/articles/data-integrity.Rmd`: the six-invariant
  verification contract (rendered as a pkgdown article).
- `vignettes/articles/sparql-strategy.Rmd`: single-BGP SPARQL query
  strategy and why R-side joins are required (rendered as a pkgdown
  article).
- `vignettes/getting-started.Rmd`: user-facing introduction.
- `vignettes/cross-framework-analysis.Rmd`: worked analytical examples
  plus librdf gotchas.
- `vignettes/adding-a-framework.Rmd`: six-step extension guide.

## Common tasks

### Run an analytical query against a staged graph

``` r

library(cybedtools); library(dplyr)
rdf <- load_combined_ntriples_graph()  # needs scripts/025-export-ntriples.R run first
framework_metadata(rdf) |> arrange(jurisdiction, name)
```

### Add a new framework

Six steps. Full walkthrough in `vignettes/adding-a-framework.Rmd`.
Summary:

1.  Pick a slug (filesystem) and prefix (JSON-LD namespace). Add the
    prefix to `cybed_namespaces` and `valid_framework_prefixes` in
    `R/jsonld-helpers.R`.
2.  Stage the source under `data/raw/<slug>/` and write
    `scripts/010-ingest-<slug>.R` producing tidy CSVs and
    `provenance.yml`.
3.  Add an entry to `docs/framework-invariants.yml` with expected role
    and element count bounds.
4.  Add verification field mappings in `scripts/015-verify-ingestion.R`.
5.  Add a JSON-LD assembly adapter in `scripts/020-assemble-jsonld.R`.
6.  Run `scripts/000-build.R`. Existing SPARQL queries automatically
    include the new framework because they target framework-agnostic
    types (`cybed:Framework`, `cybed:OrganizingUnit`,
    `cybed:RoleElement`). Queries that target the workforce-restricted
    `cybed:Role` subtype pick up the new framework only when
    [`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
    was used (workforce-shaped frameworks).

### Construct a JSON-LD document by hand

``` r

library(cybedtools)

fw <- build_framework_node(
  framework_id     = "demo-v1",
  framework_name   = "Demo",
  framework_prefix = "nice",
  version          = "1.0.0",
  publisher        = "Demo Publisher",
  jurisdiction     = "US",
  sector           = "civilian",
  specificity      = "cybersecurity-specific"
)
role <- build_role_node(
  role_id              = "DEMO-001",
  role_name            = "Demo Role",
  framework_prefix     = "nice",
  framework_role_type  = "WorkRole",
  framework_id         = "demo-v1"
)
doc <- assemble_framework_document(fw, list(role), list(), "nice")
write_jsonld_document(doc, tempfile(fileext = ".jsonld"))
```

### Add a new SPARQL helper

Mirror the existing pattern in `R/sparql-helpers.R`:

1.  Compose 1-N single-BGP calls via
    [`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md)
    /
    [`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md).
2.  Join with
    [`dplyr::left_join`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
    /
    [`dplyr::inner_join`](https://dplyr.tidyverse.org/reference/mutate-joins.html)
    /
    [`dplyr::semi_join`](https://dplyr.tidyverse.org/reference/filter-joins.html).
3.  Handle the empty-graph case: the primitives return zero-row tibbles
    with the correct columns even when the graph is empty.
4.  Add tests against `tests/testthat/helper-fixture-graph.R` covering
    happy path + edge cases (orphan elements, duplicate triples, empty
    graph).
5.  Re-document and re-test:
    `Rscript -e "roxygen2::roxygenise(); devtools::test()"`.

## Code conventions

- Native R pipes (`|>`). No magrittr `%>%` in package code.
- [`here::here()`](https://here.r-lib.org/reference/here.html) for paths
  in scripts. Avoid hardcoded paths.
- Roxygen markdown (`Roxygen: list(markdown = TRUE)` in DESCRIPTION).
- `@family` tags group related functions in pkgdown reference.
- `@lifecycle` badges via `r lifecycle::badge("stable")`.
- All exported functions have `@examples`. Runnable when feasible,
  otherwise `\dontrun{}` with a comment explaining why.
- Errors via
  [`rlang::abort()`](https://rlang.r-lib.org/reference/abort.html) with
  bullet body and classed condition. See existing `cybedtools_*`
  classes.

## Spelling

`devtools::spell_check()` should report 0 issues. Add new domain
vocabulary to `inst/WORDLIST` rather than rewording. Reference dialect
is en-US (DESCRIPTION `Language: en-US`). The package text uses American
English throughout. Framework names that originate with their publishers
(e.g., “European Commission Joint Research Centre”) retain the
publisher’s spelling.

## Licensing for data redistribution

The package code is MIT. Framework source text is **not** redistributed
in the repo because licenses differ per framework (SFIA Use Policy,
Cyber.org K-12 CC BY-NC, CSTA CC BY-NC-SA, etc.). If you are an agent
generating example outputs from staged framework data, derivative
analytical outputs (counts, mappings, structural comparisons) are
generally publishable with attribution. Raw source-text excerpts may not
be.

## What this package is NOT

- It is not a general-purpose SPARQL endpoint. It enforces a single-BGP
  discipline because of librdf limitations.
- It does not bundle framework source data. Users stage it themselves.
- It does not (currently) implement any posthumanist analytical overlay.
  That overlay was deliberately deferred to a separate downstream
  package (`cybedposthuman`) so this package stays focused on framework
  representation and querying.

## When in doubt

Read `vignettes/getting-started.Rmd`, then
`vignettes/cross-framework-analysis.Rmd` for the librdf gotchas section.
For the full structured reference, fetch
<https://ryanstraight.github.io/cybedtools/llms.txt>.
