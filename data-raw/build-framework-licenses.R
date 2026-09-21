# data-raw/build-framework-licenses.R
#
# Builds data/framework_licenses.rda, the single owner of licence facts for
# the package: one row for the package's own code, one row per framework.
#
# Run when a framework's terms are re-read from its source, when a steward
# revises what it granted, or when a framework is added. End-users never run
# this script. They consume the resulting tibble via
# cybedtools::framework_licenses or cybed_license().
#
# Unlike data-raw/build-framework-summary.R this script needs no staged
# graph: every value here is read from a source's own document, licence
# file, or published terms page. The `verified` column records the date the
# terms were last read from the source.
#
# Rules this file follows, and that any edit must keep following:
#
#   - `license` quotes what the source itself says, verbatim or as a faithful
#     close quotation, and names the document or page it was read from.
#     Where a source says nothing, the row says that it says nothing.
#   - `attribution` is verbatim where the steward prescribed wording. Where a
#     licence requires credit but the steward prescribes none, the row may
#     carry a minimal attribution composed here, and the `license` cell must
#     say so. It is NA where neither applies. A steward's wording is never
#     invented or paraphrased.
#   - `granted` is TRUE only where a steward gave cybedtools specific written
#     permission. An open licence is not a grant to cybedtools.
#   - `public_redistribution` must agree with docs/framework-invariants.yml,
#     where a framework carrying no `public_redistribution` key means
#     "unrestricted". The test suite asserts this.
#   - Only public sources are cited: terms URLs and document titles.

suppressPackageStartupMessages({
  library(tibble)
})

if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(quiet = TRUE)
} else {
  library(cybedtools)
}

