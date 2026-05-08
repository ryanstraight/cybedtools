# Tiny in-memory demo graph for first-time users and runnable examples.
# Mirrors the structural shape of tests/testthat/helper-fixture-graph.R but is
# exported so users who install the package without staging real framework
# data can still exercise the SPARQL helpers.

#' Build a small in-memory demo RDF graph
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Returns an `rdf` object containing a synthetic two-framework graph with
#' the structural shape the package's helpers expect under the v0.2.0
#' vocabulary:
#'
#' - **Framework A** (US, civilian, cybersecurity-specific) is
#'   workforce-shaped: its 2 organizing units are typed `cybed:Role`
#'   and `cybed:OrganizingUnit`, mirroring NICE / DCWF / ENISA ECSF.
#' - **Framework B** (EU, general, general-IT) is non-workforce-shaped:
#'   its 1 organizing unit is typed `cybed:OrganizingUnit` only,
#'   mirroring SFIA / Cyber.org K-12 / CSTA / CSEC2017 / DigComp 2.2.
#'
#' The graph also includes 5 atomic elements (typed `cybed:RoleElement`),
#' one `cybed:Subpoint` (an enumerated child of an element, reachable via
#' the role's `cybed:hasElement`), and one `cybed:Example` (a pedagogical-
#' scaffolding child, reachable only via the parent element's
#' `cybed:hasExample` and excluded from default `cybed:hasElement`
#' traversals). This is enough to exercise the cross-framework pivots
#' (`cybed:OrganizingUnit`), the workforce-only pivots (`cybed:Role`),
#' the Subpoint vs Example separation, and the per-framework pivots in
#' a single small graph.
#'
#' Use this to:
#'
#' - Verify the package is installed and SPARQL execution works on your
#'   system (helpful when troubleshooting `librdf` system-library issues).
#' - Try out the domain helpers before running the full pipeline.
#' - Develop new helpers or queries against a graph small enough to
#'   reason about by hand.
#'
#' For real cross-framework analysis, use [load_combined_ntriples_graph()]
#' against a graph assembled from staged framework sources.
#'
#' @return An `rdf` object containing roughly 50 triples.
#' @family RDF graph loading
#' @export
#' @examples
#' rdf <- make_demo_graph()
#' framework_metadata(rdf)
#' organizing_unit_framework_bindings(rdf)   # all three units, both frameworks
#' role_framework_bindings(rdf)              # only the two workforce-shaped units
#' sparql_pairs(rdf, "cybed:hasExample")     # the parent -> example link
make_demo_graph <- function() {
  cybed   <- "https://w3id.org/cybed/ontology#"
  schema  <- "http://schema.org/"
  rdftype <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  cybed_t  <- function(local) paste0(cybed, local)
  schema_t <- function(local) paste0(schema, local)

  rdf <- rdflib::rdf()

  fw_a <- cybed_t("framework/demo-fw-a")
  fw_b <- cybed_t("framework/demo-fw-b")
  framework_class       <- cybed_t("Framework")
  organizing_unit_class <- cybed_t("OrganizingUnit")
  role_class            <- cybed_t("Role")
  element_class         <- cybed_t("RoleElement")
  subpoint_class        <- cybed_t("Subpoint")
  example_class         <- cybed_t("Example")

  # Framework A: workforce-shaped (work-role flavor).
  rdflib::rdf_add(rdf, fw_a, rdftype,                   framework_class)
  rdflib::rdf_add(rdf, fw_a, schema_t("name"),          "Demo Framework A")
  rdflib::rdf_add(rdf, fw_a, cybed_t("jurisdiction"),   "US")
  rdflib::rdf_add(rdf, fw_a, cybed_t("sector"),         "civilian")
  rdflib::rdf_add(rdf, fw_a, cybed_t("specificity"),    "cybersecurity-specific")

  # Framework B: non-workforce-shaped (citizen / pedagogical flavor).
  rdflib::rdf_add(rdf, fw_b, rdftype,                   framework_class)
  rdflib::rdf_add(rdf, fw_b, schema_t("name"),          "Demo Framework B")
  rdflib::rdf_add(rdf, fw_b, cybed_t("jurisdiction"),   "EU")
  rdflib::rdf_add(rdf, fw_b, cybed_t("sector"),         "general")
  rdflib::rdf_add(rdf, fw_b, cybed_t("specificity"),    "general-IT")

  # Organizing units. Framework A's units assert both cybed:Role and
  # cybed:OrganizingUnit (workforce-shaped); Framework B's unit asserts
  # cybed:OrganizingUnit only (non-workforce-shaped). librdf does not
  # perform subClassOf inference, so both types must be asserted
  # explicitly to be returned by their respective queries.
  unit_a1 <- cybed_t("role/demo-a1")
  unit_a2 <- cybed_t("role/demo-a2")
  unit_b1 <- cybed_t("role/demo-b1")

  for (u in c(unit_a1, unit_a2)) {
    rdflib::rdf_add(rdf, u, rdftype, role_class)
    rdflib::rdf_add(rdf, u, rdftype, organizing_unit_class)
  }
  rdflib::rdf_add(rdf, unit_b1, rdftype, organizing_unit_class)

  rdflib::rdf_add(rdf, unit_a1, schema_t("name"), "Security Architect")
  rdflib::rdf_add(rdf, unit_a2, schema_t("name"), "Incident Responder")
  rdflib::rdf_add(rdf, unit_b1, schema_t("name"), "IT Generalist")
  rdflib::rdf_add(rdf, unit_a1, cybed_t("partOf"), fw_a)
  rdflib::rdf_add(rdf, unit_a2, cybed_t("partOf"), fw_a)
  rdflib::rdf_add(rdf, unit_b1, cybed_t("partOf"), fw_b)

  # Atomic elements.
  el_a1 <- cybed_t("element/demo-el-a1")
  el_a2 <- cybed_t("element/demo-el-a2")
  el_a3 <- cybed_t("element/demo-el-a3")
  el_b1 <- cybed_t("element/demo-el-b1")
  el_b2 <- cybed_t("element/demo-el-b2")
  for (e in c(el_a1, el_a2, el_a3, el_b1, el_b2)) {
    rdflib::rdf_add(rdf, e, rdftype, element_class)
  }
  rdflib::rdf_add(rdf, el_a1, cybed_t("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_a2, cybed_t("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_a3, cybed_t("partOf"), fw_a)
  rdflib::rdf_add(rdf, el_b1, cybed_t("partOf"), fw_b)
  rdflib::rdf_add(rdf, el_b2, cybed_t("partOf"), fw_b)

  rdflib::rdf_add(rdf, unit_a1, cybed_t("hasElement"), el_a1)
  rdflib::rdf_add(rdf, unit_a1, cybed_t("hasElement"), el_a2)
  rdflib::rdf_add(rdf, unit_a2, cybed_t("hasElement"), el_a3)
  rdflib::rdf_add(rdf, unit_b1, cybed_t("hasElement"), el_b1)
  rdflib::rdf_add(rdf, unit_b1, cybed_t("hasElement"), el_b2)

  # One Subpoint child of el_a1: framework-as-specified enumeration,
  # reachable via the cluster's cybed:hasElement (the role-level "all
  # elements" traversal includes Subpoints).
  sp_a1 <- cybed_t("element/demo-el-a1.sub.1")
  rdflib::rdf_add(rdf, sp_a1, rdftype,                     element_class)
  rdflib::rdf_add(rdf, sp_a1, rdftype,                     subpoint_class)
  rdflib::rdf_add(rdf, sp_a1, cybed_t("partOf"),           fw_a)
  rdflib::rdf_add(rdf, sp_a1, cybed_t("elaborates"),       el_a1)
  rdflib::rdf_add(rdf, unit_a1, cybed_t("hasElement"),     sp_a1)

  # One Example child of el_b1: pedagogical scaffolding, reachable only
  # via the parent element's cybed:hasExample. Deliberately NOT added to
  # unit_b1's cybed:hasElement collection so role-level traversals do
  # not pick it up.
  ex_b1 <- cybed_t("element/demo-el-b1.example.1")
  rdflib::rdf_add(rdf, ex_b1, rdftype,                     element_class)
  rdflib::rdf_add(rdf, ex_b1, rdftype,                     example_class)
  rdflib::rdf_add(rdf, ex_b1, cybed_t("partOf"),           fw_b)
  rdflib::rdf_add(rdf, el_b1, cybed_t("hasExample"),       ex_b1)

  rdf
}
