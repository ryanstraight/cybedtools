# Fixture graph used by test-sparql-helpers.R.
#
# Builds a tiny synthetic two-framework graph in memory using rdflib::rdf()
# and rdf_add(), encoding the structural invariants the SPARQL helpers
# must satisfy under the v0.2.0 vocabulary. Lives in helper-*.R so testthat
# sources it once before running tests in this directory.
#
# Structure:
#   - 2 frameworks (fw_a: US/civilian/cybersecurity-specific,
#                   fw_b: EU/general/general-IT)
#   - 5 organizing units: 3 bound to a framework, 1 orphan (no partOf),
#       1 with partOf pointing at a non-Framework subject. All 5 are
#       typed cybed:Role AND cybed:OrganizingUnit (workforce-shaped
#       fixture).
#   - 6 elements: 5 bound to a framework, 1 orphan
#   - 5 cybed:hasElement triples (role -> element)
#   - 5 cybed:Subpoint nodes (2 children of el_a1, 3 children of el_b1),
#       each carrying cybed:Subpoint + cybed:RoleElement, cybed:elaborates
#       back to parent, cybed:partOf to framework, and reachable from
#       their cluster via cybed:hasElement
#   - 1 cybed:Example node (el_a2_ex1, child of el_a2), carrying
#       cybed:Example + cybed:RoleElement only (no framework-native
#       subtype) and reachable only via el_a2's cybed:hasExample.
#       Deliberately NOT added to any role's cybed:hasElement, so
#       Example exclusion from default cluster traversals is testable.
#   - 1 duplicate cybed:partOf triple (verifies rdf set semantics
#       prevent double-counting in domain helpers)

cybed_uri  <- "https://w3id.org/cybed/ontology#"
schema_uri <- "http://schema.org/"
rdf_type   <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

cybed_term <- function(local) paste0(cybed_uri, local)
schema_term <- function(local) paste0(schema_uri, local)

