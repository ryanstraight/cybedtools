# Tests for the CyBOK ingest helpers (scripts/010-ingest-cybok.R) and JSON-LD
# adapter (scripts/_assemble-cybok.R).
#
# Both scripts guard their top-level pipeline run, so source()-ing them loads
# functions only. The fixtures below are synthetic: page words with
# coordinates, shaped like pdftools::pdf_data() output, a small drawn tree as
# a logical ink matrix, and small tables in the shape the ingest writes. No
# staged framework data is read, except by the last test, which skips when
# the staged tables are absent.
#
# scripts/ is .Rbuildignore'd, so these tests skip under R CMD check on the
# built tarball and run under devtools::test() in the source tree.

source_cybok_scripts <- function() {
  for (pkg in c("pdftools", "readr", "yaml", "digest", "stringr", "here")) {
    testthat::skip_if_not_installed(pkg)
  }
  ingest <- testthat::test_path("..", "..", "scripts", "010-ingest-cybok.R")
  adapter <- testthat::test_path("..", "..", "scripts", "_assemble-cybok.R")
  if (!file.exists(ingest) || !file.exists(adapter)) {
    testthat::skip("cybok scripts not available (built-tarball check)")
  }
  env <- new.env(parent = globalenv())
  suppressPackageStartupMessages(suppressWarnings(source(ingest, local = env)))
  suppressPackageStartupMessages(suppressWarnings(source(adapter, local = env)))
  env
}

# One printed line as pdf_data() words: each word 30 points right of the last.
fixture_words <- function(x, y, text, height = 10) {
  words <- strsplit(text, " ", fixed = TRUE)[[1]]
  tibble::tibble(x = x + 30 * (seq_along(words) - 1), y = y, width = 25,
                 height = height, text = words)
}

test_that("lines join on one space, and a line-break hyphen keeps its hyphen", {
  env <- source_cybok_scripts()
  expect_identical(env$cybok_join_lines(c("Risk Management &", " Governance")),
                   "Risk Management & Governance")
  expect_identical(env$cybok_join_lines(c("ELEC-", "TRONIC")), "ELEC-TRONIC")
  # The matching-only reading drops the hyphen instead.
  expect_identical(env$cybok_join_lines(c("ELEC-", "TRONIC"), soft_hyphen = TRUE),
                   "ELECTRONIC")
  expect_identical(env$cybok_normalise_text("a  b\nc Accountabil-\n ity"),
                   "a b c Accountabil-ity")
})

test_that("Figure 2 parses into categories and multi-line KA names", {
  env <- source_cybok_scripts()
  words <- dplyr::bind_rows(
    fixture_words(213, 71,  "Human, Organisational and Regulatory Aspects", height = 7),
    fixture_words(62,  79,  "Risk Management &"),
    fixture_words(62,  89,  "Governance"),
    fixture_words(168, 79,  "Security management systems"),
    fixture_words(62,  109, "Law & Regulation"),
    fixture_words(168, 104, "International and national"),
    fixture_words(213, 130, "Attacks and Defences", height = 7),
    fixture_words(62,  140, "Forensics"),
    fixture_words(168, 140, "The collection of evidence"),
    fixture_words(200, 170, "Figure 2: Short descriptions")
  )
  parsed <- env$cybok_parse_figure2(words)
  expect_identical(parsed$categories$category_name,
                   c("Human, Organisational and Regulatory Aspects", "Attacks and Defences"))
  expect_identical(parsed$kas$ka_name,
                   c("Risk Management & Governance", "Law & Regulation", "Forensics"))
  expect_identical(parsed$kas$category_name,
                   c("Human, Organisational and Regulatory Aspects",
                     "Human, Organisational and Regulatory Aspects",
                     "Attacks and Defences"))
})

