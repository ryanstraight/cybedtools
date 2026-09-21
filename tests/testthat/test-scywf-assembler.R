# Tests for the SCyWF ingest helpers (scripts/010-ingest-scywf.R) and JSON-LD
# adapter (scripts/_assemble-scywf.R).
#
# Both scripts guard their top-level pipeline run, so source()-ing them loads
# functions only. The fixtures below are synthetic: page words with
# coordinates, shaped like pdftools::pdf_data() output, and small tables in
# the shape the ingest writes. No staged framework data is read, except by the
# last test, which skips when the staged tables are absent.
#
# scripts/ is .Rbuildignore'd, so these tests skip under R CMD check on the
# built tarball and run under devtools::test() in the source tree.

source_scywf_scripts <- function() {
  for (pkg in c("pdftools", "readr", "yaml", "digest", "stringr", "here", "tidyr")) {
    testthat::skip_if_not_installed(pkg)
  }
  ingest <- testthat::test_path("..", "..", "scripts", "010-ingest-scywf.R")
  adapter <- testthat::test_path("..", "..", "scripts", "_assemble-scywf.R")
  if (!file.exists(ingest) || !file.exists(adapter)) {
    testthat::skip("scywf scripts not available (built-tarball check)")
  }
  env <- new.env(parent = globalenv())
  suppressPackageStartupMessages(suppressWarnings(source(ingest, local = env)))
  suppressPackageStartupMessages(suppressWarnings(source(adapter, local = env)))
  env
}

# One printed line as pdf_data() words: each word 30 points right of the last.
fixture_line <- function(x, y, text) {
  words <- strsplit(text, " ", fixed = TRUE)[[1]]
  tibble::tibble(x = x + 30 * (seq_along(words) - 1), y = y, width = 25,
                 text = words)
}

# One job role card, laid out as Appendix A lays it out: a label column at
# x = 85 and a value column at x = 161, each label centred on its cell. The
# description runs to two lines around its label, and the Competency Areas
# label carries the asterisk that points at a footnote under the card.
fixture_card_page <- function() {
  dplyr::bind_rows(
    fixture_line(273, 80,  "Job Role Details"),
    fixture_line(85,  100, "Job Role Name"),
    fixture_line(161, 100, "Threat Hunter"),
    fixture_line(85,  116, "Job Role ID"),
    fixture_line(161, 116, "PD-TM-002"),
    fixture_line(85,  132, "Category"),
    fixture_line(161, 132, "Protection and Defense"),
    fixture_line(85,  148, "Specialty Area"),
    fixture_line(161, 148, "Threat Management"),
    fixture_line(161, 164, "Proactively searches for undetected threats"),
    fixture_line(85,  171, "Job Role Description"),
    fixture_line(161, 178, "and recommends mitigation plans"),
    fixture_line(85,  194, "Competency Areas*"),
    fixture_line(161, 194, "Cyber Threat Intelligence (CA019)"),
    fixture_line(85,  210, "Tasks"),
    fixture_line(161, 210, "T0009, T0057"),
    fixture_line(85,  226, "Knowledge"),
    fixture_line(161, 226, "K0001, K0044"),
    fixture_line(85,  242, "Skills"),
    fixture_line(161, 242, "S0001"),
    fixture_line(100, 300, "In addition to the areas they manage"),
    fixture_line(90,  302, "*")
  )
}

test_that("cell lines join on one space, and a line-break hyphen keeps its hyphen", {
  env <- source_scywf_scripts()
  plain <- env$scywf_join_lines(c("Designs and ", "  oversees systems"))
  expect_identical(plain$text, "Designs and oversees systems")
  expect_equal(nrow(plain$joins), 0L)

  hyph <- env$scywf_join_lines(c("throughout the life-", "cycle."))
  expect_identical(hyph$text, "throughout the life-cycle.")
  expect_equal(nrow(hyph$joins), 1L)
  expect_identical(hyph$joins$left, "life-")

  expect_identical(env$scywf_normalise_text("a  b\r\nc life-\n  cycle"),
                   "a b c life-cycle")
})

test_that("row partition keeps rows contiguous and centres lines on anchors", {
  env <- source_scywf_scripts()
  # A three-line row centred on 114, then a one-line row.
  expect_identical(env$scywf_partition_rows(c(100, 114, 128, 150), c(114, 150)),
                   c(1L, 1L, 1L, 2L))
  # Input order does not matter. The result follows the input.
  expect_identical(env$scywf_partition_rows(c(40, 10, 20), c(15, 40)),
                   c(2L, 1L, 1L))
  expect_error(env$scywf_partition_rows(c(10), c(10, 20)), "Cannot partition")
})

