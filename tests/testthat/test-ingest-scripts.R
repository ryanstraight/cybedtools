# Tests for pure helper functions defined in scripts/010-ingest-*.R.
#
# The ingestion scripts guard their pipelines behind `if (sys.nframe() == 0)
# main()`, so source()-ing one from a test loads its helper functions
# without touching data/raw or running the pipeline. Fixtures below are
# fully synthetic -- no staged framework data is read.
#
# scripts/ is .Rbuildignore'd, so these tests skip under R CMD check on the
# built tarball and run under devtools::test() in the source tree.

source_ingest_script <- function(name, required_pkgs = character(0)) {
  for (pkg in required_pkgs) {
    testthat::skip_if_not_installed(pkg)
  }
  path <- testthat::test_path("..", "..", "scripts", name)
  if (!file.exists(path)) {
    testthat::skip(paste0(name, " not available (built-tarball check)"))
  }
  env <- new.env(parent = globalenv())
  suppressPackageStartupMessages(
    suppressWarnings(source(path, local = env))
  )
  env
}

nice_pkgs <- c("jsonlite", "readr", "yaml", "digest", "stringr")
ecsf_pkgs <- c("jsonlite", "readr", "yaml", "digest", "stringr")
dcwf_pkgs <- c("readxl", "readr", "yaml", "digest", "stringr")

# ---------------------------------------------------------------------------
# NICE (010-ingest-nice.R): relationship direction + element extraction
# ---------------------------------------------------------------------------

# Hand-built CPRT fixture mirroring the v2.2.0 export shape: one work
# role, one task, one knowledge statement, one category, one competency
# area, one opm_code, with the relationship directions the real export
# uses (work_role -> task projection; category -> work_role membership;
# competency_area -> K/S membership; work_role -> opm_code). The real
# v2.2.0 doc_identifier is SP_800_181_2_2_0 (changed from
# SP_800_181_rev_1 in the v2.0.0-era export).
make_nice_cprt <- function(reverse = FALSE) {
  wr_task <- list(
    source_element_identifier = "WRL-001",
    dest_element_identifier   = "T0001",
    relationship_identifier   = "projection"
  )
  cat_wr <- list(
    source_element_identifier = "CAT-01",
    dest_element_identifier   = "WRL-001",
    relationship_identifier   = "member_of"
  )
  ca_k <- list(
    source_element_identifier = "NF-COM-001",
    dest_element_identifier   = "K0001",
    relationship_identifier   = "member_of"
  )
  wr_opm <- list(
    source_element_identifier = "WRL-001",
    dest_element_identifier   = "652",
    relationship_identifier   = "reference"
  )
  if (reverse) {
    wr_task <- list(
      source_element_identifier = "T0001",
      dest_element_identifier   = "WRL-001",
      relationship_identifier   = "projection"
    )
    cat_wr <- list(
      source_element_identifier = "WRL-001",
      dest_element_identifier   = "CAT-01",
      relationship_identifier   = "member_of"
    )
    ca_k <- list(
      source_element_identifier = "K0001",
      dest_element_identifier   = "NF-COM-001",
      relationship_identifier   = "member_of"
    )
    wr_opm <- list(
      source_element_identifier = "652",
      dest_element_identifier   = "WRL-001",
      relationship_identifier   = "reference"
    )
  }
  list(
    elements = list(
      list(element_identifier = "WRL-001", element_type = "work_role",
           title = "Test Role", text = "Role text",
           doc_identifier = "SP_800_181_2_2_0"),
      list(element_identifier = "T0001", element_type = "task",
           title = NULL, text = "Task text",
           doc_identifier = "SP_800_181_2_2_0"),
      list(element_identifier = "K0001", element_type = "knowledge",
           title = NULL, text = "Knowledge text",
           doc_identifier = "SP_800_181_2_2_0"),
      list(element_identifier = "CAT-01", element_type = "category",
           title = "Test Category", text = "Category text",
           doc_identifier = "SP_800_181_2_2_0"),
      list(element_identifier = "NF-COM-001", element_type = "competency_area",
           title = "Test Competency Area", text = "Competency area text",
           doc_identifier = "SP_800_181_2_2_0"),
      list(element_identifier = "652", element_type = "opm_code",
           title = NULL, text = NULL,
           doc_identifier = "SP_800_181_2_2_0")
    ),
    relationships = list(wr_task, cat_wr, ca_k, wr_opm)
  )
}

