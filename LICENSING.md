# cybedtools licensing notes

This document complements [`LICENSE.md`](LICENSE.md) (which contains the canonical MIT license for the package code). It addresses how licensing applies across the package's three layers: code, framework source text, and analytical outputs.

## TL;DR

If you are using cybedtools for academic research:

- Install the package, run analyses, cite it in your papers, you're fine.
- Code (R helpers, SPARQL templates, scripts) is MIT-licensed. Reuse freely.
- Framework source text is each framework's own license. The package does not redistribute it. You stage source files yourself per [`docs/framework-data-sources.md`](docs/framework-data-sources.md).
- Derivative analytical outputs (counts, comparisons, mappings) are publishable with attribution to the source frameworks, subject to the upstream license.

If you are integrating cybedtools into a commercial product:

- The MIT license on the code accommodates this.
- Framework content is mixed. Some frameworks (NICE, DCWF) are public domain. Others (SFIA, Cyber.org K-12, CSTA, ACM/IEEE, OTCCF) impose non-commercial or attribution constraints. Two (CyQUAL, OTCCF) are included by written permission of their stewards, and CCSSF is referenced as the Canadian Centre for Cyber Security asked. The terms given to cybedtools do not pass to you. Read the per-framework licenses in [`docs/framework-data-sources.md`](docs/framework-data-sources.md) before redistributing framework text. **It is incumbent upon you to obtain proper licensing**.

## Scope of the MIT license

The MIT license in `LICENSE.md` applies to the **code** in this repository: R scripts, SPARQL queries, schema definitions, and supporting infrastructure.

This license does NOT extend to:

- **Framework source text** that users stage under `data/raw/`. Each framework carries its own licensing, recorded in `data/raw/<framework>/provenance.yml` by the ingestion scripts. Notably:
    - **SFIA.** All use of SFIA is under licence from the SFIA Foundation, and the licence covers structure as well as text. The Foundation's General Terms and Conditions define the protected material as "The concept, content and structure of SFIA along with content from the SFIA website" and name "a skills database containing SFIA information" as a royalty-bearing product, so there is no structure-versus-text carve-out. Free tiers cover personal use and single-country corporate internal use. Redistribution and sub-licensing are prohibited at every tier. The third-party extract cybedtools reads carries no licence file and holds no SFIA licence it could pass on, and it does contain full skill descriptions, guidance notes and per-level descriptors. The SFIA portion of cybedtools is local-analysis-only: nothing SFIA beyond aggregate counts is published, and anyone staging SFIA needs their own licence.
    - **Cyber.org K-12.** CC BY-NC 4.0 (attribution, non-commercial), with a separate unconditional grant on the same page: "Authorization to reproduce this report in whole or in part is granted."
    - **CSTA.** CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike). The label is read from CSTA's 2017-edition publication page, because the ingested XLSX carries no licence statement.
    - **CSTA 2026.** CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike), read from the 2026 standards document's own licence page. The same share-alike obligation applies.
    - **SCyWF.** No licence notice on the document. Used by written permission of the National Cybersecurity Authority (NCA), 2026-09-20, on three conditions. NCA is cited as issuing body and source with a link to https://nca.gov.sa/en/pages/scywf.html. Everything taken from the document is carried verbatim. Everything cybedtools derives is marked as derived rather than presented as NCA content.
    - **ECSF.** The Role Profiles report PDF is CC BY 4.0 by its own notice. The JSON and XLSX that cybedtools ingests carry no notice of any kind, and rest instead on ENISA's site-wide notice: "Reproduction of ENISA material published on this website is authorized, provided the source is acknowledged, unless it is stated otherwise."
    - **CSEC2017.** "Copyright © 2017 by ACM, IEEE, AIS, IFIP / ALL RIGHTS RESERVED", with permission granted only "to use these curricular guidelines for the development of educational materials and programs. Other use requires specific permission." cybedtools publishes Knowledge Area names, counts and alignment scores, and no statement text. A permission request to ACM is being prepared.
    - **DigComp 3.0.** CC BY 4.0, verified three ways against the official data supplement's own `copyright.txt`, the JRC Data Catalogue record, and the DigComp 3.0 resources page, with a prescribed citation carried in `docs/framework-data-sources.md`. Replaces DigComp 2.2 in place.
    - **CyBOK.** Open Government Licence v3.0, Crown Copyright NCSC 2021, read from the Introduction to CyBOK's own copyright page. The attribution CyBOK prescribes is carried verbatim: "CyBOK © Crown Copyright, The National Cyber Security Centre 2021, licensed under the Open Government Licence: http://www.nationalarchives.gov.uk/doc/open-government-licence/."
    - **NICE.** A US Government work, not subject to copyright in the United States under 17 U.S.C. 105. NIST reserves foreign rights and grants them back: "foreign rights are reserved. To the extent NIST may assert rights outside of the United States, the public is granted the non-exclusive, perpetual, paid-up, royalty-free, worldwide right to reprint works in all formats including print, electronically, and online, and in all subsequent editions, and derivative works."
    - **DCWF.** A US Government work prepared by DoD personnel, so not subject to US copyright under 17 U.S.C. 105. The v5.1 workbook carries no distribution statement, the DoD download pages now require authentication so none could be read, and nine work roles are tagged "(CUI)" in the workbook's role index. Review those sheets before any public deposit of DCWF-derived content.
