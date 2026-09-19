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

The table above is the v0.2.0 measurement and is kept as a dated snapshot. The three frameworks added in v0.3.0 are not in it. Their current counts, from `framework_summary`, are CyQUAL 852 subpoints and 0 examples, CCSSF 197 subpoints and 0 examples, and OTCCF 0 of either, since its parser is off. Current per-framework counts for all eleven are in `framework_summary$subpoint_count` and `framework_summary$example_count`.

The parser algorithm:

1. Inspect the source text for a "Clarification statement:" header. If present, the parsed items will be tagged `node_type == "Example"` and routed to `cybed:Example`. If absent, items are tagged `node_type == "Subpoint"` and routed to `cybed:Subpoint`.
2. Strip the leading "Clarification statement:" header if present (Cyber.org K-12 / CSTA convention).
3. Locate the LAST list-introducer phrase (`such as`, `examples of`, `examples include`, `including`, `for example`, `e.g.`).
4. Truncate at the first internal sentence boundary (period + whitespace + uppercase letter, or newline).
5. Split on semicolons (preferred) or commas + terminal connective.
6. Filter pure connective items (`and`, `or`, `the`, `but`, `however`, `etc.`).

**Known parser limitation.** The introducer-phrase set is exact: prose using less common framings such as "may include", "can include", "typically include", "for instance", or bullet-list enumerations under headings (e.g., SFIA's "Activities may include but are not limited to:" guidance-note pattern) is not extracted. A future revision of any framework that adopts one of these untracked patterns will silently produce zero Subpoints for that framework's affected elements. Verify with `parse_subpoints()` against representative source text before assuming exhaustive extraction.

Per-framework opt-out: set the environment variable `CYBED_DISABLE_SUBPOINT_PARSER` to a comma-separated list of slugs (e.g., `nice,cyberorg-k12`) before invoking `scripts/020-assemble-jsonld.R`. The default ingestion runs the parser against ten of the eleven frameworks. OTCCF is the exception: its `parser_enabled` flag in `docs/framework-invariants.yml` is `false`, because fragments split out of CSA's statements would be units CSA did not publish.

## Supported framework versions (cybedtools 0.3.0)

| Framework        | Version supported            | Released   | Format              |
|------------------|------------------------------|------------|---------------------|
| NICE             | Framework Components v2.2.0 (NIST SP 800-181 Rev 1) | 2026-04-28 | JSON (CPRT)         |
| DCWF             | v5.1                         | 2025-07-25 | XLSX                |
| ECSF             | v1                           | 2022-09-19 | JSON                |
| SFIA             | 9                            | 2024-10    | SQLite (extract)    |
| Cyber.org K-12   | v1.0                         | 2021-09-09 | PDF                 |
| CSTA K-12 CS     | Revised 2017                 | 2017       | XLSX                |
| ACM/IEEE CSEC    | 2017 v1.0                    | 2017-12-31 | PDF                 |
| DigComp          | 2.2                          | 2022-03-17 | PDF                 |
| CyQUAL           | 1.2.0 (open data export)     | retrieved 2026-09-16 | JSON      |
| CCSSF            | 2022 edition (ITSM.00.039)   | 2023-04-19 | PDF                 |
| OTCCF            | v1.1                         | 2021-10-08 | PDF                 |

`NEWS.md` records which framework versions a given cybedtools release supports; this table tracks the current release.

## How version updates are handled

Each ingestion script targets a specific upstream schema. When a publisher releases a new version:

- **Minor revisions** (count drift, cosmetic changes) usually pass through the same parser. Verification surfaces the drift via the count-band tolerances declared in `docs/framework-invariants.yml`. The ingestion run completes with a soft-flag warning rather than failing silently. Human review updates the bounds when the new counts are known to be correct.
- **Major schema changes** (column renames, restructured JSON, new identifier formats) cause the parser to fail with a hard error. The pipeline stops and the user knows the script needs an update for the new version. A subsequent cybedtools release ships the updated parser.
- **Multiple versions side-by-side.** The staging directory is per-framework, not per-version. You can keep `nice-v2-framework.json` and `nice-v2.2-framework.json` in the same `data/raw/nice/` folder. The ingestion script reads the version-named file the current cybedtools release expects.

If you need a newer upstream version that the current cybedtools release does not yet support, open an issue at <https://github.com/ryanstraight/cybedtools/issues> with a sample of the new schema. Schema-revision PRs are welcome.

Active publisher revisions to watch (as of cybedtools 0.3.0): NICE Framework v2.2.0 components have shipped via NIST CPRT and are now ingested, CSA has said an OTCCF update is in progress, the Canadian Centre for Cyber Security has said an updated CCSSF edition is in preparation, CSTA has signaled a major revision in development (no published target date as of this writing; verify against CSTA's roadmap), SFIA 10 is in consultation, and DigComp 3.0 has been released.

## Structural typing: cybed:OrganizingUnit and cybed:Role

The schema separates the cross-framework abstract type (`cybed:OrganizingUnit`, `subClassOf skos:Concept`) from the workforce-specific subtype (`cybed:Role`, `subClassOf cybed:OrganizingUnit`). Every framework's top-level enumerated unit asserts `cybed:OrganizingUnit`. Workforce frameworks where the unit is genuinely a work role or work profile additionally assert `cybed:Role`. Non-workforce frameworks assert `cybed:OrganizingUnit` only.

Per-framework structural typing:

| Framework         | Per-framework subtype          | Asserts cybed:Role | What the unit IS                                  |
|-------------------|--------------------------------|:------------------:|---------------------------------------------------|
| NICE              | `nice:WorkRole`                | yes                | 42 work roles (+11 competency areas, unit-only)   |
| DCWF              | `dcwf:WorkRole`                | yes                | 74 work roles                                     |
| ECSF              | `ecsf:RoleProfile`             | yes                | 12 role profiles                                  |
| SFIA              | `sfia:Skill`                   | no                 | 147 skills at up to 7 responsibility levels       |
| Cyber.org K-12    | `cyberorg:StandardGroup`    | no                 | 116 grade-band x sub-concept cells (4 grade bands x 29 sub-concepts; Cyber.org's documentation does not name the cell, so cybedtools labels it `cyberorg:StandardGroup` descriptively) |
| CSTA K-12 CS      | `csta:StandardGroup`      | no                 | 25 level x concept cells (5 levels x 5 concepts; CSTA's published terminology uses level / concept / subconcept / practice but does not name the cell, so cybedtools labels it `csta:StandardGroup` descriptively)  |
| CSEC2017          | `csec:KnowledgeArea`           | no                 | 8 Knowledge Areas (curricular thought-model groupings) |
| DigComp 2.2       | `digcomp:CompetenceArea`       | no                 | 5 competence areas                                |
| CyQUAL 1.2.0      | `cyqual:WorkRole`, `cyqual:Competency` | yes (work roles) | 102 work roles plus 59 competencies, 161 organizing units in all |
| CCSSF 2022        | `ccssf:WorkRole`, `ccssf:AdjacentRole` | yes            | 22 core work roles and 37 cyber adjacent roles     |
| OTCCF v1.1        | `otccf:JobRole`, `otccf:TechnicalSkillCompetency` | yes (job roles) | 15 job roles plus the skill units they map to, 61 organizing units in all |

Cross-framework SPARQL queries target `cybed:OrganizingUnit` to reach all eleven frameworks uniformly. Workforce-restricted queries target `cybed:Role` to reach only NICE / DCWF / ECSF / CyQUAL / CCSSF / OTCCF. Framework-specific queries target the per-framework subtype. The `framework_summary` tibble's `organizing_unit_count` column reports the cross-framework count (every framework's parents). Since v0.3.0 the tibble also carries `role_count`, which is the count of units typed `cybed:Role` and is `NA` for the five frameworks that assert no roles.

## NICE (US, NIST)

**Source.** <https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center>. Navigate to "Current Versions" and download the framework as JSON via the NIST Cybersecurity and Privacy Reference Tool (CPRT).

**License.** A US Government work, not subject to copyright in the United States under 17 U.S.C. 105. NIST reserves foreign rights and then grants them back. Verbatim from NIST's licensing statement for Technical Series publications: "Works authored by NIST employees are not subject to Copyright protection within the United States; foreign rights are reserved. To the extent NIST may assert rights outside of the United States, the public is granted the non-exclusive, perpetual, paid-up, royalty-free, worldwide right to reprint works in all formats including print, electronically, and online, and in all subsequent editions, and derivative works." NIST's copyright page adds that "Use of appropriate byline/photo/image credits is requested." The ingested CPRT JSON itself carries no rights statement, so these are the governing statements. Attribute NIST as the source and do not imply NIST endorsement.

**Stage.** Save the downloaded JSON as `data/raw/nice/nice-v2-framework.json` (rename if the publisher's filename differs).

**Ingest.** `Rscript scripts/010-ingest-nice.R`

**Notes.** Targets the NIST SP 800-181 Rev 1 CPRT JSON schema. The current ingestion uses the **CPRT v2.2.0 components (released 2026-04-28)**, retrieved 2026-08-21, SHA256 recorded in `data/raw/nice/provenance.yml`. v2.2.0 carries 42 work roles and 2,211 unique TKS elements: v2.0.0 had consolidated to 41 roles (down from v1's 52), and v2.2.0 adds Cybersecurity Supply Chain Risk Management (OG-WRL-017) plus populated content for the previously-empty Cryptography and DevSecOps competency areas. Superseded v2.0.0 raw data is archived at `data/raw/nice/v2.0.0/` with checksums. Pin the CPRT release date in any reproducibility statement.

Two v2.2.0 specifics worth knowing. NICE's 11 competency areas are now ingested as `cybed:OrganizingUnit` (not `cybed:Role`) with `cybed:hasElement` to their member statements — a second grouping axis over the same knowledge/skill catalog, so queries wanting work roles must filter on `cybed:Role` rather than by framework alone. Only 4 of the 11 areas carry member bindings in the source; the other 7 are titles and descriptions with no published membership. Separately, `S0768` appears in NIST's JSON with zero role memberships but is absent from the companion XLSX — a contradiction internal to the release; it is retained as an orphan element, so the skills count is 556 rather than 555.

The Investigation category description in the v2.2.0 release is a NIST-side regression (it carries foreign-intelligence text). The ingest applies a documented correction from `data/raw/nice/errata.csv`, gated on an exact match against the published value so the patch fails loudly rather than silently reapplying if NIST revises the source.

**DCWF / NICE relationship caveat.** DCWF v5.1 is historically aligned to NICE v2: the two frameworks share substantial element identifiers and scope. The per-unit denominators in this package treat each as independent, but downstream analyses that aggregate "US framework element coverage" across both will double-count overlapping content. cybedtools does not currently materialize the cross-framework alignment as RDF triples; that remains a future extension.

## DCWF (US, DoD)

**Source.** <https://dodcio.defense.gov/Cyber-Workforce/DCWF/>. The DoD CIO Work Role Tool publishes the framework as XLSX, with a download link from the DCWF program page. The DCWF programme page is now at <https://www.cyberworkforce.mil/Department-Cyber-Workforce-Framework/>.

**License.** A work of the US Government prepared by DoD personnel, so not subject to copyright in the United States under 17 U.S.C. 105. Three qualifications belong with that. The v5.1 workbook carries no distribution statement at all, across all 79 sheets, so nothing in the artifact either grants or restricts distribution. The DoD download pages now sit behind authentication (`public.cyber.mil/dcwf/` redirects to `www.cyber.mil/dcwf/`, which redirects into a SAML flow, and `dodcio.defense.gov/Cyber-Workforce/DCWF/` returns HTTP 403), so no download-page statement could be read as of 2026-09-18. Nine work roles carry a "(CUI)" tag in the hyperlink text of the DCWF Roles index sheet: Exploitation Analyst (CE-121), Digital Network Exploitation Analyst (CE-122), Target Digital Network Analyst (CE-132), Target Analyst Reporter (CE-133), Access Network Operator (CE-321), Cyberspace Operator (CE-322), Network Technician (CE-442), Network Analyst (CE-443) and Host Analyst (CE-463). CUI is Controlled Unclassified Information. Review those sheets before any public deposit of DCWF-derived content.

**Stage.** Save the downloaded XLSX as `data/raw/dcwf/dcwf-work-role-tool-v5.1.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-dcwf.R`

**Notes.** v5.1 added DA-series data and AI work roles, bringing the total to 74. DCWF is NICE-aligned and shares mapped identifiers with NICE work roles. The XLSX has multiple sheets; the parser uses readxl.

On the nine "(CUI)"-tagged roles, what the workbook shows: the tag appears only in the hyperlink display text on the DCWF Roles index sheet, never in any cell of any sheet, and the nine role sheets themselves are populated exactly as the other role sheets are. Each carries the same header row (Element, Work Role (DCWF Code), OPR), a functional description, and the same DCWF # / Task-KSA / Core-or-Additional table. They are among the longer sheets in the workbook rather than shorter ones (85 to 256 rows against a 81-to-142 range for a sample of untagged roles), so nothing reads as withheld or replaced by a placeholder. The tag is a marking on the role, not a redaction of the content, on the evidence of this artifact. That is an observation about the file and not a determination of the roles' CUI status, which only the publisher can give.

## ECSF (EU, ENISA)

**Source.** <https://www.enisa.europa.eu/topics/skills-and-competences/skills-development/european-cybersecurity-skills-framework>. ENISA distributes the European Cybersecurity Skills Framework as a PDF report with companion JSON and XLSX files.

**License.** Three separate things are true here and the difference matters. The Role Profiles report PDF is CC BY 4.0 by its own copyright notice: "© European Union Agency for Cybersecurity (ENISA), 2022 / This publication is licenced under CC-BY 4.0 "Unless otherwise noted, the reuse of this document is authorised under the Creative Commons Attribution 4.0 International (CC BY 4.0) licence (https://creativecommons.org/licenses/by/4.0/). This means that reuse is allowed, provided that appropriate credit is given and any changes are indicated"", with "ISBN: 978-92-9204-584-5 – DOI: 10.2824/859537". The report's legal notice adds "All references to it or its use as a whole or partially must contain ENISA as its source." The JSON and XLSX files that cybedtools actually ingests carry no notice of any kind: no copyright, licence, or rights key anywhere in either file, and no rights field in the XLSX document properties. ENISA's site-wide legal notice authorises reproduction more weakly than CC BY does, saying "Reproduction of ENISA material published on this website is authorized, provided the source is acknowledged, unless it is stated otherwise." It neither names Creative Commons nor invokes Commission Decision 2011/833/EU. Content traceable to the report PDF is CC BY 4.0. Content taken from the data files rests on the site-wide acknowledgement regime, which is a reasonable position rather than a quoted grant.

**Attribution.** The package's own wording, since ENISA prescribes no citation string: European Union Agency for Cybersecurity (ENISA), European Cybersecurity Skills Framework (ECSF) Role Profiles, September 2022, ISBN 978-92-9204-584-5, DOI 10.2824/859537. © ENISA 2022, CC BY 4.0.

**Stage.** Save the JSON as `data/raw/ecsf/ECSF_v1.json` and the companion XLSX as `data/raw/ecsf/ECSF.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-ecsf.R`

**Notes.** ECSF v1 was published 2022-09-19 with revisions through 2024-08-02. 12 role profiles with embedded e-CF 4.0 cross-references. Each profile in ECSF carries explicit e-CF 4.0 competency-and-proficiency pointers; without traversing those pointers, the package's element count for ECSF systematically undercounts what ECSF specifies. cybedtools does not currently materialize the e-CF 4.0 cross-references as RDF triples; researchers who need full ECSF coverage should consult the source JSON for the e-CF pointers per profile.

## SFIA (UK, global)

**Source.** <https://sfia-online.org/en>, the canonical SFIA Foundation site. SFIA 9 is downloadable in PDF, XLSX, JSON, and RDF formats; access is free for individuals and small employers under SFIA's Use Policy. The cybedtools ingestion script does not read SFIA's published files directly; it reads a third-party structural extract. See "Notes" below.

**License.** All use of SFIA is under licence from the SFIA Foundation, and the licence covers structure as well as text. The "Using and licensing SFIA" page states "Note: All use of SFIA is under licence." and "The SFIA Framework, guidance and support assets are the intellectual property of the SFIA Foundation." and "Please don't copy content from the SFIA website (Framework content and other assets) and include it on your own websites." and "you cannot sub-licence SFIA to others through your products, services or associate, reseller and partner programmes." The SFIA General Terms and Conditions define the protected material as "The concept, content and structure of SFIA along with content from the SFIA website", define Distribution as "Making copies of SFIA or significant extracts of SFIA available to other parties or organisations, either on its own or combined with other information. This includes the publication of SFIA in a context such as a website that allows SFIA to be browsed by parties not covered by the licence", and name "a skills database containing SFIA information" as an example of a royalty-bearing dependent product. The same terms state that "Licensees shall not use SFIA content, structure, or methodology to create, publish, or promote derivative frameworks, whether competing with or complementary to SFIA, without explicit authorisation from the SFIA Foundation." There is no structure-versus-text carve-out anywhere in those terms.

SFIA's free tiers cover personal use and single-country corporate internal use, so building and querying the graph on your own machine, for your own work or your organisation's internal development, falls within them. Everything past that needs a licence from the Foundation.

cybedtools therefore uses SFIA for local analysis only. It publishes no SFIA statement text and no SFIA structure beyond aggregate counts. Anyone staging SFIA to run this pipeline must hold or fit within their own SFIA licence, and that is their responsibility, not the package's.

**Stage.** Save the SQLite database as `data/raw/sfia/sfia-sqlite.db`.

**Ingest.** `Rscript scripts/010-ingest-sfia.R`

**Notes.** The structural extract used is [jankudev/sfia-tools](https://github.com/jankudev/sfia-tools), release v0.0.1 (2025-02-05), which packages SFIA 9 as a SQLite database built by scraping the SFIA website. The extract is not structure only. `data/raw/sfia/tables/skill.csv` carries `description` and `guidance_notes` columns holding full SFIA prose, `data/raw/sfia/tables/skill-level.csv` carries the full per-level descriptor text, and `data/raw/sfia/tables/attribute.csv` carries descriptions and guidance notes. That text reaches the local graph as `cybed:elementText` and `schema:description` literals. The jankudev repository carries no licence file of any kind, holds no SFIA licence it could pass on, and its README disclaims affiliation with the SFIA Foundation, so nothing about staging that extract substitutes for a licence of your own. SFIA 10 is in consultation and not yet supported.

## Cyber.org K-12 (US, K-12 cybersecurity learning standards)

**Source.** <https://cyber.org/standards>. CYBER.ORG and the Cyber Innovation Center publish the K-12 Cybersecurity Learning Standards as a PDF.

**License.** CC BY-NC 4.0, from the staged PDF's own version-control page: "K-12 Cybersecurity Learning Standards © 2021 by Cyber Innovation Center & CYBER.ORG is licensed under Creative Commons Attribution-NonCommercial 4.0 International". The same page carries a separate and unconditional grant alongside the licence: "Authorization to reproduce this report in whole or in part is granted." The cyber.org/standards page itself carries no licence statement, so the PDF is the only source of terms.

**Attribution.** The prescribed string, verbatim: "Suggested citation: K-12 Cybersecurity Learning Standards. (2021). Retrieved from https://cyber.org/standards."

**Stage.** Save the PDF as `data/raw/cyberorg-k12/K-12-Cybersecurity-Learning-Standards-v1.0.pdf`.

**Ingest.** `Rscript scripts/010-ingest-cyberorg-k12.R`

**Notes.** Best-effort PDF extraction via a markitdown intermediate. Standard ID format is `{grade_band}.{theme}.{sub_code}[.{sequence}]` (e.g., `K-2.SEC.ACC`, `9-12.DC.PPI.2`). The pipeline produces 123 standards across four grade bands (K-2, 3-5, 6-8, 9-12) and 29 sub-concepts.

## CSTA K-12 CS (US, K-12 computer science standards)

**Source.** <https://csteachers.org/2017standards/interactive/>. The Computer Science Teachers Association distributes the Revised 2017 standards as a downloadable XLSX from that edition's page. The older <https://csteachers.org/k12standards/> address now serves the 2026 PK-12 edition, which is a different framework from the one cybedtools ingests.

**License.** CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike). The ingested XLSX carries no licence statement of any kind, in its cells or its document properties, so the label is read from CSTA's publication page for the 2017 edition, which states "These Standards are licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0)." CSTA's licensing contact is licensing@csteachers.org.

**Attribution.** CSTA's suggested citation for the 2017 edition, verbatim: "Computer Science Teachers Association (2017). CSTA K-12 Computer Science Standards, Revised 2017. Retrieved from https://csteachers.org/k12standards/." The URL inside that string is CSTA's own and is reproduced as published, although it now resolves to the 2026 edition.

**Stage.** Save the XLSX as `data/raw/csta/csta-k-12-standards-revised-2017.xlsx`.

**Ingest.** `Rscript scripts/010-ingest-csta.R`

**Notes.** Single sheet, nine columns. 120 standards across five levels (1A, 1B, 2, 3A, 3B) and five concepts. Cybersecurity-relevant content concentrates in "Impacts of Computing" and "Networks & the Internet." 114 of the 120 standards carry pedagogical clarification text in a separate `clarification` column; the cybedtools assembler extracts each non-empty clarification as a `cybed:Example` node linked to the parent standard via `cybed:hasExample`. CSTA has signaled a major revision in development; verify against CSTA's published roadmap before assuming a target release window.

## ACM/IEEE CSEC2017 (global, higher-education cybersecurity curriculum)

**Source.** <https://cybered.acm.org/>. The Cybersecurity Curricula 2017 site hosts the curricular guidelines as a PDF, plus an errata sheet.

**License.** All rights reserved, with one purpose-scoped permission. From the staged PDF's own copyright page: "Copyright © 2017 by ACM, IEEE, AIS, IFIP / ALL RIGHTS RESERVED / Copyright and Reprint Permissions: Permission is granted to use these curricular guidelines for the development of educational materials and programs. Other use requires specific permission. Permission requests should be addressed to: ACM Permissions Dept. at permissions@acm.org, the IEEE Copyrights Manager at copyrights@ieee.org, the AIS eLibrary@aisnet.org or the IFIP at ifip@ifip.org. / ISBN: 978-1-4503-5278-9 / DOI: 10.1145/3184594". The grant is limited by purpose rather than by who may use it, and it does not extend to republishing the guidelines themselves. cybedtools publishes CSEC2017 Knowledge Area names, counts and alignment scores, and no statement text. A permission request to ACM covering machine-readable derivatives is being prepared.

**Attribution.** The package's own wording, since no citation string is prescribed: Cybersecurity Curricula 2017: Curriculum Guidelines for Post-Secondary Degree Programs in Cybersecurity, version 1.0 (31 December 2017). Copyright © 2017 ACM, IEEE, AIS, IFIP. DOI 10.1145/3184594. Used under the permission granted for development of educational materials.

**Stage.** Save the PDF as `data/raw/csec2017/CSEC2017-Curricular-Guidelines.pdf`.

**Ingest.** `Rscript scripts/010-ingest-csec2017.R`

**Notes.** Best-effort PDF extraction via a markitdown intermediate. The 8 Knowledge Areas and 38 Essentials extract cleanly. Deeper Knowledge-Unit, Topic, and Learning-Outcome detail requires manual curation or table-aware PDF extraction.

**Structural framing caveat.** CSEC2017 is a curricular framework, not a workforce framework. The 8 Knowledge Areas are thought-model groupings for cybersecurity curricular design; CSEC2017 explicitly does not specify "roles." Under v0.2.0, cybedtools' schema types each Knowledge Area as `csec:KnowledgeArea` and `cybed:OrganizingUnit` (it does not assert `cybed:Role`, which is reserved for frameworks that genuinely enumerate work roles or work profiles). Cross-framework comparison reaches CSEC2017 via the `cybed:OrganizingUnit` abstract.

## DigComp (EU, citizen digital competence)

**Source.** <https://joint-research-centre.ec.europa.eu/digcomp_en>. The European Commission Joint Research Centre publishes DigComp via the JRC Publications Repository; navigate from the project page to JRC128415 for DigComp 2.2.

**License.** CC BY 4.0, by the staged PDF's own imprint page: "© European Union, 2022 / The reuse policy of the European Commission is implemented by the Commission Decision 2011/833/EU of 12 December 2011 on the reuse of Commission documents (OJ L 330, 14.12.2011, p. 39). Except otherwise noted, the reuse of this document is authorised under the Creative Commons Attribution 4.0 International (CC BY 4.0) licence (https://creativecommons.org/licenses/by/4.0/). This means that reuse is allowed provided appropriate credit is given and any changes are indicated. For any use or reproduction of photos or other material that is not owned by the EU, permission must be sought directly from the copyright holders." Nothing cybedtools ingests is marked "otherwise noted" and none of it is photographic, so the third-party carve-out does not reach it.

**Attribution.** The prescribed string, verbatim from the imprint page: "How to cite this report: Vuorikari, R., Kluzer, S. and Punie, Y., DigComp 2.2: The Digital Competence Framework for Citizens, EUR 31006 EN, Publications Office of the European Union, Luxembourg, 2022, ISBN 978-92-76-48882-8, doi:10.2760/115376, JRC128415."

**Stage.** Save the PDF as `data/raw/digcomp/DigComp-2.2-JRC128415.pdf`.

**Ingest.** `Rscript scripts/010-ingest-digcomp.R`

**Notes.** Best-effort PDF extraction via markitdown. 5 competence areas and 21 competences extract cleanly. The 8 proficiency levels per competence are documented in the source PDF but not automated (the source layout fragments the level descriptors across multi-column PDF layouts). DigComp 3.0 has been released and is not yet supported.

**Cybersecurity scope caveat.** DigComp's specificity tag is "general-digital-competence" reflecting the framework's overall scope, but Area 4 (Safety) covers protecting devices, personal data and privacy, health and well-being, and the environment, all of which overlap cybersecurity content. Researchers doing topic-level cross-framework comparisons should treat DigComp Area 4 competences as cybersecurity-relevant for those purposes, even though the framework as a whole is broader.

**Prose-density caveat.** DigComp 2.2's signature update over 2.1 is the addition of "21 new examples of knowledge, skills, and attitudes" per competence, distributed across Annexes 1-3 of the source PDF. The cybedtools sub-point parser does not currently surface these annex examples as graph elements (extraction fragments across multi-column layouts). DigComp's apparent low element density in `framework_summary` reflects this extraction limitation, not low pedagogical density in the framework itself.

## Frameworks added by steward permission

Two of the three frameworks below are included with the written permission of their stewards, and the Canadian framework is referenced as its steward asked. Each has its own terms, stated under **License**, and those terms apply to you as well if you stage the source and build the graph. As with every framework here, cybedtools ships the ingestion code and not the source text. You retrieve the source yourself.

Statement codes are unique only within a framework. CyQUAL keeps the task codes of the 2017 NICE Framework (its `T0516` is NICE's 2017 `T0516`), and it also uses the `T1xxx` range for its own additions, a range NIST later reused for different statements. A code that appears in two frameworks is not evidence that the statements match. Align frameworks through statement text or a published crosswalk, never by joining on a bare code. In the graph every identifier sits under its framework's own namespace, so graph queries cannot confuse them. The risk is in tables.

## CyQUAL (Czech Republic, national cybersecurity qualifications framework)

**Source.** <https://platform.cyqual.cz/en>. CyQUAL is developed at Masaryk University. The platform's front page offers the framework as an open-data JSON export ("Download open data"), in English and in Czech. No account is needed.

**License.** Published as open data. The CyQUAL team confirmed in writing (2026-09-16) that a derived RDF/JSON-LD graph may be built from the export, and asked for attribution to CyQUAL and to Masaryk University.

**Attribution.** CyQUAL, the Czech national cybersecurity qualifications framework, developed at Masaryk University. Open data, version 1.2.0, <https://platform.cyqual.cz/>.

**Stage.** Save the English export as `data/raw/cyqual/cyqual_open_data_en_1.2.0.json`. The Czech export (`cyqual_open_data_cs_1.2.0.json`) may be staged beside it. The ingestion script prefers the English file and falls back to the Czech one, records which it used, and sets the framework's language in the graph when the text is not English.

**Ingest.** `Rscript scripts/010-ingest-cyqual.R`

**Notes.** Data version 1.2.0: 102 work roles in 37 specialization areas and 7 categories, 1,168 tasks, 1,320 requirements, and 59 competencies in 4 groups. Tasks and requirements are shared across roles, as in NICE. The export has no knowledge, skill, or ability field on requirements. The distinction shows only in how a statement opens, so cybedtools types them all as `cyqual:Requirement` and does not infer a finer type. Work roles are typed `cybed:Role`. Competencies are typed `cybed:OrganizingUnit` and hold the requirements assigned to them, so CyQUAL contributes two kinds of organizing unit, as NICE does with work roles and competency areas. The source has 107 tasks and 50 requirements attached to no role. They are kept. Roles WR091 to WR102 are the twelve ENISA ECSF profiles, and WR091 and WR092 carry an unparsed multi-section description in the source. One requirement (R1238) is in Czech in the English export. All of this is preserved as published.

## CCSSF (Canada, Canadian Cyber Security Skills Framework)

**Source.** The Canadian Cyber Security Skills Framework (ITSM.00.039), Canadian Centre for Cyber Security. The public page carries the main document. The full document with Annexes A to E, which hold the role detail, is available from the Centre's Cyber Skills Development Team on request.

**License.** Copyright Government of Canada. The Centre supplied the full document for this use and asks that the material be referenced when used. The document itself carries no license notice, so do not assume the Open Government Licence applies. The document is marked "TLP:CLEAR" and "UNCLASSIFIED / NON CLASSIFIÉ" on every page. Both are disclosure markings under the Traffic Light Protocol and the Government of Canada's security classification scheme, and neither is a copyright licence, so they do not widen what the Centre granted.

**Attribution.** Canadian Centre for Cyber Security, The Canadian Cyber Security Skills Framework (ITSM.00.039), 2022 edition. Copyright Government of Canada. Referenced as the Canadian Centre for Cyber Security asked.

**Stage.** Save the PDF as `data/raw/ccssf/Canadian Cyber Security Skills Framework 2022 -ENG.pdf`.

**Ingest.** `Rscript scripts/010-ingest-ccssf.R`

**Notes.** The file and catalogue number say 2022. The printed effective date and only revision are 2023-04-19. The framework adapts NICE for the Canadian labour market: 22 core work roles in 4 activity areas, plus 37 "cyber adjacent" roles in Annex E. Both are typed `cybed:Role`, with subtypes `ccssf:WorkRole` and `ccssf:AdjacentRole`. Tasks, competencies, and tools and technology become elements. The role-level prose fields (consequence of error, development pathway, qualifications, future trends) and the National Occupational Classification codes stay in the staged tables and are not in the graph. The document cites 2017-era NICE work role ids, which do not match the ids in current NICE, so they are recorded as `cybed:niceCrossReference` literals and are not links. Two ids are misprinted in the source ("SP-ARC 002", "SP Dev-001"). The literal gives the normalized id and shows the printed form. Ten core roles cite no NICE role. Extraction is from PDF word coordinates: the table structure is reconstructed, the statement text is verbatim, and source typos are kept. The Centre has said an updated edition is in preparation.

## OTCCF (Singapore, Operational Technology Cybersecurity Competency Framework)

**Source.** <https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/>. Published by the Cyber Security Agency of Singapore (CSA) as a PDF.

**License.** Copyright Cyber Security Agency of Singapore. The document names a second organization as a joint developer, verbatim from its front matter: "The OTCCF - jointly developed by CSA and Mercer Singapore, and supported by SkillsFuture Singapore (SSG) and Infocomm Media Development Authority (IMDA) - maps out the various OT cybersecurity job roles and the corresponding technical skills and core competencies required." Whether Mercer Singapore holds any interest that CSA's permission does not reach is unresolved and worth confirming with CSA. CSA granted written permission (2026-09-15) to reference and integrate the OTCCF's structure into cybedtools for non-commercial, academic and research purposes, on two conditions: the attribution below, word for word, and that ingestion scripts and structural mappings do not misrepresent or alter the intent of the OTCCF's job roles, skills, or competency mappings as published by CSA. This is narrower than the MIT license on the package code. The permission covers structure: roles, skill titles, categories, proficiency levels, and the role-to-skill mappings. It was not sought or given for republishing the framework's statement text. cybedtools therefore publishes only OTCCF structure in anything it makes public, and the ingestion record marks the framework `public_redistribution: structure_only`. If you build on the OTCCF portion, the same limits apply to you, and commercial use needs CSA's own permission.

**Attribution.** Derived from the Operational Technology Cybersecurity Competency Framework (OTCCF), published by the Cyber Security Agency of Singapore (CSA). Available at: https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/

**Stage.** Save the PDF as `data/raw/otccf/OT-Cybersecurity-Competency-Framework_V5.pdf`.

**Ingest.** `Rscript scripts/010-ingest-otccf.R`

**Notes.** The document describes itself as version 1.1, effective 8 October 2021. "V5" is the publisher's file label. The OTCCF has two independent halves, and cybedtools models both as published and does not fold one into the other. The 15 job roles are typed `cybed:Role` and hold their key tasks, each tagged with the Critical Work Function it sits under. The 30 Technical Skills and Competencies are typed `cybed:OrganizingUnit` and hold their own knowledge and ability statements by proficiency level. The two halves meet only in the skills maps, where CSA states which skills a role requires and at what level. Those statements are in the graph as `cybed:UnitRelation` nodes with the level exactly as printed (2 to 6 for technical skills, and Basic, Intermediate, or Advanced for Critical Core Skills). Eight of the 30 skills, the whole Organisational Management and Support category, are marked by CSA as extracted from the SkillsFuture ICT Framework, and the Critical Core Skills are defined by SkillsFuture Singapore. Both are tagged with `cybed:sourceCategory` so the second rights holder stays visible. The sub-point parser is off for this framework, because fragments split out of CSA's statements would be units CSA did not publish. The nesting of key tasks under Critical Work Functions is reconstructed from page layout. CSA has said an update is in progress.

## Frameworks not in this release

- **e-CF (European e-Competence Framework, CWA 16234-1).** Not currently ingested. e-CF 2.0 RDF is freely available via [EU Joinup](https://joinup.ec.europa.eu/); e-CF 4.0 (the current version, 2020) is behind a CEN paywall unless an institutional license provides direct access.
- **CyBOK (Cybersecurity Body of Knowledge).** Not currently ingested. Published by the National Cyber Security Centre (UK) under CC BY-SA 4.0 and freely downloadable from <https://www.cybok.org/>.
