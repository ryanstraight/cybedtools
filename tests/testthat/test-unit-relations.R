# Tier 1 unit-to-unit relations: build_related_unit_metadata() and
# build_unit_relation_node(). Both are meant to serve frameworks whose
# targets sit in another framework, whose relations carry no level, and
# whose targets are not roles, so each of those cases is exercised here.

# ---------------------------------------------------------------------------
# build_related_unit_metadata
# ---------------------------------------------------------------------------

test_that("build_related_unit_metadata emits one cybed:relatedUnit per target", {
  meta <- build_related_unit_metadata(c("skill-a", "skill-b"), "otccf")
  expect_named(meta, "cybed:relatedUnit")
  expect_length(meta[["cybed:relatedUnit"]], 2)
  expect_equal(
    vapply(meta[["cybed:relatedUnit"]], \(x) as.character(x[["@id"]]), character(1)),
    c("otccf:skill-a", "otccf:skill-b")
  )
})

test_that("build_related_unit_metadata de-duplicates repeated targets", {
  meta <- build_related_unit_metadata(c("skill-a", "skill-a", "skill-b"), "otccf")
  expect_length(meta[["cybed:relatedUnit"]], 2)
})

test_that("build_related_unit_metadata drops NA and empty targets", {
  meta <- build_related_unit_metadata(c("skill-a", NA, "", "skill-b"), "otccf")
  expect_length(meta[["cybed:relatedUnit"]], 2)
})

test_that("build_related_unit_metadata returns an empty list for no targets", {
  expect_equal(build_related_unit_metadata(character(0), "otccf"), list())
  expect_equal(build_related_unit_metadata(c(NA, ""), "otccf"), list())
})

test_that("build_related_unit_metadata mints targets under the target prefix", {
  meta <- build_related_unit_metadata(c("PROG", "SCTY"), "sfia")
  expect_equal(
    vapply(meta[["cybed:relatedUnit"]], \(x) as.character(x[["@id"]]), character(1)),
    c("sfia:PROG", "sfia:SCTY")
  )
})

test_that("build_related_unit_metadata takes one prefix per target", {
  meta <- build_related_unit_metadata(c("skill-a", "OG-WRL-015"),
                                      c("otccf", "nice"))
  expect_equal(
    vapply(meta[["cybed:relatedUnit"]], \(x) as.character(x[["@id"]]), character(1)),
    c("otccf:skill-a", "nice:OG-WRL-015")
  )
})

test_that("build_related_unit_metadata de-duplicates on the IRI, not the bare id", {
  # The same bare id under two prefixes is two targets, not one.
  meta <- build_related_unit_metadata(c("PROG", "PROG"), c("sfia", "otccf"))
  expect_length(meta[["cybed:relatedUnit"]], 2)
  expect_setequal(
    vapply(meta[["cybed:relatedUnit"]], \(x) as.character(x[["@id"]]), character(1)),
    c("sfia:PROG", "otccf:PROG")
  )

  # The same bare id under one prefix is one target.
  same <- build_related_unit_metadata(c("PROG", "PROG"), c("sfia", "sfia"))
  expect_length(same[["cybed:relatedUnit"]], 1)
})

test_that("build_related_unit_metadata rejects a to_prefix of the wrong length", {
  expect_error(
    build_related_unit_metadata(c("a", "b", "c"), c("otccf", "nice")),
    class = "cybedtools_bad_length"
  )
  expect_error(
    build_unit_relation_node(c("a", "b"), "x", "otccf"),
    class = "cybedtools_scalar_input"
  )
  expect_error(
    build_unit_relation_node("a", "x", "otccf", proficiency_level = c("3", "4")),
    class = "cybedtools_scalar_input"
  )
})

# ---------------------------------------------------------------------------
# build_unit_relation_node
# ---------------------------------------------------------------------------

test_that("build_unit_relation_node types the node and wires both endpoints", {
  rel <- build_unit_relation_node(
    from_unit_id   = "ot-cybersecurity-engineer",
    to_unit_id     = "network-security",
    from_prefix    = "otccf",
    relation_label = "requires"
  )
  expect_equal(rel[["@type"]], "cybed:UnitRelation")
  expect_equal(as.character(rel[["cybed:fromUnit"]][["@id"]]),
               "otccf:ot-cybersecurity-engineer")
  expect_equal(as.character(rel[["cybed:toUnit"]][["@id"]]),
               "otccf:network-security")
  expect_equal(rel[["cybed:relationLabel"]], "requires")
})

test_that("build_unit_relation_node defaults to_prefix to from_prefix", {
  rel <- build_unit_relation_node("role-a", "skill-b", from_prefix = "otccf")
  expect_equal(as.character(rel[["cybed:toUnit"]][["@id"]]), "otccf:skill-b")
})

test_that("build_unit_relation_node honours a cross-framework to_prefix", {
  rel <- build_unit_relation_node("role-a", "PROG",
                                  from_prefix = "otccf", to_prefix = "sfia")
  expect_equal(as.character(rel[["cybed:fromUnit"]][["@id"]]), "otccf:role-a")
  expect_equal(as.character(rel[["cybed:toUnit"]][["@id"]]),   "sfia:PROG")
})

test_that("build_unit_relation_node keeps a numeric level as character", {
  rel <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                  proficiency_level = 4)
  expect_type(rel[["cybed:proficiencyLevel"]], "character")
  expect_equal(rel[["cybed:proficiencyLevel"]], "4")
})

test_that("build_unit_relation_node keeps a word level verbatim", {
  rel <- build_unit_relation_node("role-a", "communication", "otccf",
                                  proficiency_level = "Advanced")
  expect_type(rel[["cybed:proficiencyLevel"]], "character")
  expect_equal(rel[["cybed:proficiencyLevel"]], "Advanced")
})

