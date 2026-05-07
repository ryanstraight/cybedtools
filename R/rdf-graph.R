# rdf-graph.R
#
# RDF graph loading helpers. Package-exported versions of the functions
# that also live in scripts/030-load-rdf-graph.R as pipeline conveniences.

#' Load the pre-assembled combined multi-framework JSON-LD into an rdflib graph
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Wraps [rdflib::rdf_parse()] with a sensible default path under
#' `data/processed/jsonld/_combined.jsonld`. Errors with a classed condition
#' (`cybedtools_file_not_found`) when the file is absent so callers can
#' branch on it.
#'
#' @param file_path Character path to `_combined.jsonld`. Defaults to the
#'   standard location under `data/processed/jsonld/`.
#' @return An rdf object from the rdflib package.
#' @family RDF graph loading
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_rdf_graph()
#' }
load_combined_rdf_graph <- function(file_path = NULL) {
  if (is.null(file_path)) {
    file_path <- here::here("data", "processed", "jsonld", "_combined.jsonld")
  }
  if (!file.exists(file_path)) {
    rlang::abort(
      c(
        "Combined JSON-LD not found.",
        "x" = paste0("Expected at: ", file_path, "."),
        "i" = "Run `scripts/020-assemble-jsonld.R` first to assemble the graph."
      ),
      class = "cybedtools_file_not_found"
    )
  }
  rdflib::rdf_parse(file_path, format = "jsonld")
}

#' Load a single framework's JSON-LD into a new rdflib graph
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Loads exactly one framework, used when per-framework diagnostics or
#' isolated SPARQL queries are needed.
#'
#' @param framework_slug Character, one of `"nice"`, `"sfia"`, `"dcwf"`,
#'   `"ecsf"`, `"cyberorg-k12"`, `"csta"`, `"csec2017"`, or `"digcomp"`.
#' @param jsonld_dir Character path to the directory containing per-framework
#'   JSON-LD files. Defaults to `data/processed/jsonld/`.
#' @return An rdf object.
#' @family RDF graph loading
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_single_framework_graph("ecsf")
#' }
load_single_framework_graph <- function(framework_slug, jsonld_dir = NULL) {
  if (is.null(jsonld_dir)) {
    jsonld_dir <- here::here("data", "processed", "jsonld")
  }
  file_path <- file.path(jsonld_dir, paste0(framework_slug, ".jsonld"))
  if (!file.exists(file_path)) {
    rlang::abort(
      c(
        "JSON-LD not found for framework.",
        "x" = paste0("Slug: '", framework_slug, "'."),
        "x" = paste0("Expected at: ", file_path, "."),
        "i" = paste0("Confirm the slug is correct and that ",
                     "`scripts/020-assemble-jsonld.R` has run.")
      ),
      class = "cybedtools_framework_not_found",
      framework_slug = framework_slug
    )
  }
  rdflib::rdf_parse(file_path, format = "jsonld")
}

#' Load the pre-combined N-Triples file into an rdflib graph
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Faster than parsing JSON-LD when the combined graph has been exported via
#' `scripts/025-export-ntriples.R`. Use this for iterative SPARQL work and as
#' the data source when publishing to a Fuseki or Blazegraph endpoint.
#'
#' @param file_path Character path to `_combined.nt`. Defaults to the standard
#'   location under `data/processed/ntriples/`.
#' @return An rdf object.
#' @family RDF graph loading
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' }
load_combined_ntriples_graph <- function(file_path = NULL) {
  if (is.null(file_path)) {
    file_path <- here::here("data", "processed", "ntriples", "_combined.nt")
  }
  if (!file.exists(file_path)) {
    rlang::abort(
      c(
        "Combined N-Triples not found.",
        "x" = paste0("Expected at: ", file_path, "."),
        "i" = "Run `scripts/025-export-ntriples.R` first to export N-Triples."
      ),
      class = "cybedtools_file_not_found"
    )
  }
  rdflib::rdf_parse(file_path, format = "ntriples")
}

#' Load every framework's JSON-LD into a unified rdflib graph
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Iterates the standard framework set and parses each into a shared
#' rdf object. Functionally equivalent to [load_combined_rdf_graph()] but
#' useful when per-framework diagnostics are needed. Marked experimental
#' because the default slug list will track NICE/SFIA/DCWF/ECSF/CSEC/etc.
#' as they revise.
#'
#' @param framework_slugs Character vector of framework slugs.
#' @param jsonld_dir Character path.
#' @return An rdf object.
#' @family RDF graph loading
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_unified_rdf_graph()
#' }
load_unified_rdf_graph <- function(framework_slugs = c("nice", "sfia", "dcwf",
                                                        "ecsf", "cyberorg-k12",
                                                        "csta", "csec2017",
                                                        "digcomp"),
                                   jsonld_dir = NULL) {
  if (is.null(jsonld_dir)) {
    jsonld_dir <- here::here("data", "processed", "jsonld")
  }
  rdf <- rdflib::rdf()
  for (slug in framework_slugs) {
    file_path <- file.path(jsonld_dir, paste0(slug, ".jsonld"))
    if (!file.exists(file_path)) {
      rlang::warn(
        c(
          paste0("Skipping missing JSON-LD for '", slug, "'."),
          "i" = paste0("Expected at: ", file_path, ".")
        ),
        class = "cybedtools_missing_framework_warning"
      )
      next
    }
    rdflib::rdf_parse(file_path, rdf = rdf, format = "jsonld")
  }
  rdf
}