test_that("NICE relationship directions are locked in: role->TKS and category->role", {
  # build_role_tks_associations assumes work_role is the SOURCE of a TKS
  # projection; build_role_categories assumes category is the source and
  # the role the DESTINATION. Opposite directions, and nothing else in the
  # pipeline would catch a silent flip -- a reversed relationship must
  # yield zero rows from both.
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)
  cprt <- make_nice_cprt()

  work_roles <- env$extract_elements_of_type(cprt, "work_role")
  tasks      <- env$extract_elements_of_type(cprt, "task")
  categories <- env$extract_elements_of_type(cprt, "category")
  rels       <- env$extract_relationships(cprt)

  assoc <- env$build_role_tks_associations(rels, work_roles, tasks)
  expect_equal(nrow(assoc), 1L)
  expect_equal(assoc$work_role_id,    "WRL-001")
  expect_equal(assoc$work_role_title, "Test Role")
  expect_equal(assoc$statement_id,    "T0001")
  expect_equal(assoc$statement_type,  "task")
  expect_equal(assoc$statement_text,  "Task text")

  cats <- env$build_role_categories(rels, work_roles, categories)
  expect_equal(nrow(cats), 1L)
  expect_equal(cats$work_role_id, "WRL-001")
  expect_equal(cats$category_id,  "CAT-01")

  # Reversed relationships: both builders must return zero rows, not the
  # same rows with columns swapped.
  rels_rev <- env$extract_relationships(make_nice_cprt(reverse = TRUE))
  expect_equal(nrow(env$build_role_tks_associations(rels_rev, work_roles, tasks)), 0L)
  expect_equal(nrow(env$build_role_categories(rels_rev, work_roles, categories)), 0L)
})

test_that("NICE v2.2.0 competency-area and OPM-code builders follow their locked directions", {
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)
  cprt <- make_nice_cprt()

  work_roles <- env$extract_elements_of_type(cprt, "work_role")
  knowledge  <- env$extract_elements_of_type(cprt, "knowledge")
  comp_areas <- env$extract_elements_of_type(cprt, "competency_area")
  opm_codes  <- env$extract_elements_of_type(cprt, "opm_code")
  rels       <- env$extract_relationships(cprt)

  # competency_area is the SOURCE of a K/S membership.
  ca_ks <- env$build_comp_area_ks_associations(rels, comp_areas, knowledge)
  expect_equal(nrow(ca_ks), 1L)
  expect_equal(ca_ks$competency_area_id,    "NF-COM-001")
  expect_equal(ca_ks$competency_area_title, "Test Competency Area")
  expect_equal(ca_ks$statement_id,          "K0001")
  expect_equal(ca_ks$statement_type,        "knowledge")

  # work_role is the SOURCE of an opm_code reference.
  role_opm <- env$build_role_opm_codes(rels, work_roles, opm_codes)
  expect_equal(nrow(role_opm), 1L)
  expect_equal(role_opm$work_role_id, "WRL-001")
  expect_equal(role_opm$opm_code,     "652")

  # Reversed relationships must yield zero rows from both.
  rels_rev <- env$extract_relationships(make_nice_cprt(reverse = TRUE))
  expect_equal(nrow(env$build_comp_area_ks_associations(rels_rev, comp_areas, knowledge)), 0L)
  expect_equal(nrow(env$build_role_opm_codes(rels_rev, work_roles, opm_codes)), 0L)
})

