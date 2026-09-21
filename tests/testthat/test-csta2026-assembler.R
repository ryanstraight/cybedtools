# Tests for the csta-2026 ingest helpers (scripts/010-ingest-csta2026.R) and
# JSON-LD adapter (scripts/_assemble-csta2026.R).
#
# Both scripts guard or omit any top-level pipeline run, so source()-ing them
# loads functions only. The fixture below is synthetic and mirrors the shape
# of the Standards Explorer JSON: no staged framework data is read, except by
# the last test, which skips when the staged tables are absent.
#
# scripts/ is .Rbuildignore'd, so these tests skip under R CMD check on the
# built tarball and run under devtools::test() in the source tree.

source_csta2026_scripts <- function() {
  for (pkg in c("jsonlite", "readr", "yaml", "digest", "stringr", "here")) {
    testthat::skip_if_not_installed(pkg)
  }
  ingest <- testthat::test_path("..", "..", "scripts", "010-ingest-csta2026.R")
  adapter <- testthat::test_path("..", "..", "scripts", "_assemble-csta2026.R")
  if (!file.exists(ingest) || !file.exists(adapter)) {
    testthat::skip("csta-2026 scripts not available (built-tarball check)")
  }
  env <- new.env(parent = globalenv())
  suppressPackageStartupMessages(suppressWarnings(source(ingest, local = env)))
  suppressPackageStartupMessages(suppressWarnings(source(adapter, local = env)))
  env
}

fixture_record <- function(code, grade, concept, subconcept = "",
                           area = "", subarea = "", title = "A standard.",
                           boundaries = list("Students should do the thing."),
                           examples = list(), ai = "No") {
  list(
    code = code, grade = grade, concept = concept, subconcept = subconcept,
    specialtyArea = area, specialtySubArea = subarea, title = title,
    boundaries = boundaries, ai_standard = ai,
    pillars = list(list(label = "Computational Thinking",
                        description = "6. Define computational problems.")),
    dispositions = list("Curiosity"),
    examples = examples
  )
}

fixture_example <- function(type, text) list(type = type, icon = "", description = text)

# Two foundational groups at MS, two specialty areas, one of which (X+CS) is
# published at Specialty I only. A crossing would give 2 x 2 specialty units;
# the observed pairs give 3.
csta2026_fixture <- function() {
  list(
    fixture_record("MS-ALG-PS-01", "MS", "Algorithms & Design",
                   "Algorithmic Problem Solving",
                   title = "Design an algorithm.",
                   boundaries = list("Students should design.", "Students are not expected to prove."),
                   examples = list(fixture_example("Unplugged", "Students sort cards."),
                                   fixture_example("Computer-based", "Students write a flowchart.")),
                   ai = "Yes"),
    fixture_record("MS-ALG-ML-02", "MS", "Algorithms & Design", "Machine Learning"),
    fixture_record("MS-SYS-SE-03", "MS", "Systems & Security", "Security",
                   examples = list(fixture_example("Teacher choice", "Students review a password policy."))),
    fixture_record("S1-CYB-ND-01", "Specialty-I", "Cybersecurity",
                   area = "Cybersecurity", subarea = "Network Theory & Design",
                   title = "Analyze network protocols.",
                   examples = list(fixture_example("Unplugged", "Students classify protocols."))),
    fixture_record("S2-CYB-ND-01", "Specialty-II", "Cybersecurity",
                   area = "Cybersecurity", subarea = "Network Theory & Design",
                   title = "Integrate security features."),
    fixture_record("S1-XCS-XC-01", "Specialty-I", "X+CS",
                   area = "X+CS", subarea = "X+CS",
                   title = "Apply computing in another discipline.")
  )
}

build_fixture_parts <- function(env) {
  records    <- csta2026_fixture()
  standards  <- env$extract_csta2026_standards(records)
  boundaries <- env$extract_csta2026_boundaries(records)
  examples   <- env$extract_csta2026_examples(records)
  units      <- env$build_csta2026_units(standards)
  prov <- list(
    framework_version  = "2026 CSTA PK-12 Computer Science Standards",
    version_date       = "2026-07",
    doi                = "10.1145/3820482",
    suggested_citation = "Computer Science Teachers Association. (2026). Fixture citation.",
    source             = list(publisher = "Computer Science Teachers Association (CSTA)"),
    licensing          = list(source_license = "CC BY-NC-SA 4.0")
  )
  list(
    standards = standards, boundaries = boundaries, examples = examples,
    units = units,
    parts = env$build_csta2026_parts(standards, boundaries, examples, units, prov)
  )
}