test_that("an A-to-Z page splits into top-aligned rows and drops section letters", {
  env <- source_cybok_scripts()
  words <- dplyr::bind_rows(
    fixture_words(73,  72,  "INDICATIVE MATERIAL"),
    fixture_words(246, 72,  "TOPIC"),
    fixture_words(485, 73,  "CyBOK KA", height = 7),
    fixture_words(73,  90,  "A", height = 11),
    fixture_words(73,  104, "ACCESS CONTROL"),
    fixture_words(246, 104, "AUTHORISATION"),
    fixture_words(506, 105, "AAA", height = 7),
    fixture_words(73,  117, "ADMISSION INTO ELEC-"),
    fixture_words(73,  127, "TRONIC DOCUMENTS"),
    fixture_words(246, 117, "DEMATERIALISATION OF ELEC-"),
    fixture_words(246, 127, "TRONIC TRUST SERVICES"),
    fixture_words(513, 118, "LR", height = 7)
  )
  rows <- env$cybok_parse_atoz_page(words)
  expect_identical(rows$indicative_material,
                   c("ACCESS CONTROL", "ADMISSION INTO ELEC-TRONIC DOCUMENTS"))
  expect_identical(rows$topic,
                   c("AUTHORISATION", "DEMATERIALISATION OF ELEC-TRONIC TRUST SERVICES"))
  expect_identical(rows$ka_acronym, c("AAA", "LR"))
  expect_identical(rows$indicative_material_soft[2], "ADMISSION INTO ELECTRONIC DOCUMENTS")
})

# A drawn tree, one pixel per point: an unlabelled root at the far left, two
# Topics, three children and one grandchild, each label in a stroked box.
draw_line <- function(ink, x0, y0, x1, y1) {
  n <- max(abs(x1 - x0), abs(y1 - y0)) + 1
  xs <- round(seq(x0, x1, length.out = n))
  ys <- round(seq(y0, y1, length.out = n))
  ink[cbind(xs, ys)] <- TRUE
  ink
}
draw_box <- function(ink, l, r, t, b) {
  ink[l:r, t] <- TRUE
  ink[l:r, b] <- TRUE
  ink[l, t:b] <- TRUE
  ink[r, t:b] <- TRUE
  ink
}
fixture_tree <- function() {
  labels <- tibble::tibble(
    node_id = 1:6,
    text    = c("topic one", "topic two", "child a", "child b", "child c", "grandchild"),
    x0      = c(40, 40, 100, 100, 100, 150),
    x1      = c(60, 60, 120, 120, 120, 170),
    y       = c(20, 60, 10, 30, 60, 10)
  )
  ink <- matrix(FALSE, nrow = 200, ncol = 100)
  for (i in seq_len(nrow(labels))) {
    ink <- draw_box(ink, labels$x0[i] - 3, labels$x1[i] + 3, labels$y[i] - 3, labels$y[i] + 8)
  }
  ink <- draw_line(ink, 5, 42, 36, 22)
  ink <- draw_line(ink, 5, 42, 36, 62)
  ink <- draw_line(ink, 64, 22, 96, 12)
  ink <- draw_line(ink, 64, 22, 96, 32)
  ink <- draw_line(ink, 64, 62, 96, 62)
  ink <- draw_line(ink, 124, 12, 146, 12)
  list(labels = labels, ink = ink)
}

test_that("Topics are the boxes on the root's fan, and their children hang from them", {
  env <- source_cybok_scripts()
  fx <- fixture_tree()
  graph <- env$cybok_tree_links(fx$labels, fx$ink, s = 1, label_height = 4)
  expect_length(graph$problems, 0L)
  expect_identical(graph$nodes$text[graph$nodes$is_topic], c("topic one", "topic two"))
  expect_identical(graph$links$topic, c(1L, 1L, 2L))
  expect_identical(graph$links$child, c(3L, 4L, 5L))
  tables <- env$cybok_tree_tables(list(nodes = graph$nodes, links = graph$links), "XX")
  expect_identical(tables$topics$topic_id, c("XX-01", "XX-02"))
  expect_identical(tables$im$term, c("child a", "child b", "child c"))
  expect_identical(tables$im$topic_id, c("XX-01", "XX-01", "XX-02"))
})