test_that("a role card parses into verbatim fields, codes and its footnote", {
  env <- source_scywf_scripts()
  parsed <- env$scywf_parse_cards(list(fixture_card_page()))
  role <- parsed$roles
  expect_equal(nrow(role), 1L)
  expect_identical(role$role_id, "PD-TM-002")
  expect_identical(role$role_name, "Threat Hunter")
  expect_identical(role$category_text, "Protection and Defense")
  expect_identical(role$specialty_area_text, "Threat Management")
  expect_identical(role$description,
                   "Proactively searches for undetected threats and recommends mitigation plans")
  expect_identical(role$competency_areas_text, "Cyber Threat Intelligence (CA019)")
  expect_identical(role$competency_areas_note, "In addition to the areas they manage")

  codes <- parsed$codes
  expect_identical(codes$statement_id, c("T0009", "T0057", "K0001", "K0044", "S0001"))
  expect_identical(codes$statement_type,
                   c("task", "task", "knowledge", "knowledge", "skill"))
  expect_identical(env$scywf_role_competency_areas(role)$ca_id, "CA019")
})

test_that("a card whose label column does not read as a card stops the parse", {
  env <- source_scywf_scripts()
  page <- fixture_card_page()
  page$text[page$text == "Knowledge"] <- "Abilities"
  expect_error(env$scywf_parse_cards(list(page)), "expected sequence")
})

test_that("a skills page assigns multi-line text and the Technical? flag by row", {
  env <- source_scywf_scripts()
  words <- dplyr::bind_rows(
    fixture_line(98,  100, "S0001"),
    fixture_line(141, 100, "Skill in conducting scans"),
    fixture_line(484, 100, "Yes"),
    fixture_line(141, 114, "Skill in solving"),
    fixture_line(98,  121, "S0017"),
    fixture_line(484, 121, "No"),
    fixture_line(141, 128, "problems")
  )
  parsed <- env$scywf_parse_statement_page(words, "skill")$rows
  expect_identical(parsed$statement_id, c("S0001", "S0017"))
  expect_identical(parsed$text, c("Skill in conducting scans", "Skill in solving problems"))
  expect_identical(parsed$technical, c("Yes", "No"))
})

test_that("the verbatim check finds carried text and flags text that is not there", {
  env <- source_scywf_scripts()
  roles <- tibble::tibble(role_id = "PD-TM-002", role_name = "Threat Hunter",
                          description = "Searches for threats.",
                          category_text = "Protection and Defense",
                          specialty_area_text = "Threat Management",
                          competency_areas_text = "Cyber Threat Intelligence (CA019)",
                          competency_areas_note = NA_character_)
  statements <- tibble::tibble(statement_id = c("T0009", "S0001"),
                               statement_type = c("task", "skill"),
                               text = c("Correlate incident data", "Skill in scanning"),
                               technical = c(NA, "Yes"))
  codes <- tibble::tibble(role_id = "PD-TM-002", statement_id = c("T0009", "S0001"),
                          statement_type = c("task", "skill"), ordinal = 1L)
  competency <- tibble::tibble(ca_id = "CA019", ca_name = "Cyber Threat Intelligence",
                               description = "This Competency Area describes threats")
  categories <- tibble::tibble(category_id = "PD", category_name = "Protection and Defense")
  specialty <- tibble::tibble(specialty_area_id = "TM", specialty_area_name = "Threat Management",
                              category_id = "PD")
  reference <- paste(
    "Job Role Name Threat Hunter Job Role ID PD-TM-002 Category Protection and Defense",
    "Specialty Area Threat Management Job Role Description Searches for",
    "threats. Competency Areas Cyber Threat Intelligence (CA019) Tasks T0009",
    "Skills S0001", "T0009 Correlate incident data",
    "S0001 Skill in scan-\nning Yes",
    "CA019 Cyber Threat Intelligence This Competency Area describes threats",
    sep = "\n"
  )
  check <- env$scywf_verbatim_check(roles, statements, codes, competency,
                                    categories, specialty, reference)
  failed <- check[!check$found, ]
  # The reference spells the skill "scan-ning" across a break, which the
  # hyphenation rule joins as "scan-ning". The carried text says "scanning",
  # so both the plain and the paired rows for S0001 must fail.
  expect_setequal(paste(failed$field, failed$id),
                  c("statement_text S0001", "statement_with_code S0001"))
})

