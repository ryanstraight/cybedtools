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
  # v0.2.0: workforce roles assert framework subtype + cybed:Role +
  # cybed:OrganizingUnit. All three are required for queries against the
  # workforce subset (cybed:Role) and the cross-framework abstract
  # (cybed:OrganizingUnit) to succeed against this node.
  expect_true(all(c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")
                  %in% node[["@type"]]))
  expect_equal(node[["cybed:partOf"]][["@id"]], "cybed:framework/test-v1")
})

test_that("build_organizing_unit_node with is_role = FALSE omits cybed:Role", {
  node <- build_organizing_unit_node(
    unit_id           = "PROG",
    unit_name         = "Programming",
    framework_prefix  = "sfia",
    framework_subtype = "Skill",
    is_role           = FALSE,
    framework_id      = "sfia-9"
  )
  expect_equal(node[["@id"]], "sfia:PROG")
  expect_true("sfia:Skill"          %in% node[["@type"]])
  expect_true("cybed:OrganizingUnit" %in% node[["@type"]])
  expect_false("cybed:Role"          %in% node[["@type"]])
})

test_that("build_organizing_unit_node with is_role = TRUE asserts cybed:Role", {
  node <- build_organizing_unit_node(
    unit_id           = "OG-WRL-015",
    unit_name         = "Cybersecurity Architecture",
    framework_prefix  = "nice",
    framework_subtype = "WorkRole",
    is_role           = TRUE,
    framework_id      = "nice-v2"
  )
  expect_true(all(c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")
                  %in% node[["@type"]]))
})

