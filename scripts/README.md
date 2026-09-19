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
026-verify-graph.R           # Graph-level gate: identity + declared counts
030-export-release.R         # Builds the public per-framework data release
040-run-sparql.R             # SPARQL query runner
_ingest-common.R             # Shared helpers for the ingesters
_release-common.R            # Pure helpers for the release export
utils/jsonld-helpers.R       # Mirror of R/jsonld-helpers.R for script use
```

## The graph gate

`015-verify-ingestion.R` runs over the staged CSVs, before any IRI exists, so there are two things it cannot check. `026-verify-graph.R` runs over the assembled graph and checks both, with no soft flags.

The first is identity. No IRI may be typed both `cybed:OrganizingUnit` and `cybed:RoleElement`, and no `cybed:hasElement` triple may point at its own subject. Both mean a framework numbered its units and its statements out of one id space and two different things fused into one node. The remedy is a `unit_iri_prefix` for that framework in `docs/framework-invariants.yml`; there is no exemption list.

The second is the `graph_invariants` block of `docs/framework-invariants.yml`, which declares what the assembled graph should hold per framework and in total. Those are outputs of the pipeline, so no earlier stage can enforce them. A measured value outside its declared band is a human-review event: find out what moved before editing the number.

`030-export-release.R` re-runs both checks itself before it writes anything, because a directory of N-Triples files does not record whether a stage ran over it, and a release cannot be withdrawn.

## The public data release

`030-export-release.R` writes one gzip-compressed N-Triples file per framework into `data/processed/release/<version>/`, alongside a `manifest.json` and a `README.md` generated from the same data. There is never a combined public file: the frameworks carry different licences, one of them is share-alike, and merging them would propagate obligations across publishers who never agreed to them.

Two independent gates decide what is written, and both fail closed. The redistribution policy comes from `public_redistribution` in `docs/framework-invariants.yml`, read through the same table `concordance/_publication-guard.R` declares; `local_only` is never written in any form. The release allowlist lives in `docs/data-release.yml` and names the frameworks a given release ships, so a framework the policy would permit still gets no file until it is listed. A slug on the allowlist whose policy is `local_only` stops the export rather than being skipped.

A framework whose policy is `structure_only` ships with every `cybed:elementText` and `schema:description` triple removed. Names, titles, categories, levels, section headings and mappings stay. After the filter a backstop refuses to write the file if any surviving literal outside an allow-listed predicate exceeds the bound in the config.

A third gate acts inside a file rather than on the file as a whole. The `exclusions` list in `docs/data-release.yml` names parts of a framework that ship with the rest of it withheld. The one kind implemented, `unit_element_links`, drops every unit-to-element link whose unit side is one of the named units, and then drops the elements those links were the only route to, together with the sub-points and examples that elaborate them. Units are matched on the exact local part of their IRI, never on a name. The unit nodes stay, with their identifiers, types, names and framework membership, so a reader can see that a unit exists and that its mappings are absent. An element any other unit also draws on stays intact with all of its other links. The gate fails closed in three places: a unit id that resolves to nothing stops the export, an exclusion naming a framework off the allowlist stops the export, and after the cut the stage asserts that no excluded unit still links to an element. A file carrying an exclusion is scoped `full_with_exclusions`, its manifest entry records the units, the reason and the counts dropped, and the generated release README says in plain sentences what is missing and why. The partition reconciliation runs before any exclusion, on the whole graph; a second check ties each file's pre-exclusion count to its shipped count and the triples dropped.

Which predicates carry a unit-to-element link is declared in `unit_element_link_predicates()`, along with which end of the triple holds the unit. The side is declared rather than inferred because some frameworks mint one IRI per source identifier and reuse an identifier for a unit and for a statement, so the same IRI can be a unit in one triple and an element in another. In DCWF v5.1, 33 of the 74 work-role IRIs are also task or KSA IRIs. Matching an excluded unit on whichever end it appears would drop other units' mappings to those statements, which is a cut no exclusion asked for.

Files are byte-reproducible: lines are sorted bytewise in the C locale regardless of the session's collation, duplicates are dropped, line endings are LF with one trailing newline, and the gzip header is written with a zeroed modification time, no original filename and an unknown operating-system byte. Two runs from the same input produce the same hashes. Pass `--out-dir=<directory>` to write a release elsewhere and compare.

`data/processed/` is gitignored, so nothing this stage writes is committed.

## Why duplicate `jsonld-helpers.R`?

The package's canonical helpers live in `R/jsonld-helpers.R` and are exported via `NAMESPACE`. A mirror copy at `scripts/utils/jsonld-helpers.R` lets the pipeline scripts source the helpers directly without requiring the package to be installed. Keep both copies in sync when modifying.