# ---------------------------------------------------------------------------
# Adapter
# ---------------------------------------------------------------------------

fixture_scywf_parts <- function(env) {
  env$build_scywf_parts(
    categories = tibble::tibble(
      category_id   = c("PD", "ICSOT"),
      category_name = c("Protection and Defense",
                        "Industrial Control Systems and Operational Technologies (ICS/OT)")
    ),
    specialty_areas = tibble::tibble(
      specialty_area_id   = c("TM", "ICSOT"),
      specialty_area_name = c("Threat Management",
                              "Industrial Control Systems and Operational Technologies (ICS/OT)"),
      category_id         = c("PD", "ICSOT")
    ),
    roles = tibble::tibble(
      role_id               = c("PD-TM-002", "ICSOT-ICSOT-005"),
      role_name             = c("Threat Hunter", "ICS/OT Cybersecurity Incident Responder"),
      specialty_area_id     = c("TM", "ICSOT"),
      description           = c("Proactively searches for undetected threats.",
                                "Investigates incidents within ICS/OT environments."),
      competency_areas_text = c("Cyber Threat Intelligence (CA019)",
                                "Incident Management (CA011)"),
      competency_areas_note = c(NA, "In addition to the areas they manage")
    ),
    statements = tibble::tibble(
      statement_id   = c("T0009", "K0001", "S0001"),
      statement_type = c("task", "knowledge", "skill"),
      text           = c("Correlate incident data",
                         "Knowledge of computer networking concepts and protocols, and network security methodologies",
                         "Skill in conducting vulnerability scans"),
      technical      = c(NA, NA, "Yes")
    ),
    role_statements = tibble::tibble(
      role_id        = c("PD-TM-002", "PD-TM-002", "PD-TM-002", "ICSOT-ICSOT-005"),
      statement_id   = c("S0001", "T0009", "K0001", "T0009"),
      statement_type = c("skill", "task", "knowledge", "task"),
      ordinal        = c(1L, 1L, 1L, 1L)
    ),
    competency_areas = tibble::tibble(
      ca_id       = c("CA011", "CA019"),
      ca_name     = c("Incident Management", "Cyber Threat Intelligence"),
      description = c("This Competency Area describes incidents",
                      "This Competency Area describes threats")
    ),
    role_competency_areas = tibble::tibble(
      role_id = c("PD-TM-002", "ICSOT-ICSOT-005"),
      ca_id   = c("CA019", "CA011"),
      ordinal = c(1L, 1L)
    ),
    prov = list(
      framework_version = "SCyWF - 1.5 : 2026",
      framework_date    = "2026",
      publisher         = "National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia",
      licensing = list(
        source_license = "Used with written permission of the National Cybersecurity Authority (NCA).",
        attribution    = "Issued by the National Cybersecurity Authority (NCA), Kingdom of Saudi Arabia. Source: https://nca.gov.sa/en/pages/scywf.html"
      )
    )
  )
}

node_by_id <- function(nodes, iri) {
  hit <- Filter(\(n) identical(as.character(n[["@id"]]), iri), nodes)
  if (length(hit) != 1L) stop("expected one node for ", iri, ", found ", length(hit))
  hit[[1]]
}

test_that("the framework node carries NCA as publisher and its attribution", {
  env <- source_scywf_scripts()
  parts <- fixture_scywf_parts(env)
  fw <- parts$framework
  expect_identical(as.character(fw[["@id"]]), "cybed:framework/scywf-1.5")
  expect_identical(fw[["schema:version"]], "SCyWF - 1.5 : 2026")
  expect_identical(fw[["cybed:jurisdiction"]], "SA")
  expect_match(fw[["schema:publisher"]], "National Cybersecurity Authority", fixed = TRUE)
  expect_match(fw[["schema:creditText"]], "https://nca.gov.sa/en/pages/scywf.html", fixed = TRUE)
  expect_identical(parts$prefix, "scywf")
})

