# Framework Data Sources

Where to obtain each in-scope framework, how to stage it for cybedtools, and which ingestion script processes it. Licensing and redistribution constraints vary by framework; each section flags the relevant terms.

This repository **does not bundle upstream framework source text**. Each ingestion script reads from `data/raw/<slug>/`, where the user has placed the publisher's source artifact. The script then writes tidy CSVs and a `provenance.yml` manifest (SHA256, retrieval date, license).

## Sub-point parsing

The JSON-LD assembly step runs `parse_subpoints()` over each parent element's `cybed:elementText` to lift prose-encoded enumerations into first-class child elements. The parser distinguishes two source patterns and routes each to a distinct vocabulary type:

- **Framework-as-specified enumerations** ("such as", "including", "examples of", "for example", "e.g.", and standalone semicolon lists) become `cybed:Subpoint` instances. Subpoints retain their parent's framework-native subtype (e.g., `nice:TaskStatement`, `sfia:SkillLevel`) and carry `cybed:elaborates` back-pointers to their parent. They appear in default `cybed:hasElement` traversals because they are part of the parent element's normative content.
- **Pedagogical-scaffolding clarification content** becomes `cybed:Example` instances. Two source-data shapes route here. (1) Cyber.org K-12 stores Clarification statements inline in the standard text under a "Clarification statement:" header; the parser strips the header and extracts enumerations, tagging each with `node_type == "Example"`. (2) CSTA K-12 CS stores its clarifications in a separate `clarification` column rather than inline; the CSTA assembler reads that column directly and emits one `cybed:Example` per non-empty clarification (no further enumeration parsing because CSTA clarifications are typically narrative paragraphs rather than enumerated lists). Both paths produce nodes with no framework-native subtype, reachable from the parent only via `cybed:hasExample`. Examples are excluded from default `cybed:hasElement` traversals so role-level "all elements" queries remain restricted to framework-as-specified content.

This split addresses the v0.1.x concern that promoting Clarification examples to `cybed:Subpoint` overstated what the framework specifies. A teacher who teaches one Cyber.org K-12 Example has met the standard; the framework does not require coverage of all Examples. Under v0.2.0, the strict element count (`framework_summary$element_count_strict`) excludes Examples and reports what each framework specifies as its normative content. The inclusive count (`element_count_with_examples`) is available for analyses that need a fine-grained search index across pedagogical scaffolding too.

SFIA's "such as" lists are framework-as-specified enumerations rather than pedagogical scaffolding, so they remain typed `cybed:Subpoint`. The reader should still treat SFIA examples as illustrative for level placement rather than enumerable competencies; the typing decision says only that SFIA's enumeration shape is structurally distinct from the Clarification-statement convention.

Per-framework parser output in v0.2.0:

| Framework        | Parser  | Subpoints | Examples | Notes                                                                                                                                                                                       |
|------------------|---------|----------:|---------:|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| NICE             | enabled |         4 |        0 | Spot-check 0/10 false-positive. Two parents have small "including X and Y" lists.                                                                                                         |
| DCWF             | enabled |         0 |        0 | Terse elementText literals; no enumerations to lift.                                                                                                                                       |
| ECSF             | enabled |        16 |        0 | Spot-check 1/10 borderline ("a building" artifact in a researcher task). Acceptable.                                                                                                      |
| SFIA             | enabled |       158 |        0 | Sentence-boundary stop and connective filter handle multi-sentence elementText cleanly. Re-spot-check 0/10. Largest workforce-side gain.                                                  |
| Cyber.org K-12   | enabled |         0 |      377 | Largest single-framework gain, routed to `cybed:Example`. Every parent has an explicit "Clarification statement:" segment with enumerated examples.                                       |
| CSTA K-12 CS     | enabled |        20 |      114 | Two extraction paths: 20 Subpoints come from "such as" enumerations in the `standard` column (framework-as-specified); 114 Examples come from the separate `clarification` column (one Example per non-empty clarification, treated as pedagogical scaffolding). |
| ACM/IEEE CSEC2017 | enabled |         2 |        0 | Connective filter handles source-truncated standards. Re-spot-check 0/2. The two Subpoints (least privilege, open design) are real.                                                       |
| DigComp 2.2      | enabled |         0 |        0 | Clean numbered standards; no enumerations to lift.                                                                                                                                          |