test_that("a label with no drawn box stops the tree read", {
  env <- source_cybok_scripts()
  fx <- fixture_tree()
  fx$labels <- dplyr::bind_rows(fx$labels, tibble::tibble(
    node_id = 7L, text = "unboxed", x0 = 150, x1 = 170, y = 80))
  graph <- env$cybok_tree_links(fx$labels, fx$ink, s = 1, label_height = 4)
  expect_match(graph$problems, "no box found around \"unboxed\"", fixed = TRUE)
})

test_that("A-to-Z rows resolve by folded case and report what does not resolve", {
  env <- source_cybok_scripts()
  topics <- tibble::tibble(ka_acronym = "RMG", topic_id = c("RMG-01", "RMG-02"),
                           ordinal = 1:2, title = c("risk definition", "risk governance"))
  im <- tibble::tibble(ka_acronym = "RMG", topic_id = c("RMG-01", "RMG-02"),
                       ordinal = 1L, term = c("risk assessment", "security culture"))
  atoz <- tibble::tibble(
    indicative_material      = c("RISK ASSESSMENT", "RISK ASSESSMENT", "SECURITY CULTURE", "NEW TERM"),
    topic                    = c("RISK DEFINITION", "RISK DEFINITIONS", "RISK DEFINITION", "RISK GOVERNANCE"),
    ka_acronym               = "RMG",
    indicative_material_soft = c("RISK ASSESSMENT", "RISK ASSESSMENT", "SECURITY CULTURE", "NEW TERM"),
    topic_soft               = c("RISK DEFINITION", "RISK DEFINITIONS", "RISK DEFINITION", "RISK GOVERNANCE")
  )
  res <- env$cybok_resolve_atoz(atoz, topics, im)
  expect_identical(res$status, c("resolved",
                                 "topic worded differently, term in tree",
                                 "term under a different topic in the tree",
                                 "topic resolved, term not in tree"))
  expect_identical(res$term_in_tree[1], "risk assessment")
  expect_identical(res$term_topic_in_tree[3], "RMG-02")
})

test_that("crosswalk KA names resolve exactly, or with and read as an ampersand", {
  env <- source_cybok_scripts()
  kas <- tibble::tibble(ka_acronym = c("LR", "F"), ka_name = c("Law & Regulation", "Forensics"))
  res <- env$cybok_resolve_crosswalk_kas(c("Forensics", "Law and Regulation", "Other"), kas)
  expect_identical(res$ka_acronym, c("F", "LR", NA))
  expect_identical(res$resolution, c("exact", "and read as ampersand", "unresolved"))
})

# ---------------------------------------------------------------------------
# Adapter
# ---------------------------------------------------------------------------

fixture_cybok_parts <- function(env) {
  env$build_cybok_parts(
    knowledge_areas = tibble::tibble(
      ka_acronym    = c("RMG", "F"),
      ka_name       = c("Risk Management & Governance", "Forensics"),
      category_name = c("Human, Organisational and Regulatory Aspects", "Attacks and Defences"),
      ka_order      = c(1L, 2L),
      version       = c("1.1.1", "1.0.1")
    ),
    topics = tibble::tibble(
      ka_acronym = c("RMG", "RMG", "F"),
      topic_id   = c("RMG-01", "RMG-02", "F-01"),
      ordinal    = c(1L, 2L, 1L),
      title      = c("risk definition", "risk governance", "definitions and conceptual models")
    ),
    indicative_material = tibble::tibble(
      ka_acronym = c("RMG", "RMG", "RMG", "F"),
      topic_id   = c("RMG-01", "RMG-01", "RMG-02", "F-01"),
      ordinal    = c(1L, 2L, 1L, 1L),
      term       = c("risk assessment", "risk management", "governance models", "definitions")
    ),
    prov = list(
      framework_version = "CyBOK v1.1.0",
      framework_date    = "2021-07",
      publisher         = "The National Cyber Security Centre (NCSC), United Kingdom",
      licensing = list(
        source_license = "Open Government Licence v3.0.",
        attribution    = "CyBOK © Crown Copyright, The National Cyber Security Centre 2021, licensed under the Open Government Licence: http://www.nationalarchives.gov.uk/doc/open-government-licence/."
      )
    )
  )
}

