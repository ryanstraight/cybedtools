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

# ---------------------------------------------------------------------------
# parse_subpoints
# ---------------------------------------------------------------------------

test_that("parse_subpoints extracts semicolon-separated sub-points after Clarification statement", {
  text <- paste(
    "Describe the concept of a good password.",
    "Clarification statement: Focus on examples such as not using common words;",
    "pass phrases being more secure than passwords;",
    "and combining letters, numbers, and symbols being more secure than pass phrases."
  )
  result <- parse_subpoints(text)
  expect_equal(nrow(result), 3L)
  expect_equal(result$ordinal, 1:3)
  expect_match(result$text[[1]], "common words")
  expect_match(result$text[[2]], "pass phrases")
  expect_match(result$text[[3]], "combining letters")
})

test_that("parse_subpoints extracts comma-separated sub-points from 'such as' lists", {
  text <- "Authentication methods, such as certificate, token-based, two-factor, multifactor, and biometric"
  result <- parse_subpoints(text)
  expect_equal(nrow(result), 5L)
  expect_setequal(
    result$text,
    c("certificate", "token-based", "two-factor", "multifactor", "biometric")
  )
})

test_that("parse_subpoints returns empty tibble for narrative text without enumeration", {
  result <- parse_subpoints("Designs enterprise security architectures.")
  expect_equal(nrow(result), 0L)
  expect_named(result, c("ordinal", "text"))
})

test_that("parse_subpoints is NA-safe and empty-string-safe", {
  expect_equal(nrow(parse_subpoints(NA_character_)), 0L)
  expect_equal(nrow(parse_subpoints("")), 0L)
  expect_equal(nrow(parse_subpoints(NULL)), 0L)
})

test_that("parse_subpoints respects CYBED_DISABLE_SUBPOINT_PARSER per framework", {
  text <- "Authentication methods, such as certificate, token-based, two-factor, multifactor, and biometric"
  withr::with_envvar(c(CYBED_DISABLE_SUBPOINT_PARSER = "sfia,nice"), {
    expect_equal(nrow(parse_subpoints(text, framework_slug = "sfia")), 0L)
    expect_equal(nrow(parse_subpoints(text, framework_slug = "csta")), 5L)
    expect_equal(nrow(parse_subpoints(text, framework_slug = NULL)), 5L)
  })
})

test_that("parse_subpoints is deterministic across repeated calls (idempotency)", {
  text <- "Methods such as foo, bar, and baz."
  r1 <- parse_subpoints(text)
  r2 <- parse_subpoints(text)
  expect_identical(r1, r2)
})

# ---------------------------------------------------------------------------
# build_subpoint_node
# ---------------------------------------------------------------------------

test_that("build_subpoint_node produces deterministic IRI parent_iri.sub.N", {
  sp <- build_subpoint_node(
    parent_element_id = "K-2.SEC.AUTH",
    ordinal           = 3L,
    text              = "combining letters, numbers, and symbols",
    framework_prefix  = "cyberorg",
    framework_id      = "cyberorg-k12-v1.0",
    parent_subtype    = "Standard"
  )
  expect_equal(as.character(sp[["@id"]]), "cyberorg:K-2.SEC.AUTH.sub.3")
})

test_that("build_subpoint_node carries triple type: framework subtype + cybed:Subpoint + cybed:RoleElement", {
  sp <- build_subpoint_node(
    parent_element_id = "STPL-3",
    ordinal           = 1L,
    text              = "financial impact assessment",
    framework_prefix  = "sfia",
    framework_id      = "sfia-9",
    parent_subtype    = "SkillLevel"
  )
  expect_setequal(
    sp[["@type"]],
    c("sfia:SkillLevel", "cybed:Subpoint", "cybed:RoleElement")
  )
})

test_that("build_subpoint_node wires cybed:elaborates back to parent IRI", {
  sp <- build_subpoint_node(
    parent_element_id = "T0001",
    ordinal           = 2L,
    text              = "example fragment",
    framework_prefix  = "nice",
    framework_id      = "nice-v2",
    parent_subtype    = "TaskStatement"
  )
  expect_equal(as.character(sp[["cybed:elaborates"]][["@id"]]), "nice:T0001")
})

test_that("build_subpoint_node attaches cybed:partOf to the framework node", {
  sp <- build_subpoint_node(
    parent_element_id = "X1",
    ordinal           = 1L,
    text              = "fragment",
    framework_prefix  = "nice",
    framework_id      = "nice-v2",
    parent_subtype    = "TaskStatement"
  )
  expect_equal(
    as.character(sp[["cybed:partOf"]][["@id"]]),
    "cybed:framework/nice-v2"
  )
})

# ---------------------------------------------------------------------------
# expand_with_subpoints
# ---------------------------------------------------------------------------

