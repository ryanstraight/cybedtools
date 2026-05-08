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

  # Five parent elements + five sub-points all have partOf; el_orphan
  # must be excluded.
  expect_equal(nrow(result), 10)
  expect_named(result, c("element", "framework", "framework_name"))
  expect_false(any(grepl("fixture-el-orphan", result$element)))
})

test_that("element_framework_bindings splits correctly across frameworks", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- element_framework_bindings(rdf)
  per_fw <- table(result$framework_name)

  # FW A: 3 parents (a1,a2,a3) + 2 sub-points (a1.sub.1, a1.sub.2) = 5
  # FW B: 2 parents (b1,b2) + 3 sub-points (b1.sub.1-3) = 5
  expect_equal(unname(per_fw["Fixture Framework A"]), 5)
  expect_equal(unname(per_fw["Fixture Framework B"]), 5)
})

# ---------------------------------------------------------------------------
# Domain helper: role_element_bindings
# ---------------------------------------------------------------------------

test_that("role_element_bindings returns one row per cybed:hasElement triple", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  result <- role_element_bindings(rdf)

  # 5 original hasElement triples + 5 sub-points-as-cluster-children = 10
  expect_equal(nrow(result), 10)
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

  # role_a1 owns el_a1 + el_a2 + el_a1's 2 sub-points = 4
  # role_a2 owns el_a3 = 1
  # role_b1 owns el_b1 + el_b2 + el_b1's 3 sub-points = 5
  expect_equal(a1, 4)
  expect_equal(a2, 1)
  expect_equal(b1, 5)
})

test_that("role_element_bindings is empty when no hasElement triples exist", {
  skip_if_no_rdflib()
  rdf <- rdflib::rdf()

  result <- role_element_bindings(rdf)
  expect_equal(nrow(result), 0)
})

# ---------------------------------------------------------------------------
# Semantic tests: sub-point traversal via cybed:elaborates and cybed:Subpoint
# ---------------------------------------------------------------------------

test_that("cybed:elaborates triples are queryable and return parent IRIs", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  elaborates <- sparql_pairs(rdf, "cybed:elaborates")

  # 5 sub-points each elaborate exactly one parent: 2 -> el_a1, 3 -> el_b1
  expect_equal(nrow(elaborates), 5)
  expect_setequal(unique(elaborates$o), c(
    "https://w3id.org/cybed/ontology#element/fixture-el-a1",
    "https://w3id.org/cybed/ontology#element/fixture-el-b1"
  ))
})

test_that("cybed:Subpoint typed subjects are exactly the sub-points", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  subpoints <- sparql_subjects(rdf, "a", "cybed:Subpoint")
  expect_equal(nrow(subpoints), 5)
  expect_true(all(grepl("\\.sub\\.\\d+$", subpoints$s)))
})

test_that("cybed:Subpoint subjects are also typed cybed:RoleElement (polymorphism)", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  all_role_elements <- sparql_subjects(rdf, "a", "cybed:RoleElement")
  subpoints         <- sparql_subjects(rdf, "a", "cybed:Subpoint")

  # Every sub-point should also appear in cybed:RoleElement queries
  expect_true(all(subpoints$s %in% all_role_elements$s))
})

test_that("top-level standards can be filtered by absence of cybed:elaborates", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  all_role_elements <- sparql_subjects(rdf, "a", "cybed:RoleElement")
  elaborators       <- sparql_pairs(rdf, "cybed:elaborates")

  # Top-level standards = role elements that do NOT have outgoing elaborates
  top_level <- setdiff(all_role_elements$s, elaborators$s)

  # Original parents: a1, a2, a3, b1, b2, orphan = 6 (orphan included
  # since fixture types it as RoleElement; 5 sub-points excluded since
  # they elaborate)
  expect_length(top_level, 6)
  expect_false(any(grepl("\\.sub\\.\\d+$", top_level)))
})

test_that("sub-points are reachable from clusters via cybed:hasElement (cluster sees all leaves)", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  bindings <- role_element_bindings(rdf)

  # role_a1's children should include both parents AND sub-points
  a1_children <- bindings$element[grepl("fixture-a1$", bindings$role)]
  expect_true(any(grepl("fixture-el-a1$", a1_children)))         # parent
  expect_true(any(grepl("fixture-el-a1\\.sub\\.1$", a1_children))) # sub-point 1
  expect_true(any(grepl("fixture-el-a1\\.sub\\.2$", a1_children))) # sub-point 2
})

test_that("sub-point cybed:partOf points at the same framework as its parent", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  partof <- sparql_pairs(rdf, "cybed:partOf")

  # All sub-points of el_a1 should partOf fw_a; sub-points of el_b1 should partOf fw_b
  a1_subpoints <- partof$o[grepl("fixture-el-a1\\.sub\\.", partof$s)]
  b1_subpoints <- partof$o[grepl("fixture-el-b1\\.sub\\.", partof$s)]

  expect_true(all(grepl("fixture-fw-a$", a1_subpoints)))
  expect_true(all(grepl("fixture-fw-b$", b1_subpoints)))
})

test_that("sub-points appear in element_framework_bindings (framework attribution)", {
  skip_if_no_rdflib()
  rdf <- make_fixture_graph()

  bindings <- element_framework_bindings(rdf)

  subpoint_rows <- bindings[grepl("\\.sub\\.\\d+$", bindings$element), ]
  expect_equal(nrow(subpoint_rows), 5)
  expect_setequal(unique(subpoint_rows$framework_name),
                  c("Fixture Framework A", "Fixture Framework B"))
})

test_that("sub-points round-trip through JSON-LD assemble + parse", {
  skip_if_no_rdflib()
  skip_if_not_installed("jsonld")
  parent <- build_role_element_node(
    element_id             = "P1",
    framework_prefix       = "nice",
    framework_element_type = "TaskStatement",
    element_text           = "Apply controls. Such as access control, encryption, monitoring.",
    framework_id           = "test-fw"
  )
  expanded <- expand_with_subpoints(
    list(parent),
    framework_prefix = "nice",
    framework_id     = "test-fw",
    framework_slug   = "nice"
  )
  fw_node <- build_framework_node(
    framework_id     = "test-fw",
    framework_name   = "Test FW",
    framework_prefix = "nice",
    version          = "1.0",
    publisher        = "Test",
    jurisdiction     = "US",
    sector           = "civilian",
    specificity      = "cybersecurity-specific"
  )
  doc <- assemble_framework_document(
    framework_node   = fw_node,
    role_nodes       = list(),
    element_nodes    = expanded$nodes,
    framework_prefix = "nice"
  )

  tmp <- tempfile(fileext = ".jsonld")
  on.exit(unlink(tmp), add = TRUE)
  write_jsonld_document(doc, tmp)

  # Round-trip: parse the file back into an rdf graph, query for sub-points
  rdf <- rdflib::rdf_parse(tmp, format = "jsonld")
  subpoints <- sparql_subjects(rdf, "a", "cybed:Subpoint")
  expect_equal(nrow(subpoints), 3)

  elaborates <- sparql_pairs(rdf, "cybed:elaborates")
  expect_equal(nrow(elaborates), 3)
  expect_true(all(elaborates$o == "https://nice.nist.gov/framework/terms#P1"))
})