framework_licenses <- tibble::tribble(
  ~layer, ~slug, ~framework_name, ~license_short, ~license, ~attribution, ~public_redistribution, ~terms_url, ~granted, ~verified,

  "code", "cybedtools", "cybedtools (R package code)",
  "MIT",
  paste0(
    "LICENSE.md, the package's own licence file: \"MIT License / Copyright ",
    "(c) 2026 Ryan Straight / Permission is hereby granted, free of charge, ",
    "to any person obtaining a copy of this software and associated ",
    "documentation files (the \"Software\"), to deal in the Software without ",
    "restriction...\" The MIT licence covers the code in this repository ",
    "only. It does not reach any framework's source text, which carries the ",
    "framework's own terms."
  ),
  "Copyright (c) 2026 Ryan Straight. MIT License.",
  "unrestricted",
  "https://github.com/ryanstraight/cybedtools/blob/main/LICENSE.md",
  FALSE, as.Date("2026-09-19"),

  "framework", "nice-v2", "NICE v2.2.0",
  "US public domain + NIST worldwide grant",
  paste0(
    "The ingested CPRT JSON carries no rights statement, so NIST's published ",
    "statements govern. NIST, \"Copyright, Fair Use, and Licensing ",
    "Statements for SRD, Data, Software and Technical Series Publications\", ",
    "Technical Series section: \"Works authored by NIST employees are not ",
    "subject to Copyright protection within the United States; foreign ",
    "rights are reserved. To the extent NIST may assert rights outside of ",
    "the United States, the public is granted the non-exclusive, perpetual, ",
    "paid-up, royalty-free, worldwide right to reprint works in all formats ",
    "including print, electronically, and online, and in all subsequent ",
    "editions, and derivative works.\" NIST's copyright page adds that \"Use ",
    "of appropriate byline/photo/image credits is requested.\""
  ),
  NA_character_,
  "unrestricted",
  "https://www.nist.gov/open/copyright-fair-use-and-licensing-statements-srd-data-software-and-technical-series-publications",
  FALSE, as.Date("2026-09-18"),

  "framework", "dcwf-v5.1", "DCWF v5.1",
  "US Government work, no US copyright",
  paste0(
    "The DoD Cyber Workforce Framework Work Role Tool v5.1 workbook carries ",
    "no rights or distribution statement in any of its 79 sheets, and the ",
    "DoD download pages sit behind authentication, so no download-page ",
    "statement could be read as of 2026-09-18. The governing position is ",
    "therefore inferred rather than quoted: a work of the US Government ",
    "prepared by DoD personnel is not subject to copyright in the United ",
    "States under 17 U.S.C. 105. Nine work roles carry a \"(CUI)\" tag in ",
    "the workbook's role index; review those sheets before any public ",
    "deposit of DCWF-derived content."
  ),
  NA_character_,
  "unrestricted",
  "https://www.cyberworkforce.mil/Department-Cyber-Workforce-Framework/",
  FALSE, as.Date("2026-09-18"),

  "framework", "ecsf-v1", "ECSF v1",
  "CC BY 4.0 (report); data files unmarked",
  paste0(
    "Two things are true. The ECSF Role Profiles report PDF (September ",
    "2022, ISBN 978-92-9204-584-5, DOI 10.2824/859537) carries its own ",
    "copyright notice: \"(c) European Union Agency for Cybersecurity ",
    "(ENISA), 2022 / This publication is licenced under CC-BY 4.0 ... the ",
    "reuse of this document is authorised under the Creative Commons ",
    "Attribution 4.0 International (CC BY 4.0) licence\", and its legal ",
    "notice adds \"All references to it or its use as a whole or partially ",
    "must contain ENISA as its source.\" The JSON and XLSX files cybedtools ",
    "ingests carry no notice of any kind, and rest instead on ENISA's ",
    "site-wide legal notice: \"Reproduction of ENISA material published on ",
    "this website is authorized, provided the source is acknowledged, unless ",
    "it is stated otherwise.\" ENISA prescribes no citation wording for the ",
    "report or the data files, so the attribution below is the package's own ",
    "and follows what the CC BY 4.0 licence requires."
  ),
  paste0(
    "European Union Agency for Cybersecurity (ENISA), European Cybersecurity ",
    "Skills Framework (ECSF) Role Profiles, September 2022, ISBN ",
    "978-92-9204-584-5, DOI 10.2824/859537. (c) ENISA 2022, licensed under ",
    "CC BY 4.0. Source: https://www.enisa.europa.eu/publications/",
    "european-cybersecurity-skills-framework-role-profiles"
  ),
  "full_with_attribution",
  "https://www.enisa.europa.eu/publications/european-cybersecurity-skills-framework-role-profiles",
  FALSE, as.Date("2026-09-19"),

  "framework", "sfia-9", "SFIA 9",
  "SFIA Foundation licence required",
  paste0(
    "SFIA Foundation, \"Using and licensing SFIA\": \"Note: All use of SFIA ",
    "is under licence.\" / \"The SFIA Framework, guidance and support assets ",
    "are the intellectual property of the SFIA Foundation.\" / \"Copying of ",
    "this material is prohibited unless authorised in writing or under a ",
    "valid SFIA licence obtained from the SFIA Foundation.\" The SFIA ",
    "General Terms and Conditions define the protected material as \"The ",
    "concept, content and structure of SFIA along with content from the ",
    "SFIA website\", and name \"a skills database containing SFIA ",
    "information\" as a royalty-bearing dependent product, so there is no ",
    "structure-versus-text carve-out. The third-party structural extract ",
    "cybedtools reads carries no licence file of any kind and holds no SFIA ",
    "licence it could pass on. SFIA content in cybedtools is local-analysis ",
    "only; nothing beyond aggregate counts is published."
  ),
  NA_character_,
  "local_only",
  "https://sfia-online.org/en/about-sfia/licensing-sfia/using-and-licensing-sfia",
  FALSE, as.Date("2026-09-18"),

  "framework", "cyberorg-k12-v1.0", "Cyber.org K-12 v1.0",
  "CC BY-NC 4.0",
  paste0(
    "From the K-12 Cybersecurity Learning Standards PDF's own ",
    "version-control page: \"K-12 Cybersecurity Learning Standards (c) 2021 ",
    "by Cyber Innovation Center & CYBER.ORG is licensed under Creative ",
    "Commons Attribution-NonCommercial 4.0 International\". The same page ",
    "carries a separate and unconditional grant alongside the licence: ",
    "\"Authorization to reproduce this report in whole or in part is ",
    "granted.\" The cyber.org/standards page itself states no terms, so the ",
    "PDF is the only source."
  ),
  "K-12 Cybersecurity Learning Standards. (2021). Retrieved from https://cyber.org/standards.",
  "full_with_attribution",
  "https://creativecommons.org/licenses/by-nc/4.0/",
  FALSE, as.Date("2026-09-18"),

  "framework", "csta-2017", "CSTA K-12 CS (Rev 2017)",
  "CC BY-NC-SA 4.0",
  paste0(
    "The ingested XLSX carries no licence statement, so the label is read ",
    "from CSTA's 2017-edition publication page: \"These Standards are ",
    "licensed under the Creative Commons ",
    "Attribution-NonCommercial-ShareAlike 4.0 International License (CC ",
    "BY-NC-SA 4.0).\" The share-alike term propagates: any file containing ",
    "CSTA-derived content must itself go out under CC BY-NC-SA 4.0, which is ",
    "why cybedtools publishes one graph file per framework rather than one ",
    "combined file."
  ),
  "Computer Science Teachers Association (2017). CSTA K-12 Computer Science Standards, Revised 2017. Retrieved from https://csteachers.org/k12standards/.",
  "full_with_attribution",
  "https://creativecommons.org/licenses/by-nc-sa/4.0/",
  FALSE, as.Date("2026-09-18"),

  "framework", "csta-2026", "CSTA PK-12 CS (2026)",
  "CC BY-NC-SA 4.0",
  paste0(
    "From the 2026 CSTA PK-12 Computer Science Standards PDF's own licence ",
    "page (p. iv): \"These Standards are licensed under the Creative Commons ",
    "Attribution-NonCommercial-ShareAlike 4.0 International License. ",
    "Accordingly, individuals and organizations are free to download, print, ",
    "share, and adapt the materials in whole or in part, as long as they ",
    "provide proper attribution, use for non-commercial purposes, and share ",
    "contributions or derivations under the same license.\" Every page ",
    "footer repeats \"CC BY-NC-SA 4.0\". cybedtools ingests the JSON behind ",
    "CSTA's interactive Standards Explorer, which carries the same standard ",
    "text and is published by CSTA, so it is treated under the same terms. ",
    "The share-alike term propagates to any file containing CSTA-derived ",
    "content. The attribution below is the PDF's own suggested citation and ",
    "DOI, with the en dash in PK-12 rendered as a hyphen."
  ),
  "Computer Science Teachers Association. (2026). 2026 CSTA PK-12 computer science standards. https://csteachers.org/pk12standards/ DOI: https://doi.org/10.1145/3820482",
  "full_with_attribution",
  "https://creativecommons.org/licenses/by-nc-sa/4.0/",
  FALSE, as.Date("2026-09-21"),

  "framework", "csec2017-v1", "ACM/IEEE CSEC2017",
  "All rights reserved; educational use",
  paste0(
    "From the CSEC2017 Curricular Guidelines PDF's own copyright page: ",
    "\"Copyright (c) 2017 by ACM, IEEE, AIS, IFIP / ALL RIGHTS RESERVED / ",
    "Copyright and Reprint Permissions: Permission is granted to use these ",
    "curricular guidelines for the development of educational materials and ",
    "programs. Other use requires specific permission.\" (ISBN ",
    "978-1-4503-5278-9, DOI 10.1145/3184594.) The grant is limited by ",
    "purpose rather than by who may use it, and it does not extend to ",
    "republishing the guidelines themselves, so cybedtools publishes ",
    "Knowledge Area names, counts and alignment scores and no statement text."
  ),
  NA_character_,
  "structure_only",
  "https://cybered.acm.org/",
  FALSE, as.Date("2026-09-18"),

  "framework", "digcomp-3.0", "DigComp 3.0",
  "CC BY 4.0",
  paste0(
    "From the copyright notice distributed with the official DigComp 3.0 ",
    "data supplement (JRC144121, ISBN 978-92-68-32677-0): \"(c) European ",
    "Union, 1995-2026 / The Commission's reuse policy is implemented by the ",
    "Commission Decision of 12 December 2011 on the reuse of Commission ",
    "documents. Any copyright and/or sui generis right on the dataset is ",
    "licensed under the Creative Commons Attribution 4.0 International (CC ",
    "BY 4.0) licence. Reuse is allowed provided appropriate credit is given ",
    "and any changes are indicated.\" Also confirmed on the JRC Data ",
    "Catalogue record (DOI 10.2905/JRC.FR75K8R) and the DigComp 3.0 ",
    "resources page, which additionally excludes the European Commission ",
    "logo from reuse; cybedtools reproduces no logo."
  ),
  "Cosgrove, J. and Cachia, R., DigComp 3.0: The Digital Competence Framework for Citizens, EUR 40491, Publications Office of the European Union, Luxembourg, 2025, ISBN 978-92-68-32677-0, doi:10.2760/0001149. Dataset: doi:10.2905/JRC.FR75K8R.",
  "full_with_attribution",
  "https://creativecommons.org/licenses/by/4.0/",
  FALSE, as.Date("2026-09-21"),

  "framework", "cyqual-v1.2.0", "CyQUAL 1.2.0",
  "Open data, attribution required",
  paste0(
    "The open-data JSON export carries no rights field of any kind. The ",
    "CyQUAL team at Masaryk University confirmed in writing on 2026-09-16 ",
    "that the framework is published as open data and publicly available, ",
    "that a derived RDF/JSON-LD graph may be built from the export, and that ",
    "the only condition is attribution to CyQUAL and to Masaryk University."
  ),
  "CyQUAL, the Czech national cybersecurity qualifications framework, developed at Masaryk University. Open data, version 1.2.0, https://platform.cyqual.cz/.",
  "full_with_attribution",
  "https://platform.cyqual.cz/en",
  TRUE, as.Date("2026-09-18"),

  # CCSSF. The steward's written reply said only that the material is
  # copyrighted under the Government of Canada and should be referenced when
  # used. That is an instruction about referencing, not an affirmative grant,
  # so `granted` is FALSE and no column in this row claims otherwise. Decided
  # 2026-09-19: public text must not characterise the reply as more than it
  # was until the steward confirms. Statement text stays unpublished.
  "framework", "ccssf-2022", "CCSSF 2022",
  "Government of Canada copyright",
  paste0(
    "The Canadian Cyber Security Skills Framework (ITSM.00.039) carries no ",
    "licence notice of any kind: a sweep of the document finds no copyright ",
    "line, no Creative Commons statement, no Open Government Licence ",
    "reference and no all-rights-reserved statement. It carries only the ",
    "Government of Canada publication identifiers (ISBN 978-0-660-46231-8, ",
    "Cat. No. D97-4/00-039-2022E-PDF). The Canadian Centre for Cyber ",
    "Security states that its material is copyrighted under the Government ",
    "of Canada and should be referenced when used. The document is marked ",
    "\"TLP:CLEAR\" and \"UNCLASSIFIED / NON CLASSIFIE\" on every page; both ",
    "are disclosure markings rather than copyright licences, so neither ",
    "widens what may be republished. Do not assume the Open Government ",
    "Licence applies."
  ),
  paste0(
    "Canadian Centre for Cyber Security, The Canadian Cyber Security Skills ",
    "Framework (ITSM.00.039), 2022 edition. Copyright Government of Canada. ",
    "Referenced as the Canadian Centre for Cyber Security asked."
  ),
  "structure_only",
  "https://www.cyber.gc.ca/en/publications",
  FALSE, as.Date("2026-09-18"),

  "framework", "otccf-v1.1", "OTCCF v1.1",
  "CSA copyright; non-commercial academic",
  paste0(
    "\"(c) Cyber Security Agency of Singapore\" appears on every page of the ",
    "Operational Technology Cybersecurity Competency Framework PDF, and the ",
    "document carries no licence beyond that copyright line. The Cyber ",
    "Security Agency of Singapore granted cybedtools written permission on ",
    "2026-09-15 to reference and integrate the OTCCF's structure for ",
    "non-commercial, academic and research purposes, on two conditions: the ",
    "attribution wording below word for word, and that the ingestion scripts ",
    "and structural mappings not misrepresent or alter the intent of the ",
    "OTCCF's job roles, skills, or competency mappings as published by CSA. ",
    "The grant covers structure only: roles, skill titles, categories, ",
    "proficiency levels and role-to-skill mappings, not statement text. The ",
    "document names Mercer Singapore as a joint developer; whether Mercer ",
    "holds any interest CSA's grant does not reach is unresolved."
  ),
  "Derived from the Operational Technology Cybersecurity Competency Framework (OTCCF), published by the Cyber Security Agency of Singapore (CSA). Available at: https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/",
  "structure_only",
  "https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/",
  TRUE, as.Date("2026-09-18"),

  # SCyWF. NCA's written grant of 2026-09-20 covers the full content with
  # attribution, on three conditions recorded below. NCA prescribed no
  # attribution wording, so the attribution is composed here from what the
  # grant requires: NCA named as issuing body and source, with the official
  # page link.
  "framework", "scywf-1.5", "SCyWF 1.5",
  "NCA written permission",
  paste0(
    "The Saudi Cybersecurity Workforce Framework (SCyWF – 1.5: 2026) PDF ",
    "carries no copyright line and no licence notice. Its only markings are ",
    "\"TLP: Clear\" and \"Document Classification: Public\", which are ",
    "disclosure markings rather than licences. The National Cybersecurity ",
    "Authority (NCA) of the Kingdom of Saudi Arabia granted cybedtools ",
    "written permission on 2026-09-20 to ingest and redistribute the ",
    "framework's content, on three conditions. (1) NCA is cited as issuing ",
    "body and source, with a link to the official SCyWF page. (2) Everything ",
    "taken from the document (identifiers, titles, statement text) is ",
    "carried verbatim, with no normalised labels, paraphrase, in-house ",
    "translation or composed text presented as NCA content. (3) Anything ",
    "cybedtools derives, such as hierarchy edges or cross-framework ",
    "mappings, is marked as derived and not presented as NCA content. NCA ",
    "prescribed no ",
    "attribution wording, so the attribution below is composed to meet the ",
    "first condition. The grant named an earlier edition (SCyWF - 1 : 2020) ",
    "that NCA no longer publishes. The current edition is ingested by owner ",
    "decision. The document's own disclaimer makes its Arabic version ",
    "binding for matters of meaning and interpretation. cybedtools ingests ",
    "the English version."
  ),
  "The Saudi Cybersecurity Workforce Framework (SCyWF – 1.5: 2026). Issued by the National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia. Source: https://nca.gov.sa/en/pages/scywf.html",
  "full_with_attribution",
  "https://nca.gov.sa/en/pages/scywf.html",
  TRUE, as.Date("2026-09-21"),

  # CyBOK. An open licence, so no grant. The attribution is the wording the
  # Introduction's copyright page prescribes, word for word, including its
  # http link. terms_url is the https address of the same licence.
  "framework", "cybok-v1.1.0", "CyBOK v1.1.0",
  "OGL v3.0",
  paste0(
    "From the copyright page of the Introduction to CyBOK Knowledge Area, ",
    "Version 1.1.0 (July 2021): \"© Crown Copyright, The National Cyber ",
    "Security Centre 2021. This information is licensed under the Open ",
    "Government Licence v3.0.\" The same page prescribes the attribution ",
    "below. The A-to-Z Indicative Material document and each Knowledge Tree ",
    "carry the same Crown Copyright and Open Government Licence v3.0 notice. ",
    "The Open Government Licence v3.0 permits copying, ",
    "publishing, adapting and commercial use on the condition of attribution."
  ),
  "CyBOK © Crown Copyright, The National Cyber Security Centre 2021, licensed under the Open Government Licence: http://www.nationalarchives.gov.uk/doc/open-government-licence/.",
  "full_with_attribution",
  "https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/",
  FALSE, as.Date("2026-09-21")
)