test_that("the level is part of the @id, so one pair at two levels gives two nodes", {
  low  <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                   proficiency_level = "3")
  high <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                   proficiency_level = "4")
  expect_false(identical(as.character(low[["@id"]]), as.character(high[["@id"]])))
  expect_match(as.character(low[["@id"]]),  "L3$")
  expect_match(as.character(high[["@id"]]), "L4$")
})

test_that("build_unit_relation_node omits optional fields left NA", {
  rel <- build_unit_relation_node("role-a", "skill-b", "otccf")
  expect_false("cybed:relationLabel"    %in% names(rel))
  expect_false("cybed:proficiencyLevel" %in% names(rel))
  expect_false("cybed:sourceSection"    %in% names(rel))
  expect_false("cybed:partOf"           %in% names(rel))
  expect_equal(as.character(rel[["@id"]]), "otccf:relation/role-a--skill-b")
})

test_that("the relation label is part of the @id, so two labels give two nodes", {
  requires <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                       relation_label    = "requires",
                                       proficiency_level = "3")
  supports <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                       relation_label    = "supports",
                                       proficiency_level = "3")
  expect_false(identical(as.character(requires[["@id"]]),
                         as.character(supports[["@id"]])))
})

test_that("the target's prefix is in the @id only when it differs from the source's", {
  same  <- build_unit_relation_node("role-a", "PROG", from_prefix = "otccf",
                                    relation_label = "requires")
  cross <- build_unit_relation_node("role-a", "PROG", from_prefix = "otccf",
                                    to_prefix = "sfia", relation_label = "requires")
  expect_false(identical(as.character(same[["@id"]]), as.character(cross[["@id"]])))
  expect_match(as.character(cross[["@id"]]), "sfia\\.PROG", fixed = FALSE)
  expect_false(grepl("sfia", as.character(same[["@id"]]), fixed = TRUE))
})

test_that("levels that differ only in punctuation stay distinct in the @id", {
  ids <- vapply(
    c("3, 4", "3-4", "3 4"),
    \(lvl) as.character(
      build_unit_relation_node("role-a", "skill-b", "otccf",
                               relation_label    = "requires",
                               proficiency_level = lvl)[["@id"]]
    ),
    character(1)
  )
  expect_length(unique(ids), 3)
})

test_that("a word level round-trips unchanged into cybed:proficiencyLevel", {
  rel <- build_unit_relation_node("role-a", "communication", "otccf",
                                  relation_label    = "requires",
                                  proficiency_level = "Advanced")
  expect_equal(rel[["cybed:proficiencyLevel"]], "Advanced")
})

test_that("the @id carries no spaces, commas, or percent signs", {
  rel <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                  relation_label    = "requires at least",
                                  proficiency_level = "3, 4 (advanced)")
  id <- as.character(rel[["@id"]])
  expect_false(grepl("[ ,%]", id))
})

test_that("build_unit_relation_node wires cybed:partOf when framework_id given", {
  rel <- build_unit_relation_node("role-a", "skill-b", "otccf",
                                  source_section = "Skills Map",
                                  framework_id   = "otccf-v1.1")
  expect_equal(as.character(rel[["cybed:partOf"]][["@id"]]),
               "cybed:framework/otccf-v1.1")
  expect_equal(rel[["cybed:sourceSection"]], "Skills Map")
})

# ---------------------------------------------------------------------------
# Merge into a unit node
# ---------------------------------------------------------------------------

test_that("relatedUnit metadata survives build_role_node alongside another key", {
  node <- build_role_node(
    role_id             = "role-a",
    role_name           = "Role A",
    framework_prefix    = "otccf",
    framework_role_type = "JobRole",
    framework_id        = "otccf-v1.1",
    metadata            = c(
      list(`cybed:sourceSection` = "Engineering"),
      build_related_unit_metadata(c("skill-a", "skill-b"), "otccf")
    )
  )
  expect_equal(node[["cybed:sourceSection"]], "Engineering")
  expect_equal(sum(names(node) == "cybed:relatedUnit"), 1L)
  expect_length(node[["cybed:relatedUnit"]], 2)
  expect_true("cybed:OrganizingUnit" %in% node[["@type"]])
})

test_that("relatedUnit metadata merges onto a non-role organizing unit", {
  node <- build_organizing_unit_node(
    unit_id           = "communication",
    unit_name         = "Communication",
    framework_prefix  = "otccf",
    framework_subtype = "CriticalCoreSkill",
    is_role           = FALSE,
    metadata          = build_related_unit_metadata("teamwork", "otccf")
  )
  expect_false("cybed:Role" %in% node[["@type"]])
  expect_length(node[["cybed:relatedUnit"]], 1)
})

# ---------------------------------------------------------------------------
# SPARQL round trip over the fixture graph
# ---------------------------------------------------------------------------

test_that("a relation is findable by fromUnit and carries its level", {
  skip_if_not_installed("rdflib")
  rdf <- make_fixture_graph()

  relations <- rdflib::rdf_query(rdf, paste0(
    "PREFIX cybed: <https://w3id.org/cybed/ontology#>\n",
    "SELECT ?rel ?level WHERE {\n",
    "  ?rel a cybed:UnitRelation ;\n",
    "       cybed:fromUnit <https://w3id.org/cybed/ontology#role/fixture-a1> ;\n",
    "       cybed:proficiencyLevel ?level .\n",
    "}"
  ))

  expect_equal(nrow(relations), 2)
  expect_setequal(relations$level, c("3", "5"))
})
