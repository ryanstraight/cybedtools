# Framework Data Sources

Where to obtain each in-scope framework, how to stage it for cybedtools, and which ingestion script processes it. Licensing and redistribution constraints vary by framework; each section flags the relevant terms.

This repository **does not bundle upstream framework source text**. Each ingestion script reads from `data/raw/<slug>/`, where the user has placed the publisher's source artifact. The script then writes tidy CSVs and a `provenance.yml` manifest (SHA256, retrieval date, license).

## Supported framework versions (cybedtools 0.1.0)

| Framework        | Version supported            | Released   | Format              |
|------------------|------------------------------|------------|---------------------|
| NICE             | v2 (NIST SP 800-181 Rev 1)   | 2024       | JSON (CPRT)         |
| DCWF             | v5.1                         | 2025-07-25 | XLSX                |
| ECSF             | v1                           | 2022-09-19 | JSON                |
| SFIA             | 9                            | 2024-10    | SQLite (extract)    |
| Cyber.org K-12   | v1.0                         | 2021-09-09 | PDF                 |
| CSTA K-12 CS     | Revised 2017                 | 2017       | XLSX                |
| ACM/IEEE CSEC    | 2017 v1.0                    | 2017-12-31 | PDF                 |
| DigComp          | 2.2                          | 2022-03-17 | PDF                 |

`NEWS.md` records which framework versions a given cybedtools release supports; this table tracks the current release.

## How version updates are handled

Each ingestion script targets a specific upstream schema. When a publisher releases a new version:

- **Minor revisions** (count drift, cosmetic changes) usually pass through the same parser. Verification surfaces the drift via the count-band tolerances declared in `docs/framework-invariants.yml`. The ingestion run completes with a soft-flag warning rather than failing silently. Human review updates the bounds when the new counts are known to be correct.
- **Major schema changes** (column renames, restructured JSON, new identifier formats) cause the parser to fail with a hard error. The pipeline stops and the user knows the script needs an update for the new version. A subsequent cybedtools release ships the updated parser.
- **Multiple versions side-by-side.** The staging directory is per-framework, not per-version. You can keep `nice-v2-framework.json` and `nice-v2.2-framework.json` in the same `data/raw/nice/` folder. The ingestion script reads the version-named file the current cybedtools release expects.

If you need a newer upstream version that the current cybedtools release does not yet support, open an issue at <https://github.com/ryanstraight/cybedtools/issues> with a sample of the new schema. Schema-revision PRs are welcome.

Active publisher revisions to watch (as of cybedtools 0.1.0): NICE Framework v2.2.0 components have shipped via NIST CPRT, CSTA's first major revision since 2017 is anticipated summer 2026, SFIA 10 is in consultation, and DigComp 3.0 has been released.

## NICE (US, NIST)

**Source.** <https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center>. Navigate to "Current Versions" and download the framework as JSON via the NIST Cybersecurity and Privacy Reference Tool (CPRT).

**License.** US Government work, public domain.