test_that("expand_with_subpoints returns parents unchanged when no clarifications present", {
  parent <- build_role_element_node(
    element_id             = "T0001",
    framework_prefix       = "nice",
    framework_element_type = "TaskStatement",
    element_text           = "Designs security architectures.",
    framework_id           = "nice-v2"
  )
  result <- expand_with_subpoints(
    list(parent),
    framework_prefix = "nice",
    framework_id     = "nice-v2",
    framework_slug   = "nice"
  )
  expect_length(result$nodes, 1L)
  expect_equal(nrow(result$subpoint_index), 0L)
})

test_that("expand_with_subpoints emits parent + N sub-points for an enumerated clarification", {
  parent <- build_role_element_node(
    element_id             = "K-2.SEC.AUTH",
    framework_prefix       = "cyberorg",
    framework_element_type = "Standard",
    element_text           = paste(
      "Describe a good password.",
      "Clarification statement: Examples such as common words; pass phrases; combining symbols."
    ),
    framework_id           = "cyberorg-k12-v1.0"
  )
  result <- expand_with_subpoints(
    list(parent),
    framework_prefix = "cyberorg",
    framework_id     = "cyberorg-k12-v1.0",
    framework_slug   = "cyberorg-k12"
  )
  expect_equal(length(result$nodes), 4L)  # 1 parent + 3 sub-points
  expect_equal(nrow(result$subpoint_index), 3L)
  expect_setequal(
    result$subpoint_index$subpoint_id,
    c("K-2.SEC.AUTH.sub.1", "K-2.SEC.AUTH.sub.2", "K-2.SEC.AUTH.sub.3")
  )
  expect_true(all(result$subpoint_index$parent_id == "K-2.SEC.AUTH"))
})

test_that("expand_with_subpoints derives parent subtype from parent's @type", {
  parent <- build_role_element_node(
    element_id             = "K-2.SEC.AUTH",
    framework_prefix       = "cyberorg",
    framework_element_type = "Standard",
    element_text           = paste(
      "X. Clarification statement:",
      "examples such as alpha cases; beta cases; gamma cases."
    ),
    framework_id           = "cyberorg-k12-v1.0"
  )
  result <- expand_with_subpoints(
    list(parent),
    framework_prefix = "cyberorg",
    framework_id     = "cyberorg-k12-v1.0",
    framework_slug   = "cyberorg-k12"
  )
  # Sub-point should inherit "Standard" framework subtype from the parent
  sp_types <- result$nodes[[2]][["@type"]]
  expect_true("cyberorg:Standard" %in% sp_types)
  expect_true("cybed:Subpoint" %in% sp_types)
})

test_that("expand_with_subpoints idempotent: same input yields same IRIs", {
  parent <- build_role_element_node(
    element_id             = "T1",
    framework_prefix       = "nice",
    framework_element_type = "TaskStatement",
    element_text           = "X. Such as alpha cases, beta cases, gamma cases.",
    framework_id           = "nice-v2"
  )
  r1 <- expand_with_subpoints(list(parent), "nice", "nice-v2",
                              framework_slug = "nice")
  r2 <- expand_with_subpoints(list(parent), "nice", "nice-v2",
                              framework_slug = "nice")
  expect_identical(r1$subpoint_index$subpoint_id, r2$subpoint_index$subpoint_id)
})

# ---------------------------------------------------------------------------
# extend_role_element_ids
# ---------------------------------------------------------------------------

test_that("extend_role_element_ids appends sub-points whose parent is in the input", {
  index <- tibble::tibble(
    parent_id   = c("E1", "E1", "E2", "E3"),
    subpoint_id = c("E1.sub.1", "E1.sub.2", "E2.sub.1", "E3.sub.1"),
    ordinal     = c(1L, 2L, 1L, 1L)
  )
  result <- extend_role_element_ids(c("E1", "E2"), index)
  expect_setequal(
    result,
    c("E1", "E2", "E1.sub.1", "E1.sub.2", "E2.sub.1")
  )
  # Order: parents first, sub-points after
  expect_equal(result[1:2], c("E1", "E2"))
})

test_that("extend_role_element_ids returns parents unchanged when index is empty", {
  empty <- tibble::tibble(
    parent_id = character(0),
    subpoint_id = character(0),
    ordinal = integer(0)
  )
  result <- extend_role_element_ids(c("E1", "E2"), empty)
  expect_equal(result, c("E1", "E2"))
})

test_that("extend_role_element_ids deduplicates input parent IDs", {
  empty <- tibble::tibble(
    parent_id = character(0),
    subpoint_id = character(0),
    ordinal = integer(0)
  )
  result <- extend_role_element_ids(c("E1", "E1", "E2"), empty)
  expect_equal(result, c("E1", "E2"))
})
