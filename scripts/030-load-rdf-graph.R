# 030-load-rdf-graph.R
#
# Load the assembled JSON-LD documents into a unified RDF graph via rdflib.
# Provides load_unified_rdf_graph() and load_single_framework_graph() for
# use by scripts/040-run-sparql.R and ad-hoc analysis.

suppressPackageStartupMessages({
  library(here)
  library(rdflib)
  library(dplyr)
  library(purrr)
  library(glue)
})

graph_config <- list(
  jsonld_dir = here("data", "processed", "jsonld"),
  frameworks = c("nice", "sfia", "dcwf", "ecsf",
                 "cyberorg-k12", "csta", "csec2017", "digcomp")
)

#' Load a single framework's JSON-LD file into a new rdflib graph
#'
#' @param framework_slug Character; one of graph_config$frameworks.
#' @return An rdf object.
load_single_framework_graph <- function(framework_slug) {
  file_path <- file.path(graph_config$jsonld_dir,
                         paste0(framework_slug, ".jsonld"))
  if (!file.exists(file_path)) {
    stop("JSON-LD missing: ", file_path)
  }
  rdf <- rdf_parse(file_path, format = "jsonld")
  rdf
}

#' Load all five assembled frameworks into one unified rdf graph
#'
#' @return An rdf object with all framework nodes, roles, and elements.
load_unified_rdf_graph <- function() {
  rdf <- rdf()
  for (framework_slug in graph_config$frameworks) {
    file_path <- file.path(graph_config$jsonld_dir,
                           paste0(framework_slug, ".jsonld"))
    if (!file.exists(file_path)) {
      warning("Skipping missing JSON-LD: ", file_path)
      next
    }
    rdf_parse(file_path, rdf = rdf, format = "jsonld")
  }
  rdf
}

#' Load the pre-combined multi-framework JSON-LD (faster than re-parsing each)
load_combined_rdf_graph <- function() {
  combined_path <- file.path(graph_config$jsonld_dir, "_combined.jsonld")
  if (!file.exists(combined_path)) {
    stop("Combined JSON-LD not assembled yet; run scripts/020-assemble-jsonld.R first.")
  }
  rdf_parse(combined_path, format = "jsonld")
}
