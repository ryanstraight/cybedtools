# Pipeline scripts

Scripts under `scripts/` form the end-to-end ingestion and assembly pipeline. They are deliberately excluded from the R package build (`.Rbuildignore`) so that:

1. The R package itself remains lightweight and CRAN-installable.
2. Pipeline reproducibility is documented in source form for cloning users.
3. Framework source text is **never** bundled in this repository, regardless of upstream license.

## What this means for you

To run the pipeline locally, you need to:

1. Install the package and its dependencies (see top-level `README.md`).
2. Stage each framework's source file at `data/raw/<framework>/` (paths and required filenames are documented in each `010-ingest-<framework>.R` script header and in `docs/framework-data-sources.md`).
3. Run the scripts in order, or run `scripts/000-build.R` for the full pipeline.

## Framework licensing summary

Different upstream frameworks carry different licensing. Some permit redistribution, some do not, and several restrict commercial use. The repository never bundles upstream framework text. Per-framework details:

| Framework | License | Redistribution |
|---|---|---|
| NICE | US Government, public domain | safe |
| DCWF | US Government, public domain | safe |
| ECSF | CC BY 4.0 (typical for ENISA) | safe with attribution |
| SFIA | SFIA Foundation non-commercial free-use | structural metadata only via jankudev/sfia-tools; do not redistribute SFIA skill text |
| Cyber.org K-12 | CC BY-NC 4.0 | non-commercial only; do not include in commercial offerings |
| CSTA K-12 CS | CC BY-NC-SA 4.0 | non-commercial, share-alike |
| CSEC2017 | ACM/IEEE/AIS/IFIP, educational use | safe for educational development; analytical derivatives publishable with attribution |
| DigComp | EU open re-use | typically safe; verify specific terms |

Analytical derivatives (code frequencies, cross-framework mappings, structural comparisons) are generally publishable with attribution to the source framework, subject to the upstream license.

See `docs/framework-data-sources.md` for canonical source URLs and ingestion notes per framework.

## Script order

```
000-build.R                  # Master orchestrator
010-ingest-<framework>.R     # 8 scripts, one per framework
015-verify-ingestion.R       # Six-invariant verification rig
016-summarize-ingestion.R    # Generates docs/ingestion-summary.md
020-assemble-jsonld.R        # Builds JSON-LD from tidy CSVs
025-export-ntriples.R        # Derives N-Triples for SPARQL backend
030-load-rdf-graph.R         # RDF graph loaders (also exported via R/rdf-graph.R)
040-run-sparql.R             # SPARQL query runner
utils/jsonld-helpers.R       # Mirror of R/jsonld-helpers.R for script use
```

## Why duplicate `jsonld-helpers.R`?

The package's canonical helpers live in `R/jsonld-helpers.R` and are exported via `NAMESPACE`. A mirror copy at `scripts/utils/jsonld-helpers.R` lets the pipeline scripts source the helpers directly without requiring the package to be installed. Keep both copies in sync when modifying.
