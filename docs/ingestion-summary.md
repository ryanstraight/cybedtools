---
title: Ingestion Summary
type: status
date: 2026-09-21
status: auto-generated
---

# Ingestion Summary

Regenerate with `Rscript scripts/016-summarize-ingestion.R`. Last rendered 2026-09-21.

**Frameworks staged: 16**

## ASD Cyber Skills Framework (`asd`)

- **Publisher:** Australian Signals Directorate (ASD)
- **Version:** v2 (October 2022, originally v1.0 July 2019)
- **Version date:** 2022-10-01

### Source
- **Type:** pdf

### Retrieval
- **Retrieved:** 2026-08-15 by `pdf.js text extraction via browser (curl/WebFetch could not reach asd.gov.au from this environment -- DNS resolves but TLS connection times out; the browser's network path succeeded)`

### Extracted scales
- **role count:** 9
- **proficiency level count:** 6
- **capability area count:** 9

### Licensing
- **source license:** MIXED, confirmed by direct page-by-page read of the PDF (not inferred from cyber.gov.au's general site copyright page, which is CC BY 4.0 but does not govern this specific document). Page 2 (overall document copyright notice) states -- "© Commonwealth of Australia 2020. This work is copyright. Apart from any use as permitted under the Copyright Act 1968 (Cwth), no part may be reproduced by any process without written permission from the Australian Signals Directorate." This governs the substantive role/capability/skill/ proficiency-level text (pages 15-51), which is the content that would actually be ingested. Separately, the four Digital Career Pathway diagram pages (50-53) each carry their own stamp -- "This work is licensed under a Creative Commons Attribution 4.0 International License" -- but these are visual skill-code-to-role pathway maps, not the ingestable role/skill text, and duplicate structural information already present elsewhere.
- **redistribution:** BLOCKED. Do not wire this into scripts/020-assemble-jsonld.R or export any derived JSON-LD/CSV until written permission is obtained from ASD (asd.assist@defence.gov.au, per the document's own contact line) or a different explicit treatment is authorized.

## CCSSF (`ccssf`)

- **Publisher:** Canadian Centre for Cyber Security
- **Version:** 2022
- **Version date:** 2023-04-19

### Source
- **Type:** official_pdf_supplied_by_steward
- **File:** `Canadian Cyber Security Skills Framework 2022 -ENG.pdf`

### Retrieval
- **Retrieved:** 2026-09-16 by `scripts/010-ingest-ccssf.R`
- **SHA256:** `568528be170e7738c1983599f3a68810167900b552ce07296e068c35145030e4`

### Extracted scales
- **activity areas:** 4
- **core roles:** 22
- **core roles declared by document:** 22
- **core role elements:** 1,368
- **core role elements with parent:** 30
- **pages with ambiguous indentation:** 
- **element type breakdown:** competencies=510, consequence_of_error_or_risk=22, development_pathway=22, functional_description=22, future_trends_affecting_key_competencies=126, nice_framework_reference=22, other_titles=69, related_nocs=58, required_qualifications_for_education=22, required_training=26, required_work_experience=22, tasks=293, tools_and_technology=154
- **adjacent roles:** 37
- **adjacent role competencies:** 265
- **nice work role references:** 39
- **spot check:** seed=2,026, elements_checked=15, exact_matches=15, discrepancies=0

### Licensing
- **source license:** Copyright Government of Canada. Referenced as the Canadian Centre for Cyber Security asked. Supplied directly by the Cyber Skills Development Team, 2026-09-16.
- **redistribution:** Not granted permission; use with attribution. Reference the publication (ITSM.00.039) wherever the material or a derivative of it is used.

## CSEC2017 (`csec2017`)

- **Publisher:** ACM / IEEE / AIS SIGSEC / IFIP WG 11.8
- **Version:** CSEC2017 Curricular Guidelines v1.0
- **Version date:** 2017-12-31

### Source
- **Type:** pdf_with_markdown_intermediate
- **File:** `CSEC2017-Curricular-Guidelines.pdf`

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-csec2017.R`
- **SHA256:** `2d668b321e142bdfc28dd93c42984f85d49b71917f8daf9a910d5e82e20806e0`

### Extracted scales
- **knowledge areas:** 8
- **essentials total:** 38
- **essentials by ka:** KA-COMP=6, KA-CONN=5, KA-DATA=4, KA-HUM=4, KA-ORG=4, KA-SOC=3, KA-SW=5, KA-SYS=7

### Licensing
- **source license:** Copyright 2017 ACM/IEEE/AIS/IFIP, all rights reserved; permission granted only to use these curricular guidelines for the development of educational materials and programs; other use requires specific permission
- **redistribution note:** The source PDF's copyright page reads 'Copyright (c) 2017 by ACM, IEEE, AIS, IFIP / ALL RIGHTS RESERVED' and grants permission only 'to use these curricular guidelines for the development of educational materials and programs. Other use requires specific permission.' cybedtools publishes CSEC2017 knowledge-area names, counts and alignment scores, and no statement text. A permission request to ACM (permissions@acm.org) covering machine-readable derivatives is being prepared. ISBN 978-1-4503-5278-9, DOI 10.1145/3184594.

## CSTA K-12 CS (`csta`)

- **Publisher:** Computer Science Teachers Association (CSTA)
- **Version:** CSTA K-12 Computer Science Standards (Revised 2017)
- **Version date:** 2017

### Source
- **Type:** official_xlsx
- **File:** `csta-k-12-standards-revised-2017.xlsx`

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-csta.R`
- **SHA256:** `ffd136c03795ad9f4a11b083f212848063072f744a6705c203b8be39df754e4e`

### Extracted scales
- **standards count:** 120
- **levels count:** 5
- **clusters count:** 25
- **concepts:** 5
- **practices:** 18

### Licensing
- **source license:** CC BY-NC-SA 4.0
- **license read from:** CSTA's 2017-edition publication page, https://csteachers.org/2017standards/interactive/. The ingested XLSX carries no licence statement in its cells or document properties.
- **citation:** Computer Science Teachers Association (2017). CSTA K-12 Computer Science Standards, Revised 2017. Retrieved from https://csteachers.org/k12standards/.
- **redistribution note:** CC BY-NC-SA 4.0: attribution + non-commercial + share-alike. Commercial toolkit release may not include CSTA text. The share-alike term propagates, so any single file containing CSTA-derived content must itself be offered under CC BY-NC-SA 4.0. Analytical derivatives publishable with attribution.

## CSTA PK-12 CS (`csta-2026`)

- **Publisher:** Computer Science Teachers Association (CSTA)
- **Version:** 2026 CSTA PK-12 Computer Science Standards
- **Version date:** 2026-07

### Source
- **Type:** official_pdf_plus_official_json_api

### Retrieval
- **Retrieved:** 2026-08-21 by `manual staging; tables built by _build_tables.py in this directory`

### Extracted scales
- **standards count:** 331
- **foundational count:** 196
- **specialty count:** 135
- **levels count:** 10
- **foundational concepts:** 5
- **foundational subconcepts:** 18
- **specialty areas:** 7
- **specialty subareas:** 28
- **practices:** 12
- **practice categories:** 4
- **dispositions:** 7
- **organizing units:** 53
- **foundational units:** 40
- **specialty units:** 13
- **boundary statements:** 660
- **implementation examples:** 652
- **standards with examples:** 326
- **ai standards:** 107

### Licensing
- **source license:** CC BY-NC-SA 4.0
- **verified against:** Document's own copyright page (PDF p. iv): 'These Standards are licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License. Accordingly, individuals and organizations are free to download, print, share, and adapt the materials in whole or in part, as long as they provide proper attribution, use for non-commercial purposes, and share contributions or derivations under the same license. Contact standards@csteachers.org for other licensing inquiries.' Every page footer repeats '(c) 2026 Computer Science Teachers Association (CSTA). | CC BY-NC-SA 4.0'. This is the DOCUMENT's license, not merely a site-wide claim (site footer separately says 'All Rights Reserved' -- the document page governs).
- **redistribution note:** CC BY-NC-SA 4.0: attribution + non-commercial + share-alike. Same terms as csta-2017. Commercial toolkit release may not include CSTA standard text; analytical derivatives publishable with attribution under BY-NC-SA. The JSON API capture reproduces standard text and boundary statements: treat it under the same CC BY-NC-SA terms as the PDF (it is the same content, published by CSTA through its own explorer). The crosswalk sheet carries no license stamp of its own; treat conservatively as CSTA-copyright, same-license-presumed but UNVERIFIED.

## Cyber.org K-12 (`cyberorg-k12`)

- **Publisher:** CYBER.ORG & Cyber Innovation Center
- **Version:** Cyber.org K-12 Learning Standards v1.0
- **Version date:** 2021-09-09

### Source
- **Type:** pdf_with_markdown_intermediate
- **File:** `K-12-Cybersecurity-Learning-Standards-v1.0.pdf`

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-cyberorg.R`
- **SHA256:** `a3d2d40ceb76ce7bf9d4dcc061f049351a3fe2ecc4d9514c47839bdd6450798c`

### Extracted scales
- **grade bands:** 4
- **themes:** 3
- **sub concepts:** 29
- **standards total:** 123
- **standards by band:** 3-5=30, 6-8=32, 9-12=31, K-2=30
- **standards by theme:** CS=48, DC=35, SEC=40

### Licensing
- **source license:** CC BY-NC 4.0
- **citation:** K-12 Cybersecurity Learning Standards. (2021). Retrieved from https://cyber.org/standards.
- **reproduction grant:** The source PDF's version-control page adds, separately from the CC licence: 'Authorization to reproduce this report in whole or in part is granted.'
- **redistribution note:** CC BY-NC 4.0 permits non-commercial redistribution with attribution. Toolkit release MUST NOT include standard text in any commercial offering. Analytical derivatives (code frequencies, cross-framework mappings) are safe to publish with attribution.

## CyBOK (`cybok`)

- **Publisher:** NA
- **Version:** CyBOK crosswalk (Tier A: cross-reference data only, not full CyBOK ingestion)
- **Version date:** 2021-10-01

### Source
- **Type:** NA

### Retrieval
- **Retrieved:** 2026-08-14 by `manual extraction, staged for scripts/020-assemble-jsonld.R`

### Extracted scales
- **cybok sfia mapping:** row_count=104, knowledge_area_count=21, distinct_sfia_codes=56
- **cybok ecsf mapping:** row_count=12, roles_with_primary_ka=8, roles_with_no_primary_ka=4

### Licensing
- **source license:** Open Government Licence (Crown Copyright / NCSC 2025) for the CyBOK-ECSF compatibility study; SFIA Foundation site terms for the CyBOK-SFIA mapping table. Verify before any source-text redistribution.
- **redistribution:** Analytical derivatives (the two crosswalk CSVs staged here) treated as safe; full CyBOK Knowledge Area text is out of scope for this Tier A ingest.

## CyQUAL (`cyqual`)

- **Publisher:** CyQUAL / Masaryk University
- **Version:** 1.2.0
- **Version date:** NA

### Source
- **Type:** official_json_open_data_export
- **File:** `cyqual_open_data_en_1.2.0.json`

### Retrieval
- **Retrieved:** 2026-09-16 by `scripts/010-ingest-cyqual.R`
- **SHA256:** `a8c1c64f574264181fb69a35dbb954648784cfedc4d5a117af9178f189741c41`

### Extracted scales
- **categories count:** 7
- **competency groups count:** 4
- **competencies count:** 59
- **specialization areas count:** 37
- **work roles count:** 102
- **tasks count:** 1,168
- **requirements count:** 1,320
- **work role task edges:** 1,889
- **work role requirement edges:** 8,838

### Licensing
- **source license:** Published as open data by CyQUAL (Masaryk University). Derived RDF/JSON-LD graph permitted by written confirmation from the CyQUAL team, 2026-09-16. Attribution to CyQUAL and to Masaryk University required.
- **redistribution:** Source text and derived graph may be redistributed with attribution to CyQUAL and Masaryk University.

## DCWF (`dcwf`)

- **Publisher:** DoD Chief Information Officer (DoD CIO)
- **Version:** DCWF v5.1
- **Version date:** 2025-07-25

### Source
- **Type:** official_xlsx_workbook
- **File:** `dcwf-work-role-tool-v5.1.xlsx`

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-dcwf.R`
- **SHA256:** `19b76ffc58a8cb22baac28ebee40093adde1eaef2c0283a20a6d7b9e51f98a79`

### Extracted scales
- **roles count:** 74
- **master task ksa count:** 2,945
- **per role sheet count:** 74

### Licensing
- **source license:** US Government work, not subject to US copyright (17 U.S.C. 105); no distribution statement found on the artifact
- **redistribution:** A work of the US Government prepared by DoD personnel, so not subject to copyright in the United States. The v5.1 workbook carries no distribution statement across any of its 79 sheets, and the DoD download pages now sit behind authentication, so no download-page statement could be read (checked 2026-09-18). Nine work roles are tagged '(CUI)' in the hyperlink text of the DCWF Roles index sheet; review those sheets before any public deposit of DCWF-derived content, and do not imply DoD endorsement.

## DigComp (`digcomp`)

- **Publisher:** European Commission Joint Research Centre (JRC)
- **Version:** DigComp 3.0
- **Version date:** 2025-11-27

### Source
- **Type:** structured_data_supplement

### Retrieval
- **Retrieved:** 2026-09-21 by `scripts/010-ingest-digcomp.R`

### Extracted scales
- **competence areas:** 5
- **competences:** 21
- **competence statements:** 362
- **learning outcomes pre errata:** 523
- **learning outcomes post errata:** 522
- **proficiency levels staged:** 8
- **glossary terms staged:** 126

### Errata
- **status:** PARTIALLY_APPLIED
- **applied:** E1, E2, E3, E4
- **unapplied:** E5, E6, E7
- **note:** E1 (structural: delete LO2.5.09, renumber 2.5's outcomes down by one) and E2/E3/E4 (exact quoted replacement text) applied verbatim. Errata E5 to E7 are published as instructions without replacement text, so the staged wording is carried unchanged. The learning-outcome count (522) is unaffected: it comes from E1 alone.

### Licensing
- **source license:** CC BY 4.0 (European Union, 2025; Commission Decision 2011/833/EU)
- **citation:** Cosgrove, J. and Cachia, R., DigComp 3.0: The Digital Competence Framework for Citizens, EUR 40491, Publications Office of the European Union, Luxembourg, 2025, ISBN 978-92-68-32677-0, doi:10.2760/0001149. Dataset: doi:10.2905/JRC.FR75K8R.
- **redistribution note:** CC BY 4.0, verified three ways in data/raw/digcomp/v3.0/provenance.yml: the dataset's own copyright.txt, the JRC Data Catalogue record, and the DigComp 3.0 resources page. The European Commission logo is excluded from reuse; cybedtools reproduces no logo.

## ECSF (`ecsf`)

- **Publisher:** ENISA (European Union Agency for Cybersecurity)
- **Version:** ECSF v1
- **Version date:** 2022-09-19

### Source
- **Type:** official_json
- **File:** `ECSF_v1.json`

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-ecsf.R`
- **SHA256:** `7729813fb61957349913dfdabd7b1db71bec2d3862aa79c5095315e366e58502`

### Extracted scales
- **profile count:** 12
- **element count:** 374
- **ecompetence references:** 55
- **element type breakdown:** deliverables=22, key_knowledge=124, key_skills=103, main_tasks=125

### Licensing
- **source license:** Report PDF: CC BY 4.0 (ENISA, 2022, ISBN 978-92-9204-584-5, DOI 10.2824/859537). Ingested JSON and XLSX: no notice stated; ENISA's site-wide notice authorises reproduction with acknowledgement.
- **attribution:** European Union Agency for Cybersecurity (ENISA), European Cybersecurity Skills Framework (ECSF) Role Profiles, September 2022, ISBN 978-92-9204-584-5, DOI 10.2824/859537. (c) ENISA 2022, CC BY 4.0.
- **redistribution:** The Role Profiles report PDF carries its own CC BY 4.0 notice, so content traceable to it may be reused with credit to ENISA and an indication of changes. The JSON and XLSX files this script reads carry no copyright, licence or rights statement of any kind, and rest instead on ENISA's site-wide notice: 'Reproduction of ENISA material published on this website is authorized, provided the source is acknowledged, unless it is stated otherwise.' ENISA's legal notice adds that all references to the publication must contain ENISA as its source.

## NICE (`nice`)

- **Publisher:** NIST (National Institute of Standards and Technology)
- **Version:** NICE v2.2.0 (NIST SP 800-181 Rev 1 components)
- **Version date:** 2026-04-28

### Source
- **Type:** official_cprt_json
- **File:** `v2.2.0/v2-2-0_nf_components.json`

### Retrieval
- **Retrieved:** 2026-08-21 by `scripts/010-ingest-nice.R`
- **SHA256:** `3ad1d9d7e0d6b32895cb569f86c3bc05af2937a68e96eab4d1c9b3d9fa6e575e`

### Extracted scales
- **work roles count:** 42
- **tasks count:** 962
- **knowledge count:** 693
- **skills count:** 556
- **categories count:** 5
- **competency areas count:** 11
- **opm codes count:** 40
- **unique tks count:** 2,211
- **tks associations count:** 5,410
- **competency area ks associations count:** 412
- **role opm mappings count:** 40

### Errata
- **applied:** 1
- **note:** Source-data corrections applied deterministically at ingest. See errata.csv for element ids, published vs corrected values, and rationale.

### Licensing
- **source license:** US public domain (17 U.S.C. 105); foreign rights reserved but granted royalty-free worldwide, incl. derivative works; attribute NIST as source
- **redistribution:** NICE text is a US Government work in the US public domain (17 U.S.C. 105). NIST reserves foreign rights and then grants them back: 'foreign rights are reserved. To the extent NIST may assert rights outside of the United States, the public is granted the non-exclusive, perpetual, paid-up, royalty-free, worldwide right to reprint works in all formats including print, electronically, and online, and in all subsequent editions, and derivative works.' Attribute NIST as the source and do not imply NIST endorsement.

## OTCCF (`otccf`)

- **Publisher:** NA
- **Version:** 1.1
- **Version date:** 2021-10-08

### Source
- **Type:** official_pdf
- **File:** `OT-Cybersecurity-Competency-Framework_V5.pdf`
- **URL:** https://isomer-user-content.by.gov.sg/36/b12cf28f-55fd-4a92-8a57-53403e59fcdc/OT-Cybersecurity-Competency-Framework_V5.pdf

### Retrieval
- **Retrieved:** NA by `cybedtools acquisition job`
- **SHA256:** `fec332ecd81410b98998f538d6b4c534d4fd2eea3804d6a58b78417e827f3028`

### Extracted scales
- **tracks:** 5
- **job roles:** 15
- **role elements:** 347
- **role element breakdown:** critical_work_function=62, key_task=270, performance_expectation=15
- **tscs:** 30
- **tsc category breakdown:** Analyse and Detect=1, Detect=2, Identify=5, Organisational Management=1, Organisational Management and Support=7, Protect=10, Respond and Recover=4
- **tsc level statements:** 1,319
- **tsc level breakdown:** ability=694, knowledge=517, level_description=108
- **tsc statements by level:** level_2=125, level_3=343, level_4=389, level_5=353, level_6=109
- **tsc range of application rows:** 23
- **tsc range of application tscs:** 3
- **role tsc map rows:** 190
- **role critical core skills rows:** 139
- **spot check exact:** 25
- **spot check total:** 25

### Licensing
- **source license:** Copyright Cyber Security Agency of Singapore. Used with written permission of CSA, 2026-09-15, for non-commercial, academic and research purposes.
- **attribution:** Derived from the Operational Technology Cybersecurity Competency Framework (OTCCF), published by the Cyber Security Agency of Singapore (CSA). Available at: https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/
- **permission granted:** 2026-09-15
- **redistribution:** Non-commercial academic and research use only. Any other use requires fresh permission from CSA.
- **terms of use url:** https://www.csa.gov.sg/terms-of-use/
- **landing page copyright verbatim:** © 2026 Government of Singapore

## SCyWF (`scywf`)

- **Publisher:** National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia
- **Version:** SCyWF - 1.5 : 2026
- **Version date:** 2026

### Source
- **Type:** official_pdf

### Retrieval
- **Retrieved:** 2026-09-21 by `manual staging (curl from cdn.nca.gov.sa, URLs located via the NCA English SCyWF landing page)`

### Extracted scales
- **categories:** 5
- **specialty areas:** 12
- **job roles:** 40
- **tasks:** 646
- **knowledge:** 430
- **skills:** 343
- **statements:** 1,419
- **role statement links:** 4,794
- **unresolved card codes:** 0
- **competency areas:** 24
- **role competency area links:** 84
- **hyphenation joins:** 0
- **verbatim checked:** 3,290
- **verbatim found:** 3,290
- **nice shared codes:** 296
- **nice identical text:** 0
- **nice same text any code:** 762

### Licensing
- **source license:** Used with written permission of the National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia, granted 2026-09-20. The document itself carries no copyright line and no licence notice, only the markings "TLP: Clear" and "Document Classification: Public", which are disclosure markings, not licences. Its p.3 disclaimer makes the Arabic version binding for all matters of meaning or interpretation. cybedtools ingests the English version.
- **edition string note:** The title page sets the edition as SCyWF, an en dash, then "1.5: 2026". cybedtools records the edition as SCyWF - 1.5 : 2026 by owner decision.
- **attribution:** The Saudi Cybersecurity Workforce Framework (SCyWF - 1.5 : 2026). Issued by the National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia. Source: https://nca.gov.sa/en/pages/scywf.html
- **status:** full_with_attribution
- **permission granted:** 2026-09-20

## SFIA (`sfia`)

- **Publisher:** NA
- **Version:** SFIA 9
- **Version date:** 2024-10

### Source
- **Type:** third_party_structural_extract
- **Release:** v0.0.1
- **URL:** https://github.com/jankudev/sfia-tools/releases/download/v0.0.1/sfia-sqlite.db

### Retrieval
- **Retrieved:** 2026-05-08 by `scripts/010-ingest-sfia.R`
- **SHA256:** `6223cf50d1b747abd569b040051f163cb563a71a4ce42ffc299ff189310d75e4`

### Extracted scales
- **table row counts:** Skill=147, SkillLevel=672, Level=7, Attribute=16, AttributeType=3, AttributeLevel=112, RelatedSkill=1,117, SkillsProfile=45, SkillsProfileFamily=19, SkillsProfileJobTitle=240, SkillsProfileSkill=563

### Licensing
- **sfia text license:** SFIA Foundation licence required for all use; no redistribution or sub-licensing; local analysis only in cybedtools
- **jankudev license:** None. The jankudev/sfia-tools repository carries no licence file.
- **extract contents:** Not structure only. The extract carries full skill descriptions and guidance notes, per-level descriptors, and attribute descriptions.
- **redistribution note:** All use of SFIA is under licence from the SFIA Foundation. The free Personal and single-country Corporate tiers cover internal use by an individual or a small organisation, which is what running this pipeline locally is. Redistribution and sub-licensing are prohibited at every tier, and the licence covers the concept, content and structure of SFIA, so there is no structure-versus-text carve-out. The extract this script reads is unlicensed and grants nothing. cybedtools publishes no SFIA text and no SFIA structure beyond aggregate counts. Anyone staging SFIA needs their own licence.

## UKCSC (`ukcsc`)

- **Publisher:** UK Cyber Security Council
- **Version:** live site content (framework is unversioned on-site)
- **Version date:** NA

### Source
- **Type:** scraped_html_rsc_payload

### Retrieval
- **Retrieved:** 2026-08-21 by `data/raw/ukcsc/scrape-ukcsc.R`

### Extracted scales
- **specialism count:** 15
- **section count:** 105
- **sections per specialism min:** 6
- **sections per specialism max:** 9
- **pathway edge count:** 48
- **unresolved content refs:** 0
- **extraction issues:** 

### Licensing
- **source license:** ALL RIGHTS RESERVED -- NOT openly licensed. Site terms (https://www.ukcybersecuritycouncil.org.uk/legal/terms-and-conditions, s.11 Intellectual property rights, checked 2026-08-21): 11.1 the Council owns or licenses all IP in site material, all such rights are reserved; 11.2 permits printing one copy / downloading extracts for PERSONAL USE only; 11.3 forbids modifying copies; 11.4 requires attribution; 11.5 forbids commercial use of any content without a licence from the Council. No Creative Commons or Open Government Licence statement appears anywhere on the site (the Council is a private body, not Crown, so OGL does not apply by default).
- **redistribution:** DO NOT redistribute the scraped text (short_text, introduction, content_html/content_text columns) in a released package or public repo -- that exceeds the personal-use extract permission of s.11.2 and, for a published R package, likely trips the commercial-use bar of s.11.5. Structural/analytical derivatives (specialism names, slugs, section titles, the relatedIds pathway graph, counts, mappings created by us) are the defensible layer, analogous to citing a taxonomy. If verbatim framework text is ever needed in a release, seek written permission from the Council first.

## Cross-framework comparison

| Framework | Version | Date | Top-level units | Elements | License |
|---|---|---|---|---|---|
| ASD Cyber Skills Framework | v2 (October 2022, originally v1.0 Jul... | 2022-10-01 | - | - | MIXED, confirmed by direct page-by-pa... |
| CCSSF | 2022 | 2023-04-19 | 59 | 1,222 | Copyright Government of Canada. Refer... |
| CSEC2017 | CSEC2017 Curricular Guidelines v1.0 | 2017-12-31 | 8 | 38 | Copyright 2017 ACM/IEEE/AIS/IFIP, all... |
| CSTA K-12 CS | CSTA K-12 Computer Science Standards ... | 2017 | 25 | 120 | CC BY-NC-SA 4.0 |
| CSTA PK-12 CS | 2026 CSTA PK-12 Computer Science Stan... | 2026-07 | 53 | 331 | CC BY-NC-SA 4.0 |
| Cyber.org K-12 | Cyber.org K-12 Learning Standards v1.0 | 2021-09-09 | 116 | 123 | CC BY-NC 4.0 |
| CyBOK | CyBOK crosswalk (Tier A: cross-refere... | 2021-10-01 | - | - | Open Government Licence (Crown Copyri... |
| CyQUAL | 1.2.0 | NA | 102 | 2,488 | Published as open data by CyQUAL (Mas... |
| DCWF | DCWF v5.1 | 2025-07-25 | 74 | 2,945 | US Government work, not subject to US... |
| DigComp | DigComp 3.0 | 2025-11-27 | 5 | 21 | CC BY 4.0 (European Union, 2025; Comm... |
| ECSF | ECSF v1 | 2022-09-19 | 12 | 374 | Report PDF: CC BY 4.0 (ENISA, 2022, I... |
| NICE | NICE v2.2.0 (NIST SP 800-181 Rev 1 co... | 2026-04-28 | 42 | 2,211 | US public domain (17 U.S.C. 105); for... |
| OTCCF | 1.1 | 2021-10-08 | 15 | 1,612 | Copyright Cyber Security Agency of Si... |
| SCyWF | SCyWF - 1.5 : 2026 | 2026 | 40 | 1,419 | Used with written permission of the N... |
| SFIA | SFIA 9 | 2024-10 | 147 | 672 | SFIA Foundation licence required for ... |
| UKCSC | live site content (framework is unver... | NA | - | - | ALL RIGHTS RESERVED -- NOT openly lic... |

## Verification

Data integrity verification for all frameworks listed here is enforced by `scripts/015-verify-ingestion.R` against `docs/framework-invariants.yml`. Re-run after any ingestion change.

```
Rscript scripts/015-verify-ingestion.R
```

## Downstream pipeline

- `scripts/020-assemble-jsonld.R` assembles the eleven framework JSON-LD documents plus a combined graph at `data/processed/jsonld/_combined.jsonld`.
- `load_combined_rdf_graph()` and the other loaders in `R/rdf-graph.R` load the graph into rdflib.
- `scripts/040-run-sparql.R` runs the package's nine named analyses (q10 through q16) via the helpers in `R/sparql-helpers.R` and writes one CSV per analysis to `data/processed/query-results/`.