node_by_id <- function(nodes, iri) {
  hit <- Filter(\(n) identical(as.character(n[["@id"]]), iri), nodes)
  if (length(hit) != 1L) stop("expected one node for ", iri, ", found ", length(hit))
  hit[[1]]
}

test_that("the framework node carries the OGL attribution as credit text", {
  env <- source_cybok_scripts()
  parts <- fixture_cybok_parts(env)
  fw <- parts$framework
  expect_identical(as.character(fw[["@id"]]), "cybed:framework/cybok-v1.1.0")
  expect_identical(fw[["cybed:jurisdiction"]], "UK")
  expect_match(fw[["schema:creditText"]], "Open Government Licence", fixed = TRUE)
  expect_identical(parts$prefix, "cybok")
})

test_that("Knowledge Areas are organizing units, never roles, with category and version", {
  env <- source_cybok_scripts()
  parts <- fixture_cybok_parts(env)
  rmg <- node_by_id(parts$roles, "cybok:RMG")
  expect_true(all(c("cybok:KnowledgeArea", "cybed:OrganizingUnit") %in% rmg[["@type"]]))
  expect_false("cybed:Role" %in% rmg[["@type"]])
  expect_identical(rmg[["cybok:category"]], "Human, Organisational and Regulatory Aspects")
  expect_identical(rmg[["schema:version"]], "1.1.1")
  expect_identical(vapply(rmg[["cybed:hasElement"]], \(e) as.character(e[["@id"]]), character(1)),
                   c("cybok:RMG-01", "cybok:RMG-02", "cybok:RMG-01.sub.1",
                     "cybok:RMG-01.sub.2", "cybok:RMG-02.sub.1"))
})

test_that("Topics are elements and Indicative Material is a Subpoint of its Topic", {
  env <- source_cybok_scripts()
  parts <- fixture_cybok_parts(env)
  expect_length(parts$elements, 7L)
  topic <- node_by_id(parts$elements, "cybok:RMG-01")
  expect_true(all(c("cybok:Topic", "cybed:RoleElement") %in% topic[["@type"]]))
  expect_false("cybed:Subpoint" %in% topic[["@type"]])
  expect_identical(topic[["cybed:elementText"]], "risk definition")
  im <- node_by_id(parts$elements, "cybok:RMG-01.sub.2")
  expect_true(all(c("cybok:IndicativeMaterial", "cybed:Subpoint", "cybed:RoleElement") %in%
                    im[["@type"]]))
  expect_false("cybok:Topic" %in% im[["@type"]])
  expect_identical(im[["cybed:elementText"]], "risk management")
  expect_identical(as.character(im[["cybed:elaborates"]][["@id"]]), "cybok:RMG-01")
  ids <- vapply(c(parts$roles, parts$elements), \(n) as.character(n[["@id"]]), character(1))
  expect_equal(anyDuplicated(ids), 0L)
})

test_that("the cybok prefix resolves to the cybed-minted namespace", {
  ctx <- build_jsonld_context("cybok")
  expect_identical(ctx[["cybok"]], "https://w3id.org/cybed/framework/cybok#")
})

test_that("the staged tables hold 21 KAs and pass the verbatim check", {
  tables <- testthat::test_path("..", "..", "data", "raw", "cybok", "tables")
  skip_if_not(file.exists(file.path(tables, "knowledge-areas.csv")),
              "CyBOK staged tables not available.")
  kas <- readr::read_csv(file.path(tables, "knowledge-areas.csv"), show_col_types = FALSE)
  expect_equal(nrow(kas), 21L)
  expect_equal(length(unique(kas$category_name)), 5L)
  check <- readr::read_csv(file.path(tables, "verbatim-check.csv"), show_col_types = FALSE)
  expect_true(nrow(check) > 0)
  expect_true(all(check$found))
  im <- readr::read_csv(file.path(tables, "indicative-material.csv"), show_col_types = FALSE)
  topics <- readr::read_csv(file.path(tables, "topics.csv"), show_col_types = FALSE)
  expect_true(all(im$topic_id %in% topics$topic_id))
})