make_fixture_graph <- function() {
  rdf <- rdflib::rdf()

  fw_a <- cybed_term("framework/fixture-fw-a")
  fw_b <- cybed_term("framework/fixture-fw-b")

  framework_class       <- cybed_term("Framework")
  role_class            <- cybed_term("Role")
  organizing_unit_class <- cybed_term("OrganizingUnit")
  element_class         <- cybed_term("RoleElement")
  example_class         <- cybed_term("Example")

  # Framework A
  rdflib::rdf_add(rdf, fw_a, rdf_type,                       framework_class)
  rdflib::rdf_add(rdf, fw_a, schema_term("name"),            "Fixture Framework A")
  rdflib::rdf_add(rdf, fw_a, cybed_term("jurisdiction"),     "US")
  rdflib::rdf_add(rdf, fw_a, cybed_term("sector"),           "civilian")
  rdflib::rdf_add(rdf, fw_a, cybed_term("specificity"),      "cybersecurity-specific")

  # Framework B
  rdflib::rdf_add(rdf, fw_b, rdf_type,                       framework_class)
  rdflib::rdf_add(rdf, fw_b, schema_term("name"),            "Fixture Framework B")
  rdflib::rdf_add(rdf, fw_b, cybed_term("jurisdiction"),     "EU")
  rdflib::rdf_add(rdf, fw_b, cybed_term("sector"),           "general")
  rdflib::rdf_add(rdf, fw_b, cybed_term("specificity"),      "general-IT")

  role_a1     <- cybed_term("role/fixture-a1")
  role_a2     <- cybed_term("role/fixture-a2")
  role_b1     <- cybed_term("role/fixture-b1")
  role_orphan <- cybed_term("role/fixture-orphan")
  role_bad    <- cybed_term("role/fixture-bad-partof")

  # Workforce-shaped fixture: each role asserts cybed:Role AND
  # cybed:OrganizingUnit. librdf does not perform subClassOf inference,
  # so both types are emitted explicitly to match the v0.2.0 emission
  # rule used by build_organizing_unit_node(is_role = TRUE).
  for (r in c(role_a1, role_a2, role_b1, role_orphan, role_bad)) {
    rdflib::rdf_add(rdf, r, rdf_type, role_class)
    rdflib::rdf_add(rdf, r, rdf_type, organizing_unit_class)
  }
  rdflib::rdf_add(rdf, role_a1,     schema_term("name"), "Role A1")
  rdflib::rdf_add(rdf, role_a2,     schema_term("name"), "Role A2")
  rdflib::rdf_add(rdf, role_b1,     schema_term("name"), "Role B1")
  rdflib::rdf_add(rdf, role_orphan, schema_term("name"), "Orphan Role")
  rdflib::rdf_add(rdf, role_bad,    schema_term("name"), "Bad Partof Role")

  rdflib::rdf_add(rdf, role_a1, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, role_a2, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, role_b1, cybed_term("partOf"), fw_b)
  # role_bad's partOf target is itself not typed cybed:Framework
  rdflib::rdf_add(rdf, role_bad, cybed_term("partOf"),
                  cybed_term("framework/fixture-nonexistent"))

  el_a1     <- cybed_term("element/fixture-el-a1")
  el_a2     <- cybed_term("element/fixture-el-a2")
  el_a3     <- cybed_term("element/fixture-el-a3")
  el_b1     <- cybed_term("element/fixture-el-b1")
  el_b2     <- cybed_term("element/fixture-el-b2")
  el_orphan <- cybed_term("element/fixture-el-orphan")

  for (e in c(el_a1, el_a2, el_a3, el_b1, el_b2, el_orphan)) {
    rdflib::rdf_add(rdf, e, rdf_type, element_class)
  }
  rdflib::rdf_add(rdf, el_a1, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_a2, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_a3, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_b1, cybed_term("partOf"), fw_b)
  rdflib::rdf_add(rdf, el_b2, cybed_term("partOf"), fw_b)
  # el_orphan deliberately has no partOf

  rdflib::rdf_add(rdf, role_a1, cybed_term("hasElement"), el_a1)
  rdflib::rdf_add(rdf, role_a1, cybed_term("hasElement"), el_a2)
  rdflib::rdf_add(rdf, role_a2, cybed_term("hasElement"), el_a3)
  rdflib::rdf_add(rdf, role_b1, cybed_term("hasElement"), el_b1)
  rdflib::rdf_add(rdf, role_b1, cybed_term("hasElement"), el_b2)

  # Sub-points (added v0.1.1). el_a1 has 2 sub-points, el_b1 has 3.
  # Sub-points carry: cybed:Subpoint + cybed:RoleElement types,
  # cybed:elaborates -> parent, cybed:partOf -> framework,
  # and the cluster (role) cybed:hasElement extends to include them.
  subpoint_class <- cybed_term("Subpoint")

  el_a1_sub1 <- cybed_term("element/fixture-el-a1.sub.1")
  el_a1_sub2 <- cybed_term("element/fixture-el-a1.sub.2")
  el_b1_sub1 <- cybed_term("element/fixture-el-b1.sub.1")
  el_b1_sub2 <- cybed_term("element/fixture-el-b1.sub.2")
  el_b1_sub3 <- cybed_term("element/fixture-el-b1.sub.3")

  for (sp in c(el_a1_sub1, el_a1_sub2, el_b1_sub1, el_b1_sub2, el_b1_sub3)) {
    rdflib::rdf_add(rdf, sp, rdf_type, element_class)
    rdflib::rdf_add(rdf, sp, rdf_type, subpoint_class)
  }

  # cybed:elaborates: sub-point -> parent
  rdflib::rdf_add(rdf, el_a1_sub1, cybed_term("elaborates"), el_a1)
  rdflib::rdf_add(rdf, el_a1_sub2, cybed_term("elaborates"), el_a1)
  rdflib::rdf_add(rdf, el_b1_sub1, cybed_term("elaborates"), el_b1)
  rdflib::rdf_add(rdf, el_b1_sub2, cybed_term("elaborates"), el_b1)
  rdflib::rdf_add(rdf, el_b1_sub3, cybed_term("elaborates"), el_b1)

  # cybed:partOf: sub-point -> framework (matches parent's framework)
  rdflib::rdf_add(rdf, el_a1_sub1, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_a1_sub2, cybed_term("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_b1_sub1, cybed_term("partOf"), fw_b)
  rdflib::rdf_add(rdf, el_b1_sub2, cybed_term("partOf"), fw_b)
  rdflib::rdf_add(rdf, el_b1_sub3, cybed_term("partOf"), fw_b)

  # Cluster (role) cybed:hasElement extends to include the sub-points.
  # role_a1 originally had {el_a1, el_a2}; adding 2 sub-points of el_a1.
  rdflib::rdf_add(rdf, role_a1, cybed_term("hasElement"), el_a1_sub1)
  rdflib::rdf_add(rdf, role_a1, cybed_term("hasElement"), el_a1_sub2)
  # role_b1 originally had {el_b1, el_b2}; adding 3 sub-points of el_b1.
  rdflib::rdf_add(rdf, role_b1, cybed_term("hasElement"), el_b1_sub1)
  rdflib::rdf_add(rdf, role_b1, cybed_term("hasElement"), el_b1_sub2)
  rdflib::rdf_add(rdf, role_b1, cybed_term("hasElement"), el_b1_sub3)

  # Duplicate partOf triple. RDF set semantics should dedupe; the domain
  # helpers must not double-count regardless.
  rdflib::rdf_add(rdf, role_a1, cybed_term("partOf"), fw_a)

  # cybed:Example child of el_a2. Mirrors the Cyber.org K-12 / CSTA
  # Clarification-statement promotion path. Example carries
  # cybed:Example + cybed:RoleElement only (no framework-native subtype),
  # has cybed:partOf to its parent's framework, and is reachable from
  # above only via el_a2's cybed:hasExample. NOT added to role_a2's
  # cybed:hasElement so the exclusion-from-default-traversal invariant
  # is testable.
  el_a2_ex1 <- cybed_term("element/fixture-el-a2.example.1")
  rdflib::rdf_add(rdf, el_a2_ex1, rdf_type,                element_class)
  rdflib::rdf_add(rdf, el_a2_ex1, rdf_type,                example_class)
  rdflib::rdf_add(rdf, el_a2_ex1, cybed_term("partOf"),    fw_a)
  rdflib::rdf_add(rdf, el_a2,     cybed_term("hasExample"), el_a2_ex1)

  rdf
}