test_that("statements keep their printed codes and text, and skills keep Technical?", {
  env <- source_scywf_scripts()
  parts <- fixture_scywf_parts(env)
  expect_length(parts$elements, 3L)
  s1 <- node_by_id(parts$elements, "scywf:S0001")
  expect_true(all(c("scywf:SkillStatement", "cybed:RoleElement") %in% s1[["@type"]]))
  expect_identical(s1[["cybed:elementText"]], "Skill in conducting vulnerability scans")
  expect_identical(s1[["scywf:technical"]], "Yes")
  t1 <- node_by_id(parts$elements, "scywf:T0009")
  expect_true("scywf:TaskStatement" %in% t1[["@type"]])
  expect_null(t1[["scywf:technical"]])
  # The parser is off: a statement with a comma list is not split.
  k1 <- node_by_id(parts$elements, "scywf:K0001")
  expect_match(k1[["cybed:elementText"]], "protocols, and network security", fixed = TRUE)
  expect_false(any(vapply(parts$elements,
                          \(n) "cybed:Subpoint" %in% n[["@type"]], logical(1))))
})

test_that("job roles are cybed:Role, link card codes and carry derived edges apart", {
  env <- source_scywf_scripts()
  parts <- fixture_scywf_parts(env)
  role <- node_by_id(parts$roles, "scywf:PD-TM-002")
  expect_true(all(c("scywf:JobRole", "cybed:Role", "cybed:OrganizingUnit") %in% role[["@type"]]))
  # Card order: tasks, then knowledge, then skills.
  expect_identical(vapply(role[["cybed:hasElement"]], \(e) as.character(e[["@id"]]), character(1)),
                   c("scywf:T0009", "scywf:K0001", "scywf:S0001"))
  expect_identical(role[["scywf:inSpecialtyArea"]][["@id"]], "scywf:specialty-TM")
  expect_identical(vapply(role[["cybed:relatedUnit"]], \(e) e[["@id"]], character(1)),
                   "scywf:CA019")
  expect_identical(role[["scywf:competencyAreasText"]], "Cyber Threat Intelligence (CA019)")
  expect_null(role[["scywf:competencyAreasNote"]])
  other <- node_by_id(parts$roles, "scywf:ICSOT-ICSOT-005")
  expect_identical(other[["scywf:competencyAreasNote"]], "In addition to the areas they manage")
})

test_that("the ICSOT category and specialty area stay two nodes", {
  env <- source_scywf_scripts()
  parts <- fixture_scywf_parts(env)
  spec <- node_by_id(parts$roles, "scywf:specialty-ICSOT")
  cat_node <- node_by_id(parts$roles, "scywf:category-ICSOT")
  expect_identical(spec[["schema:identifier"]], "ICSOT")
  expect_identical(cat_node[["schema:identifier"]], "ICSOT")
  expect_true("scywf:SpecialtyArea" %in% spec[["@type"]])
  expect_true("scywf:Category" %in% cat_node[["@type"]])
  expect_identical(spec[["scywf:inCategory"]][["@id"]], "scywf:category-ICSOT")
  for (n in list(spec, cat_node)) {
    expect_false("cybed:Role" %in% n[["@type"]])
    expect_null(n[["cybed:hasElement"]])
  }
  ca <- node_by_id(parts$roles, "scywf:CA019")
  expect_true(all(c("scywf:CompetencyArea", "cybed:OrganizingUnit") %in% ca[["@type"]]))
  expect_false("cybed:Role" %in% ca[["@type"]])

  ids <- vapply(c(parts$roles, parts$elements), \(n) as.character(n[["@id"]]), character(1))
  expect_equal(anyDuplicated(ids), 0L)
})

test_that("the scywf prefix resolves to the cybed-minted namespace", {
  ctx <- build_jsonld_context("scywf")
  expect_identical(ctx[["scywf"]], "https://w3id.org/cybed/framework/scywf#")
})

test_that("the staged tables hold 40 roles and pass the verbatim check", {
  tables <- testthat::test_path("..", "..", "data", "raw", "scywf", "tables")
  skip_if_not(dir.exists(tables), "SCyWF staged tables not available.")
  roles <- readr::read_csv(file.path(tables, "roles.csv"), show_col_types = FALSE)
  expect_equal(nrow(roles), 40L)
  check <- readr::read_csv(file.path(tables, "verbatim-check.csv"), show_col_types = FALSE)
  expect_true(nrow(check) > 0)
  expect_true(all(check$found))
  unresolved <- readr::read_csv(file.path(tables, "unresolved-codes.csv"), show_col_types = FALSE)
  expect_equal(nrow(unresolved), 0L)
})