test_that("NICE apply_errata patches a matching row and stops on published-value drift", {
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)

  errata <- tibble::tibble(
    element_id      = "IN",
    field           = "text",
    published_value = "Wrong upstream text",
    corrected_value = "Correct text",
    rationale       = "test",
    source          = "test"
  )
  tbl <- tibble::tibble(
    element_id = c("IN", "OG"),
    text       = c("Wrong upstream text", "Untouched text")
  )

  patched <- suppressMessages(env$apply_errata(tbl, errata, "categories"))
  expect_equal(patched$text[patched$element_id == "IN"], "Correct text")
  expect_equal(patched$text[patched$element_id == "OG"], "Untouched text")

  # A table without the target element passes through unchanged.
  other <- tibble::tibble(element_id = "T0001", text = "Task text")
  expect_identical(suppressMessages(env$apply_errata(other, errata, "tasks")), other)

  # If the source no longer matches published_value (upstream fixed or
  # revised), the erratum is stale and must fail loudly, not reapply.
  drifted <- tibble::tibble(element_id = "IN", text = "Upstream fixed this")
  expect_error(
    suppressMessages(env$apply_errata(drifted, errata, "categories")),
    "Erratum mismatch"
  )
})

test_that("NICE shipped errata table matches the live IN category erratum", {
  # The in-script errata definition is the single source of truth; pin its
  # shape and the one known row so accidental edits surface here.
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)
  errata <- env$nice_errata
  expect_named(errata, c("element_id", "field", "published_value",
                         "corrected_value", "rationale", "source"))
  expect_true("IN" %in% errata$element_id)
  in_row <- errata[errata$element_id == "IN", ]
  expect_equal(in_row$field, "text")
  expect_match(in_row$published_value, "foreign actors")
  expect_match(in_row$corrected_value, "cybercrime investigations")
})

test_that("NICE extract_elements_of_type handles NULL fields and squishes whitespace", {
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)
  cprt <- list(elements = list(
    list(element_identifier = "T0002", element_type = "task",
         title = NULL, text = "  spaced   text ", doc_identifier = "doc")
  ))
  out <- env$extract_elements_of_type(cprt, "task")
  expect_equal(nrow(out), 1L)
  expect_true(is.na(out$title))
  expect_equal(out$text, "spaced text")
})

test_that("NICE extract_elements_of_type returns a schema-stable empty tibble on zero matches", {
  # map_dfr() over an empty list returns 0 rows AND 0 columns, silently
  # losing the schema and breaking downstream bind_rows()/select().
  # Fixed 2026-08-20: a zero-match type now returns 0 rows with all 5
  # columns intact.
  # "sort" elements exist in the real export but are never extracted; the
  # fixture omits them entirely, so this exercises the zero-match path.
  env <- source_ingest_script("010-ingest-nice.R", nice_pkgs)
  cprt <- make_nice_cprt()
  out <- env$extract_elements_of_type(cprt, "sort")
  expect_equal(nrow(out), 0L)
  expect_named(out, c("element_id", "element_type", "title", "text", "doc_id"))
})

# ---------------------------------------------------------------------------
# ECSF (010-ingest-ecsf.R): slug stability and flatteners
# ---------------------------------------------------------------------------

test_that("ECSF slugify_profile_title produces the expected stable slugs", {
  env <- source_ingest_script("010-ingest-ecsf.R", ecsf_pkgs)
  slug <- env$slugify_profile_title

  expect_equal(slug("Chief Information Security Officer (CISO)"),
               "chief-information-security-officer")
  expect_equal(slug("Cyber Incident Responder"), "cyber-incident-responder")
  expect_equal(slug("Cyber Legal, Policy & Compliance Officer"),
               "cyber-legal-policy-compliance-officer")
  # No leading/trailing hyphens when the title starts or ends with
  # punctuation after parenthetical removal.
  expect_equal(slug("(CISO) Chief Officer!"), "chief-officer")
  # Determinism.
  expect_identical(slug("Penetration Tester"), slug("Penetration Tester"))
})

