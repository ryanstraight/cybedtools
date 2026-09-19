# Graph-level identity and declared-count checks.
#
# The identity checks exist because a framework that numbers its organizing
# units and its statements out of one id space used to mint one IRI for both,
# fusing two nodes into one. That defect is invisible to every count, so the
# tests below plant it deliberately and assert the check fires.

cybed_of <- function(local) paste0("https://w3id.org/cybed/ontology#", local)

test_that("the fixture graph carries no identity violations", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()

  violations <- graph_identity_violations(rdf)
  expect_s3_class(violations, "tbl_df")
  expect_identical(nrow(violations), 0L)
  expect_named(violations, c("check", "iri", "framework"))
  expect_true(assert_graph_identity(rdf))
})

test_that("the shared-code fixture is clean too", {
  skip_if_not_installed("rdflib")
  # Two frameworks reusing one bare code is not the defect. The defect is one
  # IRI standing for a unit and for a statement inside a single framework.
  expect_identical(nrow(graph_identity_violations(make_shared_code_fixture_graph())), 0L)
})

test_that("a planted unit-and-statement collision is reported and aborts", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()
  fused <- cybed_of("role/fixture-a1")
  rdflib::rdf_add(rdf, fused, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
                  cybed_of("RoleElement"))

  violations <- graph_identity_violations(rdf)
  expect_identical(nrow(violations), 1L)
  expect_identical(violations$check, "unit_element_collision")
  expect_identical(violations$iri, fused)
  expect_identical(violations$framework, "fixture-fw-a")

  expect_error(assert_graph_identity(rdf), class = "cybedtools_graph_identity")
})

test_that("a planted cybed:hasElement self-loop is reported and aborts", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()
  looped <- cybed_of("role/fixture-a2")
  rdflib::rdf_add(rdf, looped, cybed_of("hasElement"), looped)

  violations <- graph_identity_violations(rdf)
  expect_identical(nrow(violations), 1L)
  expect_identical(violations$check, "has_element_self_loop")
  expect_identical(violations$iri, looped)

  expect_error(assert_graph_identity(rdf), class = "cybedtools_graph_identity")
})

test_that("the abort names the framework and the offending IRIs", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()
  looped <- cybed_of("role/fixture-b1")
  rdflib::rdf_add(rdf, looped, cybed_of("hasElement"), looped)

  condition <- tryCatch(assert_graph_identity(rdf), error = function(e) e)
  expect_s3_class(condition, "cybedtools_graph_identity")
  expect_identical(nrow(condition$violations), 1L)
  message_text <- paste(conditionMessage(condition), collapse = " ")
  expect_match(message_text, "fixture-fw-b", fixed = TRUE)
  expect_match(message_text, looped, fixed = TRUE)
})

test_that("counts are measured per framework and in total", {
  skip_if_not_installed("rdflib")
  counts <- graph_invariant_counts(make_fixture_graph())

  value_of <- function(scope, measure) {
    counts$value[counts$scope == scope & counts$measure == measure]
  }
  expect_identical(value_of("combined", "framework_count"), 2)
  expect_identical(value_of("combined", "organizing_unit_count"), 5)
  expect_identical(value_of("combined", "role_count"), 5)
  expect_identical(value_of("combined", "example_count"), 1)
  expect_identical(value_of("combined", "unit_relation_count"), 2)
  # 6 parents + 5 sub-points + 1 example, one parent unbound to a framework.
  expect_identical(value_of("combined", "total_elements_full"), 12)
  expect_identical(value_of("combined", "total_elements_with_subpoints"), 11)
  expect_identical(value_of("fixture-fw-a", "example_elements"), 1)
  expect_identical(value_of("fixture-fw-b", "subpoint_elements"), 3)
})

test_that("a declared band inside the measurement passes and outside it aborts", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()

  ok <- list(combined = list(framework_count = c(2, 2),
                             role_count = c(4, 6)))
  expect_message(assert_graph_invariants(rdf, declared = ok), "within band")

  bad <- list(combined = list(framework_count = c(3, 4)))
  expect_error(assert_graph_invariants(rdf, declared = bad),
               class = "cybedtools_graph_invariant")
})

test_that("a declared measure the graph does not report aborts", {
  skip_if_not_installed("rdflib")
  expect_error(
    assert_graph_invariants(
      make_fixture_graph(),
      declared = list(per_framework = list(`no-such-framework` = list(parent_elements = c(1, 1))))
    ),
    class = "cybedtools_graph_invariant"
  )
})

test_that("no DCWF or Cyber.org unit IRI is also an element IRI in the built graph", {
  skip_if_not_installed("rdflib")
  graph_path <- here::here("data", "processed", "ntriples", "_combined.nt")
  skip_if_not(file.exists(graph_path),
              "Combined N-Triples not staged; run scripts/025-export-ntriples.R.")

  rdf <- load_combined_ntriples_graph(graph_path)
  violations <- graph_identity_violations(rdf)

  # The regression this guards. Both frameworks number their units and their
  # statements out of one space, and both were fused before their unit IRIs
  # were given a discriminator.
  expect_false(any(grepl("dcwf", violations$framework, fixed = TRUE)))
  expect_false(any(grepl("cyberorg", violations$framework, fixed = TRUE)))
  expect_identical(nrow(violations), 0L)
})
