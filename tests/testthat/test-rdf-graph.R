test_that("load_single_framework_graph returns an rdf object", {
  skip_if_not_installed("rdflib")
  skip_if_not(file.exists(here::here("data/processed/jsonld/ecsf.jsonld")),
              "ecsf.jsonld not assembled (run scripts/020-assemble-jsonld.R first)")

  rdf <- load_single_framework_graph("ecsf")
  expect_s3_class(rdf, "rdf")
})

test_that("load_single_framework_graph errors on missing framework", {
  skip_if_not_installed("rdflib")
  expect_error(load_single_framework_graph("nonexistent-framework"),
               "JSON-LD not found")
})

test_that("load_unified_rdf_graph produces a queryable graph for all frameworks", {
  skip_if_not_installed("rdflib")
  skip_if_not(file.exists(here::here("data/processed/jsonld/ecsf.jsonld")),
              "JSON-LD not assembled")

  rdf <- load_unified_rdf_graph()
  # Graph should contain at least one cybed:Framework node
  result <- rdflib::rdf_query(rdf, "PREFIX cybed: <https://w3id.org/cybed/ontology#>
SELECT ?f WHERE { ?f a cybed:Framework }")
  expect_true(nrow(result) >= 1)
})