**Stage.** Save the downloaded JSON as `data/raw/nice/nice-v2-framework.json` (rename if the publisher's filename differs).

**Ingest.** `Rscript scripts/010-ingest-nice.R`

**Notes.** Targets the v2 (NIST SP 800-181 Rev 1) CPRT JSON schema. v2 consolidated to 41 work roles with 2,111 unique TKS elements (down from v1's 52 work roles).

## DCWF (US, DoD)

**Source.** <https://dodcio.defense.gov/Cyber-Workforce/DCWF/>. The DoD CIO Work Role Tool publishes the framework as XLSX, with a download link from the DCWF program page.

**License.** US Government work, public domain. Some DoD publications carry distribution statements; verify the artifact you download.

**Stage.** Save the downloaded XLSX as `data/raw/dcwf/dcwf-work-role-tool-v5.1.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-dcwf.R`

**Notes.** v5.1 added DA-series data and AI work roles, bringing the total to 74. DCWF is NICE-aligned and shares mapped identifiers with NICE work roles. The XLSX has multiple sheets; the parser uses readxl.

## ECSF (EU, ENISA)

**Source.** <https://www.enisa.europa.eu/topics/skills-and-competences/skills-development/european-cybersecurity-skills-framework>. ENISA distributes the European Cybersecurity Skills Framework as a PDF report with companion JSON and XLSX files.

**License.** Typically CC BY 4.0 for ENISA publications; verify the specific artifact.

**Stage.** Save the JSON as `data/raw/ecsf/ECSF_v1.json` and the companion XLSX as `data/raw/ecsf/ECSF.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-ecsf.R`

**Notes.** ECSF v1 was published 2022-09-19 with revisions through 2024-08-02. 12 role profiles with embedded e-CF 4.0 cross-references.

## SFIA (UK, global)

**Source.** <https://sfia-online.org/en>, the canonical SFIA Foundation site. SFIA 9 is downloadable in PDF, XLSX, JSON, and RDF formats; access is free for individuals and small employers under SFIA's Use Policy. The cybedtools ingestion script does not read SFIA's published files directly; it reads a third-party structural extract. See "Notes" below.

**License.** Licensed by the SFIA Foundation. Non-commercial research and educational use is permitted under SFIA's Use Policy. Redistribution of full SFIA-copyrighted text is restricted.

**Stage.** Save the SQLite database as `data/raw/sfia/sfia-sqlite.db`.

**Ingest.** `Rscript scripts/010-ingest-sfia.R`

**Notes.** The structural extract used is [jankudev/sfia-tools](https://github.com/jankudev/sfia-tools), release v0.0.1 (2025-02-05), which packages SFIA 9 as a SQLite database of framework structure (skill IDs, levels, attributes, relationships). Full skill descriptions are not bundled by jankudev. If your analysis needs the full skill text, retrieve it from sfia-online.org under the non-commercial provision and do not commit it to the repository. SFIA 10 is in consultation and not yet supported.

## Cyber.org K-12 (US, K-12 cybersecurity learning standards)

**Source.** <https://cyber.org/standards>. CYBER.ORG and the Cyber Innovation Center publish the K-12 Cybersecurity Learning Standards as a PDF.

**License.** CC BY-NC 4.0 (attribution, non-commercial).

**Stage.** Save the PDF as `data/raw/cyberorg-k12/K-12-Cybersecurity-Learning-Standards-v1.0.pdf`.

**Ingest.** `Rscript scripts/010-ingest-cyberorg-k12.R`

**Notes.** Best-effort PDF extraction via a markitdown intermediate. Standard ID format is `{grade_band}.{theme}.{sub_code}[.{sequence}]` (e.g., `K-2.SEC.ACC`, `9-12.DC.PPI.2`). The pipeline produces 123 standards across four grade bands (K-2, 3-5, 6-8, 9-12) and 29 sub-concepts.

## CSTA K-12 CS (US, K-12 computer science standards)

**Source.** <https://csteachers.org/k12standards/>. The Computer Science Teachers Association distributes the standards as a downloadable XLSX from the K-12 Standards page.

**License.** CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike).

**Stage.** Save the XLSX as `data/raw/csta/csta-k-12-standards-revised-2017.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-csta.R`

**Notes.** Single sheet, nine columns. 120 standards across five levels (1A, 1B, 2, 3A, 3B) and five concepts. Cybersecurity-relevant content concentrates in "Impacts of Computing" and "Networks & the Internet." A first major revision since 2017 is anticipated summer 2026.

## ACM/IEEE CSEC2017 (global, higher-education cybersecurity curriculum)

**Source.** <https://cybered.acm.org/>. The Cybersecurity Curricula 2017 site hosts the curricular guidelines as a PDF, plus an errata sheet.

**License.** Copyright 2017 ACM/IEEE/AIS/IFIP. Permission granted for development of educational materials. Other use requires specific permission.

**Stage.** Save the PDF as `data/raw/csec2017/CSEC2017-Curricular-Guidelines.pdf`.

**Ingest.** `Rscript scripts/010-ingest-csec2017.R`

**Notes.** Best-effort PDF extraction via a markitdown intermediate. The 8 Knowledge Areas and 38 Essentials extract cleanly. Deeper Knowledge-Unit, Topic, and Learning-Outcome detail requires manual curation or table-aware PDF extraction.

## DigComp (EU, citizen digital competence)

**Source.** <https://joint-research-centre.ec.europa.eu/digcomp_en>. The European Commission Joint Research Centre publishes DigComp via the JRC Publications Repository; navigate from the project page to JRC128415 for DigComp 2.2.

**License.** EU open re-use policy. Verify the specific terms at the JRC Publications Repository before redistributing.

**Stage.** Save the PDF as `data/raw/digcomp/DigComp-2.2-JRC128415.pdf`.

**Ingest.** `Rscript scripts/010-ingest-digcomp.R`

**Notes.** Best-effort PDF extraction via markitdown. 5 competence areas and 21 competences extract cleanly. The 8 proficiency levels per competence are documented in the source PDF but not automated (the source layout fragments the level descriptors across multi-column PDF layouts). DigComp 3.0 has been released and is not yet supported.

## Frameworks not yet supported

- **e-CF (European e-Competence Framework, CWA 16234-1).** A future cybedtools release may add e-CF as a ninth framework. e-CF 2.0 RDF is freely available via [EU Joinup](https://joinup.ec.europa.eu/); e-CF 4.0 (the current version, 2020) is behind a CEN paywall unless an institutional license provides direct access.
- **CyBOK (Cybersecurity Body of Knowledge).** Planned for cybedtools 0.2.0. CyBOK is published by the National Cyber Security Centre (UK) under CC BY-SA 4.0 and is freely downloadable from <https://www.cybok.org/>.
