test_that("build_jsonld_context returns required base prefixes plus the framework", {
  ctx <- build_jsonld_context("nice")
  expect_true(all(c("schema", "skos", "rdfs", "cybed", "nice") %in% names(ctx)))
  expect_false("dcwf" %in% names(ctx))
})

test_that("build_jsonld_context rejects unknown prefixes", {
  expect_error(build_jsonld_context("fakeprefix"))
})

test_that("build_multi_framework_context includes all requested prefixes", {
  ctx <- build_multi_framework_context(c("nice", "sfia"))
  expect_true(all(c("nice", "sfia", "cybed") %in% names(ctx)))
})

test_that("build_framework_node produces dual-type @type and required fields", {
  node <- build_framework_node(
    framework_id     = "test-v1",
    framework_name   = "Test Framework",
    framework_prefix = "nice",
    version          = "1.0",
    publisher        = "Test Publisher",
    jurisdiction     = "US",
    sector           = "civilian",
    specificity      = "cybersecurity-specific"
  )
  expect_equal(node[["@id"]], "cybed:framework/test-v1")
  expect_true(all(c("nice:Framework", "cybed:Framework") %in% node[["@type"]]))
  expect_equal(node[["cybed:jurisdiction"]], "US")
})

test_that("build_role_node wires cybed:partOf when framework_id given", {
  node <- build_role_node(
    role_id              = "WRL-001",
    role_name            = "Test Role",
    framework_prefix     = "nice",
    framework_role_type  = "WorkRole",
    framework_id         = "test-v1"
  )
  expect_equal(node[["@id"]], "nice:WRL-001")
  expect_true(all(c("nice:WorkRole", "cybed:Role") %in% node[["@type"]]))
  expect_equal(node[["cybed:partOf"]][["@id"]], "cybed:framework/test-v1")
})

test_that("build_role_element_node omits cybed:partOf when framework_id is NA", {
  node <- build_role_element_node(
    element_id             = "E0001",
    framework_prefix       = "nice",
    framework_element_type = "TaskStatement",
    element_text           = "Sample task text."
  )
  expect_null(node[["cybed:partOf"]])
  expect_equal(node[["cybed:elementText"]], "Sample task text.")
})

test_that("validate_jsonld_node flags missing required fields", {
  incomplete <- list(`@id` = "test")
  result <- validate_jsonld_node(incomplete)
  expect_false(result$valid)
  expect_true("@type" %in% result$missing_fields)
})

test_that("build_multi_framework_context signals a classed condition for unknown prefix", {
  expect_error(
    build_multi_framework_context(c("nice", "not-a-prefix")),
    class = "cybedtools_unknown_prefix"
  )
})

test_that("read_jsonld_document signals classed condition when path is missing", {
  expect_error(
    read_jsonld_document(file.path(tempdir(), "definitely-not-a-real-file.jsonld")),
    class = "cybedtools_file_not_found"
  )
})
