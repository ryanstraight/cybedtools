# Tests for make_demo_graph().

test_that("make_demo_graph returns an rdf object", {
  skip_if_not_installed("rdflib")
  rdf <- make_demo_graph()
  expect_s3_class(rdf, "rdf")
})

test_that("make_demo_graph yields the documented structure", {
  skip_if_not_installed("rdflib")
  rdf <- make_demo_graph()

  # 2 frameworks
  fws <- framework_metadata(rdf)
  expect_equal(nrow(fws), 2)
  expect_setequal(fws$jurisdiction, c("US", "EU"))

  # 3 roles, all bound to a framework
  rfb <- role_framework_bindings(rdf)
  expect_equal(nrow(rfb), 3)

  # 5 elements, all bound to a framework
  efb <- element_framework_bindings(rdf)
  expect_equal(nrow(efb), 5)

  # 5 hasElement triples
  reb <- role_element_bindings(rdf)
  expect_equal(nrow(reb), 5)
})