node_ids <- function(nodes) vapply(nodes, \(n) as.character(n[["@id"]]), character(1))

node_by_id <- function(nodes, id) nodes[[match(id, node_ids(nodes))]]

link_ids <- function(links) vapply(links, \(l) as.character(l[["@id"]]), character(1))

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

test_that("both tiers normalise onto one concept / subconcept pair", {
  env <- source_csta2026_scripts()
  s <- env$extract_csta2026_standards(csta2026_fixture())

  cyb <- s[s$code == "S1-CYB-ND-01", ]
  expect_equal(cyb$tier, "specialty")
  expect_equal(cyb$concept, "Cybersecurity")
  expect_equal(cyb$subconcept, "Network Theory & Design")
  expect_equal(cyb$specialty_area_code, "CYB")
  expect_equal(cyb$source_section, "S1.Cybersecurity.Network Theory & Design")

  ms <- s[s$code == "MS-ALG-PS-01", ]
  expect_equal(ms$tier, "foundational")
  expect_true(is.na(ms$specialty_area_code))
  expect_equal(ms$source_section, "MS.Algorithms & Design.Algorithmic Problem Solving")
  expect_true(ms$ai_standard)
  expect_equal(ms$practices, "CT6")
})

test_that("units come from observed pairs, never from a crossing", {
  env <- source_csta2026_scripts()
  s <- env$extract_csta2026_standards(csta2026_fixture())
  units <- env$build_csta2026_units(s)

  expect_setequal(units$unit_id,
                  c("MS-ALG", "MS-SYS", "S1-CYB", "S2-CYB", "S1-XCS"))
  expect_false("S2-XCS" %in% units$unit_id)
  expect_equal(sum(units$tier == "foundational"), 2L)
  expect_equal(sum(units$tier == "specialty"), 3L)
})

# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------

test_that("the adapter emits one StandardGroup unit per observed pair", {
  env <- source_csta2026_scripts()
  built <- build_fixture_parts(env)
  roles <- built$parts$roles

  expect_length(roles, 5L)
  for (unit in roles) {
    expect_equal(unit[["@type"]], c("csta2026:StandardGroup", "cybed:OrganizingUnit"))
    expect_false("cybed:Role" %in% unit[["@type"]])
  }
  cyb <- node_by_id(roles, "csta2026:S1-CYB")
  expect_equal(cyb[["csta2026:tier"]], "specialty")
  expect_equal(cyb[["csta2026:specialtyArea"]], "CYB")
  expect_equal(link_ids(cyb[["cybed:hasElement"]]), "csta2026:S1-CYB-ND-01")

  alg <- node_by_id(roles, "csta2026:MS-ALG")
  expect_setequal(link_ids(alg[["cybed:hasElement"]]),
                  c("csta2026:MS-ALG-PS-01", "csta2026:MS-ALG-ML-02"))
  expect_null(alg[["csta2026:specialtyArea"]])
})

test_that("standards keep CSTA's code and text verbatim and carry the tier literals", {
  env <- source_csta2026_scripts()
  built <- build_fixture_parts(env)
  el <- node_by_id(built$parts$elements, "csta2026:S1-CYB-ND-01")

  expect_equal(el[["@type"]], c("csta2026:Standard", "cybed:RoleElement"))
  expect_equal(el[["cybed:elementText"]], "Analyze network protocols.")
  expect_equal(el[["cybed:sourceSection"]], "S1.Cybersecurity.Network Theory & Design")
  expect_equal(el[["csta2026:tier"]], "specialty")
  expect_equal(el[["csta2026:specialtyArea"]], "CYB")
  expect_equal(el[["csta2026:subconcept"]], "Network Theory & Design")
  expect_false(el[["csta2026:aiStandard"]])

  ms <- node_by_id(built$parts$elements, "csta2026:MS-ALG-PS-01")
  expect_true(ms[["csta2026:aiStandard"]])
  expect_null(ms[["csta2026:specialtyArea"]])
})