test_that("build_role_node delegates correctly: identical output to is_role = TRUE", {
  via_wrapper <- build_role_node(
    role_id              = "WRL-001",
    role_name            = "Test Role",
    framework_prefix     = "nice",
    framework_role_type  = "WorkRole",
    framework_id         = "test-v1"
  )
  via_canonical <- build_organizing_unit_node(
    unit_id           = "WRL-001",
    unit_name         = "Test Role",
    framework_prefix  = "nice",
    framework_subtype = "WorkRole",
    is_role           = TRUE,
    framework_id      = "test-v1"
  )
  expect_identical(via_wrapper, via_canonical)
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

test_that("parse_subpoints tags Clarification-statement fragments as Example", {
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
  # "Clarification statement:" presence routes to cybed:Example downstream.
  expect_true(all(result$node_type == "Example"))
})

test_that("parse_subpoints tags 'such as' enumerations as Subpoint", {
  text <- "Authentication methods, such as certificate, token-based, two-factor, multifactor, and biometric"
  result <- parse_subpoints(text)
  expect_equal(nrow(result), 5L)
  expect_setequal(
    result$text,
    c("certificate", "token-based", "two-factor", "multifactor", "biometric")
  )
  # Framework-as-specified enumeration: routes to cybed:Subpoint downstream.
  expect_true(all(result$node_type == "Subpoint"))
})

test_that("parse_subpoints returns empty tibble (with v0.2.0 schema) for narrative text", {
  result <- parse_subpoints("Designs enterprise security architectures.")
  expect_equal(nrow(result), 0L)
  expect_named(result, c("ordinal", "text", "node_type"))
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

test_that("parse_subpoints distinguishes Clarification-statement vs enumeration patterns within mixed input", {
  # Same list payload, two different framing prefixes. Should produce
  # different node_type values. Items must be at least 3 characters
  # because parse_subpoints filters single-character noise.
  text_clarification <- "Describe rule. Clarification statement: examples such as alpha, beta, and gamma"
  text_enumeration   <- "Authentication methods such as alpha, beta, and gamma"

  r_clar <- parse_subpoints(text_clarification)
  r_enum <- parse_subpoints(text_enumeration)

  expect_equal(nrow(r_clar), 3L)
  expect_true(all(r_clar$node_type == "Example"))
  expect_equal(nrow(r_enum), 3L)
  expect_true(all(r_enum$node_type == "Subpoint"))
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

test_that("expand_with_subpoints returns parents unchanged when no enumerations present", {
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
  expect_equal(nrow(result$subnode_index), 0L)
  expect_named(result$subnode_index,
               c("parent_id", "subnode_id", "ordinal", "node_type"))
})

test_that("expand_with_subpoints routes Clarification fragments to cybed:Example", {
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
  # Parent + 3 children
  expect_equal(length(result$nodes), 4L)
  expect_equal(nrow(result$subnode_index), 3L)
  expect_true(all(result$subnode_index$node_type == "Example"))
  expect_setequal(
    result$subnode_index$subnode_id,
    c("K-2.SEC.AUTH.example.1", "K-2.SEC.AUTH.example.2", "K-2.SEC.AUTH.example.3")
  )
  expect_true(all(result$subnode_index$parent_id == "K-2.SEC.AUTH"))

  # Parent (first node) carries cybed:hasExample for each Example child.
  expanded_parent <- result$nodes[[1]]
  expect_false(is.null(expanded_parent[["cybed:hasExample"]]))
  expect_length(expanded_parent[["cybed:hasExample"]], 3L)

  # Examples carry cybed:Example + cybed:RoleElement only (no
  # framework-native subtype).
  ex_types <- result$nodes[[2]][["@type"]]
  expect_setequal(ex_types, c("cybed:Example", "cybed:RoleElement"))
  expect_false("cyberorg:Standard" %in% ex_types)
})

test_that("expand_with_subpoints routes 'such as' fragments to cybed:Subpoint and inherits parent subtype", {
  parent <- build_role_element_node(
    element_id             = "T1",
    framework_prefix       = "nice",
    framework_element_type = "TaskStatement",
    element_text           = "Apply controls. Such as access control, encryption, and monitoring.",
    framework_id           = "nice-v2"
  )
  result <- expand_with_subpoints(
    list(parent),
    framework_prefix = "nice",
    framework_id     = "nice-v2",
    framework_slug   = "nice"
  )
  expect_equal(nrow(result$subnode_index), 3L)
  expect_true(all(result$subnode_index$node_type == "Subpoint"))
  expect_setequal(
    result$subnode_index$subnode_id,
    c("T1.sub.1", "T1.sub.2", "T1.sub.3")
  )
  # Subpoint inherits parent's framework subtype + cybed:Subpoint + cybed:RoleElement
  sp_types <- result$nodes[[2]][["@type"]]
  expect_true("nice:TaskStatement" %in% sp_types)
  expect_true("cybed:Subpoint"     %in% sp_types)
  expect_true("cybed:RoleElement"  %in% sp_types)

  # Parent does NOT carry cybed:hasExample (no Example children emitted).
  expect_null(result$nodes[[1]][["cybed:hasExample"]])
})

test_that("expand_with_subpoints idempotent: same input yields same IRIs and node_types", {
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
  expect_identical(r1$subnode_index, r2$subnode_index)
})

# ---------------------------------------------------------------------------
# extend_role_element_ids
# ---------------------------------------------------------------------------

test_that("extend_role_element_ids appends Subpoint IDs whose parent is in the input", {
  index <- tibble::tibble(
    parent_id  = c("E1", "E1", "E2", "E3"),
    subnode_id = c("E1.sub.1", "E1.sub.2", "E2.sub.1", "E3.sub.1"),
    ordinal    = c(1L, 2L, 1L, 1L),
    node_type  = c("Subpoint", "Subpoint", "Subpoint", "Subpoint")
  )
  result <- extend_role_element_ids(c("E1", "E2"), index)
  expect_setequal(
    result,
    c("E1", "E2", "E1.sub.1", "E1.sub.2", "E2.sub.1")
  )
  # Order: parents first, Subpoints after
  expect_equal(result[1:2], c("E1", "E2"))
})

test_that("extend_role_element_ids excludes Example IDs from cybed:hasElement", {
  # Mixed index: one Subpoint and one Example. extend_role_element_ids
  # is the back-fill path for cybed:hasElement; Examples must be excluded
  # so they remain reachable only via the parent's cybed:hasExample.
  index <- tibble::tibble(
    parent_id  = c("E1", "E1"),
    subnode_id = c("E1.sub.1", "E1.example.1"),
    ordinal    = c(1L, 1L),
    node_type  = c("Subpoint", "Example")
  )
  result <- extend_role_element_ids(c("E1"), index)
  expect_setequal(result, c("E1", "E1.sub.1"))
  expect_false("E1.example.1" %in% result)
})

test_that("extend_role_element_ids returns parents unchanged when index is empty", {
  empty <- tibble::tibble(
    parent_id  = character(0),
    subnode_id = character(0),
    ordinal    = integer(0),
    node_type  = character(0)
  )
  result <- extend_role_element_ids(c("E1", "E2"), empty)
  expect_equal(result, c("E1", "E2"))
})

test_that("extend_role_element_ids deduplicates input parent IDs", {
  empty <- tibble::tibble(
    parent_id  = character(0),
    subnode_id = character(0),
    ordinal    = integer(0),
    node_type  = character(0)
  )
  result <- extend_role_element_ids(c("E1", "E1", "E2"), empty)
  expect_equal(result, c("E1", "E2"))
})

# ---------------------------------------------------------------------------
# build_example_node
# ---------------------------------------------------------------------------

test_that("build_example_node produces deterministic IRI parent_iri.example.N", {
  ex <- build_example_node(
    parent_element_id = "K-2.SEC.AUTH",
    ordinal           = 1L,
    text              = "not using common words as passwords",
    framework_prefix  = "cyberorg",
    framework_id      = "cyberorg-k12-v1.0"
  )
  expect_equal(as.character(ex[["@id"]]), "cyberorg:K-2.SEC.AUTH.example.1")
})

test_that("build_example_node carries cybed:Example + cybed:RoleElement only (no framework subtype)", {
  ex <- build_example_node(
    parent_element_id = "3A-IC-24",
    ordinal           = 2L,
    text              = "considering user preferences",
    framework_prefix  = "csta",
    framework_id      = "csta-2017"
  )
  # No framework-native subtype on Examples.
  expect_setequal(ex[["@type"]], c("cybed:Example", "cybed:RoleElement"))
  expect_false("csta:Standard"            %in% ex[["@type"]])
  expect_false("csta:StandardGroup"      %in% ex[["@type"]])
})

test_that("build_example_node attaches cybed:partOf to the framework but no cybed:elaborates", {
  ex <- build_example_node(
    parent_element_id = "X1",
    ordinal           = 1L,
    text              = "fragment",
    framework_prefix  = "cyberorg",
    framework_id      = "cyberorg-k12-v1.0"
  )
  expect_equal(
    as.character(ex[["cybed:partOf"]][["@id"]]),
    "cybed:framework/cyberorg-k12-v1.0"
  )
  # Examples deliberately do not carry cybed:elaborates; the parent owns
  # the example via cybed:hasExample, not the converse.
  expect_null(ex[["cybed:elaborates"]])
})
