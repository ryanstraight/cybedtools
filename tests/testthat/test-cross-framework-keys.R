# Cross-framework key safety.
#
# Statement codes are unique only within a framework. CCSSF is an explicit
# adaptation of NICE and reuses NICE-shaped codes, so two frameworks in the
# shipped corpus can print the same bare code (the T0516 shape) for two
# different statements. Anything that returns identifiers spanning more than
# one framework must therefore let the caller tell them apart, either by
# carrying an explicit framework column or by returning the full IRI, which
# is minted in a per-framework namespace.
#
# These tests run against make_shared_code_fixture_graph(), the base fixture
# plus one deliberate collision: element code "T0516" and role code
# "WRL-001" each minted once per framework.
#
# Helpers covered (every exported SPARQL helper in R/sparql-helpers.R that
# returns element or unit identifiers across frameworks):
#   framework_metadata, role_framework_bindings,
#   organizing_unit_framework_bindings, element_framework_bindings,
#   example_framework_bindings, subpoint_framework_bindings,
#   role_element_bindings

looks_like_full_iri <- function(x) {
  x <- x[!is.na(x)]
  length(x) > 0L && all(grepl("^https?://", x))
}

# One row per helper: the identifier columns it returns, and whether it is
# expected to disambiguate by an explicit framework column or by IRI alone.
key_safety_cases <- list(
  list(name = "framework_metadata",
       fn   = function(rdf) framework_metadata(rdf),
       ids  = "framework"),
  list(name = "role_framework_bindings",
       fn   = function(rdf) role_framework_bindings(rdf),
       ids  = "role"),
  list(name = "organizing_unit_framework_bindings",
       fn   = function(rdf) organizing_unit_framework_bindings(rdf),
       ids  = "unit"),
  list(name = "element_framework_bindings",
       fn   = function(rdf) element_framework_bindings(rdf),
       ids  = "element"),
  list(name = "example_framework_bindings",
       fn   = function(rdf) example_framework_bindings(rdf),
       ids  = "example"),
  list(name = "subpoint_framework_bindings",
       fn   = function(rdf) subpoint_framework_bindings(rdf),
       ids  = "subpoint"),
  list(name = "role_element_bindings",
       fn   = function(rdf) role_element_bindings(rdf),
       ids  = c("role", "element"))
)

test_that("the extended fixture really does share a local code across frameworks", {
  rdf <- make_shared_code_fixture_graph()

  elements <- element_framework_bindings(rdf)
  colliding <- elements$element[
    sub("^.*[#/]", "", elements$element) == fixture_shared_element_code
  ]
  expect_equal(length(colliding), 2L)
  expect_equal(length(unique(colliding)), 2L)
  # Two distinct IRIs, two distinct frameworks, one bare code.
  expect_equal(
    length(unique(elements$framework[elements$element %in% colliding])), 2L
  )

  roles <- role_framework_bindings(rdf)
  colliding_roles <- roles$role[
    sub("^.*[#/]", "", roles$role) == fixture_shared_role_code
  ]
  expect_equal(length(unique(colliding_roles)), 2L)
})

test_that("every cross-framework helper disambiguates by framework column or full IRI", {
  rdf <- make_shared_code_fixture_graph()

  for (case in key_safety_cases) {
    result <- case$fn(rdf)
    info   <- paste0(case$name, "()")

    expect_gt(nrow(result), 0L)

    has_framework_col <- "framework" %in% names(result)
    ids_are_iris <- all(vapply(
      case$ids, function(cl) looks_like_full_iri(result[[cl]]), logical(1)
    ))

    # The safety contract: at least one of the two must hold, or a caller
    # cannot tell a NICE T0516 from a CCSSF T0516.
    expect_true(
      has_framework_col || ids_are_iris,
      info = paste0(
        info, " returns neither a framework column nor full IRIs, so ",
        "identifiers from two frameworks sharing a local code cannot be ",
        "told apart"
      )
    )
  }
})

test_that("stripping identifiers to bare local codes collapses two frameworks", {
  # The negative control. This is what the contract above protects against:
  # once the namespace is thrown away, the two statements are the same key.
  rdf <- make_shared_code_fixture_graph()

  elements <- element_framework_bindings(rdf)
  bare <- sub("^.*[#/]", "", elements$element)

  expect_equal(sum(bare == fixture_shared_element_code), 2L)
  expect_true(anyDuplicated(bare) > 0L)

  # Whereas the full IRIs stay unique.
  expect_equal(anyDuplicated(elements$element), 0L)
})

test_that("role_element_bindings pairs stay resolvable to a single framework", {
  # role_element_bindings() is the one helper with no framework column. It
  # returns full IRIs on both sides, so each pair still resolves, but only
  # through a join. Documented here so the reliance is explicit.
  rdf <- make_shared_code_fixture_graph()

  pairs <- role_element_bindings(rdf)
  expect_false("framework" %in% names(pairs))
  expect_true(looks_like_full_iri(pairs$role))
  expect_true(looks_like_full_iri(pairs$element))

  resolved <- merge(
    pairs,
    element_framework_bindings(rdf)[, c("element", "framework")],
    by = "element"
  )
  colliding <- resolved[
    sub("^.*[#/]", "", resolved$element) == fixture_shared_element_code, ,
    drop = FALSE
  ]
  expect_equal(nrow(colliding), 2L)
  expect_equal(length(unique(colliding$framework)), 2L)
})
