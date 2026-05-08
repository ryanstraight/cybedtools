# Tests for make_demo_graph().

test_that("make_demo_graph returns an rdf object", {
  skip_if_not_installed("rdflib")
  rdf <- make_demo_graph()
  expect_s3_class(rdf, "rdf")
})

test_that("make_demo_graph yields the documented v0.2.0 structure", {
  skip_if_not_installed("rdflib")
  rdf <- make_demo_graph()

  # 2 frameworks
  fws <- framework_metadata(rdf)
  expect_equal(nrow(fws), 2)
  expect_setequal(fws$jurisdiction, c("US", "EU"))

  # 3 organizing units bound to a framework. All three appear via the
  # cross-framework cybed:OrganizingUnit query.
  ofb <- organizing_unit_framework_bindings(rdf)
  expect_equal(nrow(ofb), 3)

  # Only 2 of those units are cybed:Role: the workforce-shaped framework's
  # units. The non-workforce framework's unit is OrganizingUnit only.
  rfb <- role_framework_bindings(rdf)
  expect_equal(nrow(rfb), 2)
  expect_true(all(grepl("demo-a[12]$", rfb$role)))

  # 7 elements bound to a framework: 5 atomic elements + 1 Subpoint + 1
  # Example. All three are typed cybed:RoleElement.
  efb <- element_framework_bindings(rdf)
  expect_equal(nrow(efb), 7)

  # Exactly 1 Example, in the non-workforce-shaped framework, reachable
  # only via cybed:hasExample.
  exb <- example_framework_bindings(rdf)
  expect_equal(nrow(exb), 1)
  expect_equal(exb$framework_name, "Demo Framework B")

  # 6 cybed:hasElement triples: 5 original + 1 Subpoint added as a
  # cluster child. The Example is deliberately NOT in cybed:hasElement.
  reb <- role_element_bindings(rdf)
  expect_equal(nrow(reb), 6)
  expect_false(any(grepl("\\.example\\.\\d+$", reb$element)))
})