- **Framework analyses** produced by running this pipeline on framework source text. Derivative analytical outputs (code frequencies, cross-framework mappings) are generally safe to publish with attribution, but specific licensing turns on the source framework.

When redistributing or building on this toolkit, respect the upstream framework licenses in addition to the MIT license on the code.

## Frameworks included by steward permission

Two frameworks are in cybedtools because their stewards said yes in writing, and the Canadian framework is here referenced as its steward asked. The terms differ, and none of them is as broad as MIT. Full detail, including how to obtain each source, is in [`docs/framework-data-sources.md`](docs/framework-data-sources.md).

**OTCCF, Cyber Security Agency of Singapore.** Derived from the Operational Technology Cybersecurity Competency Framework (OTCCF), published by the Cyber Security Agency of Singapore (CSA). Available at: https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/

The document names Mercer Singapore as a joint developer alongside CSA, with SkillsFuture Singapore and the Infocomm Media Development Authority as supporters. Whether Mercer holds any interest that CSA's permission does not reach is unresolved.

CSA's permission is for referencing and integrating the OTCCF's structure, for non-commercial, academic and research purposes, and it requires that the ingestion scripts and structural mappings not misrepresent or alter the intent of the OTCCF's job roles, skills, or competency mappings as published by CSA. cybedtools makes public only the OTCCF's structure (roles, skill titles, categories, proficiency levels, role-to-skill mappings) and not its statement text. Eight of its thirty skills and all of its Critical Core Skills originate with SkillsFuture Singapore, and the graph marks them. Commercial use of the OTCCF portion is outside what CSA granted.

**CCSSF, Canadian Centre for Cyber Security.** Canadian Centre for Cyber Security, The Canadian Cyber Security Skills Framework (ITSM.00.039), 2022 edition. Copyright Government of Canada. Referenced as the Canadian Centre for Cyber Security asked. The Centre asks that its material be referenced when used.

**CyQUAL, Masaryk University.** CyQUAL, the Czech national cybersecurity qualifications framework, developed at Masaryk University. Open data, version 1.2.0, https://platform.cyqual.cz/. Published as open data. Attribution to CyQUAL and to Masaryk University is required.

Each attribution statement also travels in the graph itself, as `schema:creditText` on the framework node, so anything built from the graph carries it.

## Combined graphs

Building the combined graph on your own machine and querying it there triggers none of this. No distribution occurs, so no framework's redistribution terms are engaged.

Publishing a single combined graph file under one licence is not possible, for two independent reasons. CSTA's CC BY-NC-SA 4.0 carries a share-alike obligation, and a file containing CSTA-derived content would have to go out under CC BY-NC-SA 4.0 in its entirety, dragging the public-domain NICE and DCWF content and the CC BY DigComp and ECSF content under terms their stewards never asked for. And four sources cannot be licensed onward by the package author at all: SFIA, CSEC2017 statement text, OTCCF statement text, and CCSSF.

Any public distribution of the graph is therefore one file per framework, each under its own terms, with a manifest stating the licence per file. Users who want a combined graph merge the files locally. For a Zenodo deposit, which forces one licence per record, put the per-file licences in the record description and let any machine-readable record licence describe only the code and the manifest.
