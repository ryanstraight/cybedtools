# Tests for R/sparql-helpers.R against the fixture graph in
# helper-fixture-graph.R.

skip_if_no_rdflib <- function() skip_if_not_installed("rdflib")

# ---------------------------------------------------------------------------
# Primitives: sparql_pairs and sparql_subjects
# ---------------------------------------------------------------------------

test_that("sparql_pairs returns a tibble of subject-object pairs", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- sparql_pairs(rdf, "cybed:jurisdiction")

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("s", "o"))
  expect_setequal(result$o, c("US", "EU"))
})

test_that("sparql_pairs is empty when the predicate is absent", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- sparql_pairs(rdf, "cybed:nonexistentPredicate")

  expect_equal(nrow(result), 0)
})

test_that("sparql_subjects returns subjects matching predicate+object", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- sparql_subjects(rdf, "a", "cybed:Framework")

  expect_s3_class(result, "tbl_df")
  expect_named(result, "s")
  expect_equal(nrow(result), 2)
})

# ---------------------------------------------------------------------------
# Domain helper: framework_metadata
# ---------------------------------------------------------------------------

test_that("framework_metadata yields one row per framework with all metadata", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- framework_metadata(rdf)

  expect_s3_class(result, "tbl_df")
  expect_named(result,
               c("framework", "name", "jurisdiction", "sector", "specificity"))
  expect_equal(nrow(result), 2)

  fw_a <- result[result$jurisdiction == "US", ]
  expect_equal(fw_a$name,        "Fixture Framework A")
  expect_equal(fw_a$sector,      "civilian")
  expect_equal(fw_a$specificity, "cybersecurity-specific")

  fw_b <- result[result$jurisdiction == "EU", ]
  expect_equal(fw_b$name,        "Fixture Framework B")
  expect_equal(fw_b$sector,      "general")
  expect_equal(fw_b$specificity, "general-IT")
})

test_that("framework_metadata returns empty tibble on empty graph", {
  skip_if_no_rdflib()
  rdf <- rdflib::rdf()

  result <- framework_metadata(rdf)

  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

# ---------------------------------------------------------------------------
# Domain helper: role_framework_bindings
# ---------------------------------------------------------------------------

test_that("role_framework_bindings returns one row per bound role", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- role_framework_bindings(rdf)

  # Three roles have valid partOf pointing at a Framework: a1, a2, b1.
  # role_orphan (no partOf) and role_bad (partOf points at non-Framework)
  # must be excluded.
  expect_equal(nrow(result), 3)
  expect_named(result, c("role", "framework", "role_name", "framework_name"))

  expect_false(any(grepl("fixture-orphan",       result$role)))
  expect_false(any(grepl("fixture-bad-partof",   result$role)))
})

test_that("role_framework_bindings does not double-count duplicate partOf triples", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()  # role_a1 has a duplicate partOf

  result <- role_framework_bindings(rdf)
  a1_rows <- result[grepl("fixture-a1", result$role), ]

  expect_equal(nrow(a1_rows), 1)
})

test_that("role_framework_bindings attaches role and framework names", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- role_framework_bindings(rdf)
  a1 <- result[grepl("fixture-a1", result$role), ]

  expect_equal(a1$role_name,      "Role A1")
  expect_equal(a1$framework_name, "Fixture Framework A")
})

# ---------------------------------------------------------------------------
# Domain helper: element_framework_bindings
# ---------------------------------------------------------------------------

test_that("element_framework_bindings returns one row per bound element", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- element_framework_bindings(rdf)

  # Five elements have valid partOf; el_orphan must be excluded.
  expect_equal(nrow(result), 5)
  expect_named(result, c("element", "framework", "framework_name"))
  expect_false(any(grepl("fixture-el-orphan", result$element)))
})

test_that("element_framework_bindings splits correctly across frameworks", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- element_framework_bindings(rdf)
  per_fw <- table(result$framework_name)

  expect_equal(unname(per_fw["Fixture Framework A"]), 3)
  expect_equal(unname(per_fw["Fixture Framework B"]), 2)
})

# ---------------------------------------------------------------------------
# Domain helper: role_element_bindings
# ---------------------------------------------------------------------------

test_that("role_element_bindings returns one row per cybed:hasElement triple", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- role_element_bindings(rdf)

  expect_equal(nrow(result), 5)
  expect_named(result, c("role", "element"))
})

test_that("role_element_bindings counts elements per role correctly", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result  <- role_element_bindings(rdf)
  per_role <- as.data.frame(table(result$role), stringsAsFactors = FALSE)
  names(per_role) <- c("role", "n")

  a1 <- per_role[grepl("fixture-a1", per_role$role), "n"]
  a2 <- per_role[grepl("fixture-a2", per_role$role), "n"]
  b1 <- per_role[grepl("fixture-b1", per_role$role), "n"]

  expect_equal(a1, 2)
  expect_equal(a2, 1)
  expect_equal(b1, 2)
})

test_that("role_element_bindings is empty when no hasElement triples exist", {
  skip_if_no_rdflib()
  rdf <- rdflib::rdf()

  result <- role_element_bindings(rdf)
  expect_equal(nrow(result), 0)
})