The parser algorithm:

1. Inspect the source text for a "Clarification statement:" header. If present, the parsed items will be tagged `node_type == "Example"` and routed to `cybed:Example`. If absent, items are tagged `node_type == "Subpoint"` and routed to `cybed:Subpoint`.
2. Strip the leading "Clarification statement:" header if present (Cyber.org K-12 / CSTA convention).
3. Locate the LAST list-introducer phrase (`such as`, `examples of`, `examples include`, `including`, `for example`, `e.g.`).
4. Truncate at the first internal sentence boundary (period + whitespace + uppercase letter, or newline).
5. Split on semicolons (preferred) or commas + terminal connective.
6. Filter pure connective items (`and`, `or`, `the`, `but`, `however`, `etc.`).

**Known parser limitation.** The introducer-phrase set is exact: prose using less common framings such as "may include", "can include", "typically include", "for instance", or bullet-list enumerations under headings (e.g., SFIA's "Activities may include but are not limited to:" guidance-note pattern) is not extracted. A future revision of any framework that adopts one of these untracked patterns will silently produce zero Subpoints for that framework's affected elements. Verify with `parse_subpoints()` against representative source text before assuming exhaustive extraction.

Per-framework opt-out: set the environment variable `CYBED_DISABLE_SUBPOINT_PARSER` to a comma-separated list of slugs (e.g., `nice,cyberorg-k12`) before invoking `scripts/020-assemble-jsonld.R`. The default ingestion runs the parser against all eight.

## Supported framework versions (cybedtools 0.2.0)

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

Active publisher revisions to watch (as of cybedtools 0.2.0): NICE Framework v2.2.0 components have shipped via NIST CPRT, CSTA has signaled a major revision in development (no published target date as of this writing; verify against CSTA's roadmap), SFIA 10 is in consultation, and DigComp 3.0 has been released.

## Structural typing: cybed:OrganizingUnit and cybed:Role

The schema separates the cross-framework abstract type (`cybed:OrganizingUnit`, `subClassOf skos:Concept`) from the workforce-specific subtype (`cybed:Role`, `subClassOf cybed:OrganizingUnit`). Every framework's top-level enumerated unit asserts `cybed:OrganizingUnit`. Workforce frameworks where the unit is genuinely a work role or work profile additionally assert `cybed:Role`. Non-workforce frameworks assert `cybed:OrganizingUnit` only.

Per-framework structural typing:

| Framework         | Per-framework subtype          | Asserts cybed:Role | What the unit IS                                  |
|-------------------|--------------------------------|:------------------:|---------------------------------------------------|
| NICE              | `nice:WorkRole`                | yes                | 41 work roles                                     |
| DCWF              | `dcwf:WorkRole`                | yes                | 74 work roles                                     |
| ECSF              | `ecsf:RoleProfile`             | yes                | 12 role profiles                                  |
| SFIA              | `sfia:Skill`                   | no                 | 147 skills at up to 7 responsibility levels       |
| Cyber.org K-12    | `cyberorg:StandardGroup`    | no                 | 116 grade-band x sub-concept cells (4 grade bands x 29 sub-concepts; Cyber.org's documentation does not name the cell, so cybedtools labels it `cyberorg:StandardGroup` descriptively) |
| CSTA K-12 CS      | `csta:StandardGroup`      | no                 | 25 level x concept cells (5 levels x 5 concepts; CSTA's published terminology uses level / concept / subconcept / practice but does not name the cell, so cybedtools labels it `csta:StandardGroup` descriptively)  |
| CSEC2017          | `csec:KnowledgeArea`           | no                 | 8 Knowledge Areas (curricular thought-model groupings) |
| DigComp 2.2       | `digcomp:CompetenceArea`       | no                 | 5 competence areas                                |

Cross-framework SPARQL queries target `cybed:OrganizingUnit` to reach all eight frameworks uniformly. Workforce-restricted queries target `cybed:Role` to reach only NICE / DCWF / ECSF. Framework-specific queries target the per-framework subtype. The `framework_summary` tibble's `organizing_unit_count` column reports the cross-framework count (every framework's parents); `role_count` is no longer present because that label was misleading for the five non-workforce frameworks.

## NICE (US, NIST)

**Source.** <https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center>. Navigate to "Current Versions" and download the framework as JSON via the NIST Cybersecurity and Privacy Reference Tool (CPRT).

**License.** US Government work, public domain.

**Stage.** Save the downloaded JSON as `data/raw/nice/nice-v2-framework.json` (rename if the publisher's filename differs).

**Ingest.** `Rscript scripts/010-ingest-nice.R`

**Notes.** Targets the v2 (NIST SP 800-181 Rev 1) CPRT JSON schema. v2 consolidated to 41 work roles with 2,111 unique TKS elements (down from v1's 52 work roles). The current ingestion uses the CPRT v2.0.0 components retrieved 2026-04-23 (SHA256 recorded in `data/raw/nice/provenance.yml`). NIST has released v2.2.0 components since this ingestion. Pin the CPRT release date in any reproducibility statement.

**DCWF / NICE relationship caveat.** DCWF v5.1 is historically aligned to NICE v2: the two frameworks share substantial element identifiers and scope. The per-unit denominators in this package treat each as independent, but downstream analyses that aggregate "US framework element coverage" across both will double-count overlapping content. cybedtools does not currently materialize the cross-framework alignment as RDF triples; that remains a future extension.

## DCWF (US, DoD)

**Source.** <https://dodcio.defense.gov/Cyber-Workforce/DCWF/>. The DoD CIO Work Role Tool publishes the framework as XLSX, with a download link from the DCWF program page.

**License.** US Government work, public domain. Some DoD publications carry distribution statements; verify the artifact you download.

**Stage.** Save the downloaded XLSX as `data/raw/dcwf/dcwf-work-role-tool-v5.1.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-dcwf.R`

**Notes.** v5.1 added DA-series data and AI work roles, bringing the total to 74. DCWF is NICE-aligned and shares mapped identifiers with NICE work roles. The XLSX has multiple sheets; the parser uses readxl.

## ECSF (EU, ENISA)

**Source.** <https://www.enisa.europa.eu/topics/skills-and-competences/skills-development/european-cybersecurity-skills-framework>. ENISA distributes the European Cybersecurity Skills Framework as a PDF report with companion JSON and XLSX files.

**License.** Published under ENISA's re-use notice. ENISA's standard publication notice is functionally equivalent to CC BY 4.0 for the report PDF, but the JSON/XLSX companion files may carry a different notice or permission scope. Verify the specific artifact's re-use terms against the ENISA notice published alongside it before redistributing or building on the data.

**Stage.** Save the JSON as `data/raw/ecsf/ECSF_v1.json` and the companion XLSX as `data/raw/ecsf/ECSF.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-ecsf.R`

**Notes.** ECSF v1 was published 2022-09-19 with revisions through 2024-08-02. 12 role profiles with embedded e-CF 4.0 cross-references. Each profile in ECSF carries explicit e-CF 4.0 competency-and-proficiency pointers; without traversing those pointers, the package's element count for ECSF systematically undercounts what ECSF specifies. cybedtools does not currently materialize the e-CF 4.0 cross-references as RDF triples; researchers who need full ECSF coverage should consult the source JSON for the e-CF pointers per profile.

## SFIA (UK, global)

**Source.** <https://sfia-online.org/en>, the canonical SFIA Foundation site. SFIA 9 is downloadable in PDF, XLSX, JSON, and RDF formats; access is free for individuals and small employers under SFIA's Use Policy. The cybedtools ingestion script does not read SFIA's published files directly; it reads a third-party structural extract. See "Notes" below.

**License.** Licensed by the SFIA Foundation under the SFIA Use Policy. The Use Policy permits free use by individuals, accredited training providers under partnership, and small employers below a defined threshold; commercial consultancies and large employers require paid licensing. Redistribution of full SFIA-copyrighted skill text is restricted regardless of use category. Confirm your use case against the current SFIA Use Policy at sfia-online.org before assuming any single-line summary applies.

**Stage.** Save the SQLite database as `data/raw/sfia/sfia-sqlite.db`.

**Ingest.** `Rscript scripts/010-ingest-sfia.R`

**Notes.** The structural extract used is [jankudev/sfia-tools](https://github.com/jankudev/sfia-tools), release v0.0.1 (2025-02-05), which packages SFIA 9 as a SQLite database of framework structure (skill IDs, levels, attributes, relationships). Full skill descriptions are not bundled by jankudev. If your analysis needs the full skill text, retrieve it from sfia-online.org under the SFIA Use Policy applicable to your situation and do not commit it to the repository. SFIA 10 is in consultation and not yet supported.

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

**Notes.** Single sheet, nine columns. 120 standards across five levels (1A, 1B, 2, 3A, 3B) and five concepts. Cybersecurity-relevant content concentrates in "Impacts of Computing" and "Networks & the Internet." 114 of the 120 standards carry pedagogical clarification text in a separate `clarification` column; the cybedtools assembler extracts each non-empty clarification as a `cybed:Example` node linked to the parent standard via `cybed:hasExample`. CSTA has signaled a major revision in development; verify against CSTA's published roadmap before assuming a target release window.

## ACM/IEEE CSEC2017 (global, higher-education cybersecurity curriculum)

**Source.** <https://cybered.acm.org/>. The Cybersecurity Curricula 2017 site hosts the curricular guidelines as a PDF, plus an errata sheet.

**License.** Copyright 2017 ACM/IEEE/AIS/IFIP. Permission granted for development of educational materials. Other use requires specific permission.

**Stage.** Save the PDF as `data/raw/csec2017/CSEC2017-Curricular-Guidelines.pdf`.

**Ingest.** `Rscript scripts/010-ingest-csec2017.R`

**Notes.** Best-effort PDF extraction via a markitdown intermediate. The 8 Knowledge Areas and 38 Essentials extract cleanly. Deeper Knowledge-Unit, Topic, and Learning-Outcome detail requires manual curation or table-aware PDF extraction.

**Structural framing caveat.** CSEC2017 is a curricular framework, not a workforce framework. The 8 Knowledge Areas are thought-model groupings for cybersecurity curricular design; CSEC2017 explicitly does not specify "roles." Under v0.2.0, cybedtools' schema types each Knowledge Area as `csec:KnowledgeArea` and `cybed:OrganizingUnit` (it does not assert `cybed:Role`, which is reserved for frameworks that genuinely enumerate work roles or work profiles). Cross-framework comparison reaches CSEC2017 via the `cybed:OrganizingUnit` abstract.

## DigComp (EU, citizen digital competence)

**Source.** <https://joint-research-centre.ec.europa.eu/digcomp_en>. The European Commission Joint Research Centre publishes DigComp via the JRC Publications Repository; navigate from the project page to JRC128415 for DigComp 2.2.

**License.** EU open re-use policy. Verify the specific terms at the JRC Publications Repository before redistributing.

**Stage.** Save the PDF as `data/raw/digcomp/DigComp-2.2-JRC128415.pdf`.

**Ingest.** `Rscript scripts/010-ingest-digcomp.R`

**Notes.** Best-effort PDF extraction via markitdown. 5 competence areas and 21 competences extract cleanly. The 8 proficiency levels per competence are documented in the source PDF but not automated (the source layout fragments the level descriptors across multi-column PDF layouts). DigComp 3.0 has been released and is not yet supported.

**Cybersecurity scope caveat.** DigComp's specificity tag is "general-digital-competence" reflecting the framework's overall scope, but Area 4 (Safety) covers protecting devices, personal data and privacy, health and well-being, and the environment, all of which overlap cybersecurity content. Researchers doing topic-level cross-framework comparisons should treat DigComp Area 4 competences as cybersecurity-relevant for those purposes, even though the framework as a whole is broader.

**Prose-density caveat.** DigComp 2.2's signature update over 2.1 is the addition of "21 new examples of knowledge, skills, and attitudes" per competence, distributed across Annexes 1-3 of the source PDF. The cybedtools sub-point parser does not currently surface these annex examples as graph elements (extraction fragments across multi-column layouts). DigComp's apparent low element density in `framework_summary` reflects this extraction limitation, not low pedagogical density in the framework itself.

## Frameworks not in this release

- **e-CF (European e-Competence Framework, CWA 16234-1).** Not currently ingested. e-CF 2.0 RDF is freely available via [EU Joinup](https://joinup.ec.europa.eu/); e-CF 4.0 (the current version, 2020) is behind a CEN paywall unless an institutional license provides direct access.
- **CyBOK (Cybersecurity Body of Knowledge).** Not currently ingested. Published by the National Cyber Security Centre (UK) under CC BY-SA 4.0 and freely downloadable from <https://www.cybok.org/>.
