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
010-ingest-<framework>.R     # 11 scripts, one per framework
015-verify-ingestion.R       # Six-invariant verification rig
016-summarize-ingestion.R    # Generates docs/ingestion-summary.md
020-assemble-jsonld.R        # Builds JSON-LD from tidy CSVs
025-export-ntriples.R        # Derives N-Triples for SPARQL backend
030-export-release.R         # Builds the public per-framework data release
040-run-sparql.R             # SPARQL query runner
_ingest-common.R             # Shared helpers for the ingesters
_release-common.R            # Pure helpers for the release export
utils/jsonld-helpers.R       # Mirror of R/jsonld-helpers.R for script use
```

## The public data release

`030-export-release.R` writes one gzip-compressed N-Triples file per framework into `data/processed/release/<version>/`, alongside a `manifest.json` and a `README.md` generated from the same data. There is never a combined public file: the frameworks carry different licences, one of them is share-alike, and merging them would propagate obligations across publishers who never agreed to them.

Two independent gates decide what is written, and both fail closed. The redistribution policy comes from `public_redistribution` in `docs/framework-invariants.yml`, read through the same table `concordance/_publication-guard.R` declares; `local_only` is never written in any form. The release allowlist lives in `docs/data-release.yml` and names the frameworks a given release ships, so a framework the policy would permit still gets no file until it is listed. A slug on the allowlist whose policy is `local_only` stops the export rather than being skipped.

A framework whose policy is `structure_only` ships with every `cybed:elementText` and `schema:description` triple removed. Names, titles, categories, levels, section headings and mappings stay. After the filter a backstop refuses to write the file if any surviving literal outside an allow-listed predicate exceeds the bound in the config.

Files are byte-reproducible: lines are sorted bytewise in the C locale regardless of the session's collation, duplicates are dropped, line endings are LF with one trailing newline, and the gzip header is written with a zeroed modification time, no original filename and an unknown operating-system byte. Two runs from the same input produce the same hashes. Pass `--out-dir=<directory>` to write a release elsewhere and compare.

`data/processed/` is gitignored, so nothing this stage writes is committed.

## Why duplicate `jsonld-helpers.R`?

The package's canonical helpers live in `R/jsonld-helpers.R` and are exported via `NAMESPACE`. A mirror copy at `scripts/utils/jsonld-helpers.R` lets the pipeline scripts source the helpers directly without requiring the package to be installed. Keep both copies in sync when modifying.
