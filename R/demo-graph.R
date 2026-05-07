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
#' the structural shape the package's helpers expect: 2 frameworks
#' (US/civilian/cybersecurity-specific and EU/general/general-IT), 3 roles
#' bound to those frameworks, and 5 elements distributed across them. The
#' graph is small enough to execute every helper in milliseconds and is
#' provided so first-time users can run `framework_metadata()`,
#' `role_framework_bindings()`, etc. without staging upstream framework
#' source data.
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
#' @return An `rdf` object containing roughly 30 triples.
#' @family RDF graph loading
#' @export
#' @examples
#' rdf <- make_demo_graph()
#' framework_metadata(rdf)
#' role_framework_bindings(rdf)
#' sparql_pairs(rdf, "cybed:jurisdiction")
make_demo_graph <- function() {
  cybed   <- "https://w3id.org/cybed/ontology#"
  schema  <- "http://schema.org/"
  rdftype <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  cybed_t <- function(local) paste0(cybed, local)
  schema_t <- function(local) paste0(schema, local)

  rdf <- rdflib::rdf()

  fw_a <- cybed_t("framework/demo-fw-a")
  fw_b <- cybed_t("framework/demo-fw-b")
  framework_class <- cybed_t("Framework")
  role_class      <- cybed_t("Role")
  element_class   <- cybed_t("RoleElement")

  # Framework A
  rdflib::rdf_add(rdf, fw_a, rdftype, framework_class)
  rdflib::rdf_add(rdf, fw_a, schema_t("name"),       "Demo Framework A")
  rdflib::rdf_add(rdf, fw_a, cybed_t("jurisdiction"), "US")
  rdflib::rdf_add(rdf, fw_a, cybed_t("sector"),       "civilian")
  rdflib::rdf_add(rdf, fw_a, cybed_t("specificity"),  "cybersecurity-specific")

  # Framework B
  rdflib::rdf_add(rdf, fw_b, rdftype, framework_class)
  rdflib::rdf_add(rdf, fw_b, schema_t("name"),       "Demo Framework B")
  rdflib::rdf_add(rdf, fw_b, cybed_t("jurisdiction"), "EU")
  rdflib::rdf_add(rdf, fw_b, cybed_t("sector"),       "general")
  rdflib::rdf_add(rdf, fw_b, cybed_t("specificity"),  "general-IT")

  # Roles
  role_a1 <- cybed_t("role/demo-a1")
  role_a2 <- cybed_t("role/demo-a2")
  role_b1 <- cybed_t("role/demo-b1")
  for (r in c(role_a1, role_a2, role_b1)) {
    rdflib::rdf_add(rdf, r, rdftype, role_class)
  }
  rdflib::rdf_add(rdf, role_a1, schema_t("name"),    "Security Architect")
  rdflib::rdf_add(rdf, role_a2, schema_t("name"),    "Incident Responder")
  rdflib::rdf_add(rdf, role_b1, schema_t("name"),    "IT Generalist")
  rdflib::rdf_add(rdf, role_a1, cybed_t("partOf"),    fw_a)
  rdflib::rdf_add(rdf, role_a2, cybed_t("partOf"),    fw_a)
  rdflib::rdf_add(rdf, role_b1, cybed_t("partOf"),    fw_b)

  # Elements
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

  rdflib::rdf_add(rdf, role_a1, cybed_t("hasElement"), el_a1)
  rdflib::rdf_add(rdf, role_a1, cybed_t("hasElement"), el_a2)
  rdflib::rdf_add(rdf, role_a2, cybed_t("hasElement"), el_a3)
  rdflib::rdf_add(rdf, role_b1, cybed_t("hasElement"), el_b1)
  rdflib::rdf_add(rdf, role_b1, cybed_t("hasElement"), el_b2)

  rdf
}