# Integrity checks. These duplicate the test suite deliberately: the build
# must refuse to write a bad object, not merely fail a test afterwards.
allowed_redistribution <- c("unrestricted", "full_with_attribution",
                            "structure_only", "local_only")

stopifnot(
  "exactly one code row is expected" =
    sum(framework_licenses$layer == "code") == 1L,
  "layer must be either code or framework" =
    all(framework_licenses$layer %in% c("code", "framework")),
  "slugs must be unique" = !anyDuplicated(framework_licenses$slug),
  "no NA values outside the attribution column" =
    !any(is.na(framework_licenses[setdiff(names(framework_licenses),
                                          "attribution")])),
  "public_redistribution must use the declared vocabulary" =
    all(framework_licenses$public_redistribution %in% allowed_redistribution),
  "license_short must be non-empty and under 40 characters" =
    all(nzchar(framework_licenses$license_short)) &&
    all(nchar(framework_licenses$license_short) < 40L),
  "every terms_url must be https" =
    all(grepl("^https://", framework_licenses$terms_url)),
  "the CCSSF row must not claim permission" =
    !any(grepl("permission",
               unlist(framework_licenses[framework_licenses$slug == "ccssf-2022", ]),
               ignore.case = TRUE))
)

# The framework rows must cover exactly the shipped framework_summary slugs.
# Checked here as well as in the tests so a rebuild of either object cannot
# quietly drift from the other, in the direction that can break a release.
if (exists("framework_summary")) {
  fw_slugs <- framework_licenses$slug[framework_licenses$layer == "framework"]
  missing_license <- setdiff(framework_summary$framework_slug, fw_slugs)
  missing_summary <- setdiff(fw_slugs, framework_summary$framework_slug)
  # A licence row with no summary row yet is the expected state while a
  # framework is being added: this object is built first, because the
  # summary build derives its licence column from it and refuses a framework
  # without a licence row. That direction is reported, not fatal. The summary
  # build and the test suite both require the two to agree exactly after.
  if (length(missing_license) > 0L) {
    stop(
      "framework_licenses has no row for shipped framework_summary ",
      "framework(s): ", paste(missing_license, collapse = ", "),
      call. = FALSE
    )
  }
  if (length(missing_summary) > 0L) {
    message(
      "Licence row(s) with no framework_summary row yet: ",
      paste(missing_summary, collapse = ", "),
      ". Rebuild data-raw/build-framework-summary.R next."
    )
  }
}

if (!dir.exists("data")) dir.create("data")
save(framework_licenses, file = "data/framework_licenses.rda", compress = "xz")

cat("Wrote data/framework_licenses.rda\n")
print(framework_licenses[, c("layer", "slug", "license_short",
                             "public_redistribution", "granted", "verified")],
      n = 20, width = 200)