test_that("ECSF slugify_profile_title keeps the 12 canonical profile titles unique", {
  # slugify has no collision guard; profile_id is the join key everywhere
  # downstream, so the 12 published ECSF titles must slugify uniquely.
  env <- source_ingest_script("010-ingest-ecsf.R", ecsf_pkgs)
  titles <- c(
    "Chief Information Security Officer (CISO)",
    "Cyber Incident Responder",
    "Cyber Legal, Policy & Compliance Officer",
    "Cyber Threat Intelligence Specialist",
    "Cybersecurity Architect",
    "Cybersecurity Auditor",
    "Cybersecurity Educator",
    "Cybersecurity Implementer",
    "Cybersecurity Researcher",
    "Cybersecurity Risk Manager",
    "Digital Forensics Investigator",
    "Penetration Tester"
  )
  slugs <- vapply(titles, env$slugify_profile_title, character(1),
                  USE.NAMES = FALSE)
  expect_equal(length(unique(slugs)), 12L)
  expect_false(any(grepl("^-|-$", slugs)))
})

test_that("ECSF flatten_profile_elements indexes per (profile, field) and skips empty fields", {
  env <- source_ingest_script("010-ingest-ecsf.R", ecsf_pkgs)
  profiles <- list(
    list(
      title        = "Penetration Tester",
      main_tasks   = list("Task one", "Task two"),
      key_skills   = list("Skill one"),
      key_knowledge = NULL,
      deliverables = list()
    )
  )
  out <- env$flatten_profile_elements(profiles)
  expect_equal(nrow(out), 3L)
  expect_true(all(out$profile_id == "penetration-tester"))
  mt <- out[out$element_type == "main_tasks", ]
  expect_equal(mt$element_index, 1:2)
  expect_equal(mt$element_text, c("Task one", "Task two"))
  ks <- out[out$element_type == "key_skills", ]
  expect_equal(ks$element_index, 1L)
  # NULL and length-0 fields contribute no rows.
  expect_false(any(out$element_type %in% c("key_knowledge", "deliverables")))
})

test_that("ECSF flatten_ecompetences handles NULL blocks and non-numeric proficiency", {
  env <- source_ingest_script("010-ingest-ecsf.R", ecsf_pkgs)

  no_ecomp <- list(list(title = "Cybersecurity Auditor", ecompetences = NULL))
  expect_equal(nrow(env$flatten_ecompetences(no_ecomp)), 0L)

  profiles <- list(
    list(
      title = "Cybersecurity Auditor",
      ecompetences = list(
        list("E.3", "Risk Management", "4"),
        list("A.7", "Technology Trend Monitoring", "e3")
      )
    )
  )
  out <- env$flatten_ecompetences(profiles)
  expect_equal(nrow(out), 2L)
  expect_equal(out$ecf_code, c("E.3", "A.7"))
  expect_identical(out$proficiency_level[[1]], 4L)
  # Non-numeric proficiency coerces to NA silently (suppressWarnings in
  # the script); pinned so a format change in the source JSON surfaces
  # here rather than as silent NA propagation.
  expect_true(is.na(out$proficiency_level[[2]]))
})

# ---------------------------------------------------------------------------
# DCWF (010-ingest-dcwf.R): sheet identification
# ---------------------------------------------------------------------------

test_that("DCWF identify_role_sheets selects only '(XX-NNN)' sheets", {
  env <- source_ingest_script("010-ingest-dcwf.R", dcwf_pkgs)
  sheets <- c(
    "Info Sheet", "Change Log", "Master Task & KSA List", "DCWF Roles",
    "(IT-411) Tech Supp", "(OM-001) Ops",
    "(XYZ-11) Bad",   # three letters / two digits: not a role sheet
    "(it-411) lower", # lowercase: not a role sheet
    "Template"
  )
  expect_equal(env$identify_role_sheets(sheets),
               c("(IT-411) Tech Supp", "(OM-001) Ops"))
})

test_that("DCWF extract_role_code pulls the code out of a role sheet name", {
  env <- source_ingest_script("010-ingest-dcwf.R", dcwf_pkgs)
  expect_equal(env$extract_role_code("(IT-411) Tech Supp"), "IT-411")
  expect_equal(env$extract_role_code("(OM-001) Ops"), "OM-001")
  expect_true(is.na(env$extract_role_code("DCWF Roles")))
})