test_that("implementation examples are Examples reached by hasExample, not hasElement", {
  env <- source_csta2026_scripts()
  built <- build_fixture_parts(env)
  elements <- built$parts$elements

  is_example <- vapply(elements, \(n) "cybed:Example" %in% n[["@type"]], logical(1))
  expect_equal(sum(is_example), nrow(built$examples))
  expect_equal(sum(is_example), 4L)

  example_iris <- node_ids(elements[is_example])
  for (ex in elements[is_example]) {
    expect_equal(ex[["@type"]], c("cybed:Example", "cybed:RoleElement"))
  }

  parent <- node_by_id(elements, "csta2026:MS-ALG-PS-01")
  expect_equal(link_ids(parent[["cybed:hasExample"]]),
               c("csta2026:MS-ALG-PS-01.example.1", "csta2026:MS-ALG-PS-01.example.2"))
  first <- node_by_id(elements, "csta2026:MS-ALG-PS-01.example.1")
  expect_equal(first[["cybed:elementText"]], "Students sort cards.")
  expect_equal(first[["csta2026:exampleType"]], "Unplugged")

  # No unit reaches an Example through cybed:hasElement.
  unit_links <- unlist(lapply(built$parts$roles, \(u) link_ids(u[["cybed:hasElement"]])))
  expect_length(intersect(unit_links, example_iris), 0L)

  # A standard with no published examples carries no hasExample.
  expect_null(node_by_id(elements, "csta2026:MS-ALG-ML-02")[["cybed:hasExample"]])
})

test_that("boundary statements are literals on the standard, never Examples", {
  env <- source_csta2026_scripts()
  built <- build_fixture_parts(env)
  elements <- built$parts$elements

  parent <- node_by_id(elements, "csta2026:MS-ALG-PS-01")
  expect_equal(parent[["csta2026:boundaryStatement"]],
               c("Students should design.", "Students are not expected to prove."))

  example_texts <- unlist(lapply(
    Filter(\(n) "cybed:Example" %in% n[["@type"]], elements),
    \(n) n[["cybed:elementText"]]
  ))
  expect_false(any(built$boundaries$text %in% example_texts))
})

test_that("the adapter never touches csta-2017's prefix or namespace", {
  env <- source_csta2026_scripts()
  built <- build_fixture_parts(env)

  all_ids <- c(node_ids(built$parts$roles), node_ids(built$parts$elements))
  expect_true(all(startsWith(all_ids, "csta2026:")))
  expect_false(any(startsWith(all_ids, "csta:")))
  expect_equal(built$parts$prefix, "csta2026")
  expect_equal(as.character(built$parts$framework[["@id"]]), "cybed:framework/csta-2026")

  # csta-2017 keeps its own namespace and a context of its own.
  expect_equal(build_jsonld_context("csta")$csta,
               "https://csteachers.org/k12standards/terms#")
  expect_false("csta2026" %in% names(build_jsonld_context("csta")))
  expect_true("csta2026" %in% names(build_jsonld_context("csta2026")))
  expect_false(identical(build_jsonld_context("csta2026")$csta2026,
                         build_jsonld_context("csta")$csta))
})

test_that("the framework node is pedagogical, US, with CSTA's citation and DOI", {
  env <- source_csta2026_scripts()
  fw <- build_fixture_parts(env)$parts$framework

  expect_equal(fw[["@type"]], c("csta2026:Framework", "cybed:Framework"))
  expect_equal(fw[["cybed:jurisdiction"]], "US")
  expect_equal(fw[["cybed:specificity"]], "general-computing")
  expect_equal(fw[["schema:license"]], "CC BY-NC-SA 4.0")
  expect_match(fw[["schema:creditText"]], "Computer Science Teachers Association", fixed = TRUE)
  expect_match(fw[["schema:creditText"]], "10.1145/3820482", fixed = TRUE)
})

# ---------------------------------------------------------------------------
# Staged data, when present
# ---------------------------------------------------------------------------

test_that("the staged tables yield 53 units and 27 Cybersecurity standards", {
  env <- source_csta2026_scripts()
  tables <- testthat::test_path("..", "..", "data", "raw", "csta-2026", "tables")
  skip_if(!file.exists(file.path(tables, "units.csv")), "csta-2026 tables not staged.")

  units <- readr::read_csv(file.path(tables, "units.csv"), show_col_types = FALSE)
  standards <- readr::read_csv(file.path(tables, "standards.csv"), show_col_types = FALSE)
  expect_equal(nrow(units), 53L)
  expect_equal(sum(units$tier == "foundational"), 40L)
  expect_equal(sum(units$tier == "specialty"), 13L)
  expect_false("S2-XCS" %in% units$unit_id)
  expect_equal(nrow(standards), 331L)
  expect_equal(sum(standards$specialty_area_code %in% "CYB"), 27L)
})
