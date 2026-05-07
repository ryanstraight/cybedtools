# SPARQL Helpers, Single-BGP Discipline
#
# librdf (the C library that rdflib wraps) exhibits poor performance and
# silent zero-row results on conjunctive triple patterns against multi-
# framework graphs at this scale. Single basic graph patterns (one triple
# match per query) execute fast and correctly. The package's design
# discipline is therefore:
#
#   - SPARQL queries are SINGLE basic graph patterns (one triple match).
#   - All joins, multi-property assembly, and aggregation happen in R via
#     dplyr. The graph holds the data. R holds the query plan.
#
# Functions in this file implement that discipline. Domain-level helpers
# (framework_metadata, role_framework_bindings, element_framework_bindings)
# call multiple single-BGP queries and stitch the results in R.

#' Default PREFIX declarations used by every helper query
#'
#' @return Character string with the standard prefixes plus a trailing newline.
#' @noRd
default_prefixes <- function() {
  paste0(
    "PREFIX cybed: <https://w3id.org/cybed/ontology#>\n",
    "PREFIX schema: <http://schema.org/>\n",
    "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n",
    "PREFIX skos: <http://www.w3.org/2004/02/skos/core#>\n"
  )
}

#' Run a single-BGP SPARQL select returning subject-object pairs
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Issues a `SELECT ?s ?o WHERE { ?s P ?o }` query where `P` is the supplied
#' predicate. The predicate position is constant. Both subject and object are
#' bound. This is a single triple match, the only pattern shape librdf
#' reliably plans on graphs of cybedtools' scale.
#'
#' @param rdf An rdf object from [rdflib::rdf_parse()] or
#'   [load_combined_ntriples_graph()].
#' @param predicate Character. A SPARQL predicate (e.g., `"cybed:partOf"`,
#'   `"schema:name"`, `"a"`). Use the prefixed form. `default_prefixes()`
#'   supplies cybed, schema, rdfs, and skos.
#' @return A tibble with columns `s` (character, subject URI) and `o`
#'   (character, object value, either URI or literal).
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' sparql_pairs(rdf, "cybed:jurisdiction")
#' }
sparql_pairs <- function(rdf, predicate) {
  query <- paste0(
    default_prefixes(),
    sprintf("SELECT ?s ?o WHERE { ?s %s ?o }", predicate)
  )
  result <- rdflib::rdf_query(rdf, query)
  if (nrow(result) == 0) {
    return(tibble::tibble(s = character(0), o = character(0)))
  }
  tibble::as_tibble(result)
}

#' Run a single-BGP SPARQL select with fixed predicate and object
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Issues a `SELECT ?s WHERE { ?s P O }` query where `P` and `O` are the
#' supplied predicate and object. Useful when the object is a known type
#' (e.g., `predicate = "a"`, `object = "cybed:Framework"`).
#'
#' @param rdf An rdf object.
#' @param predicate Character SPARQL predicate.
#' @param object Character SPARQL object (either prefixed-URI or literal).
#' @return A tibble with column `s` (character).
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' sparql_subjects(rdf, "a", "cybed:Framework")
#' }
sparql_subjects <- function(rdf, predicate, object) {
  query <- paste0(
    default_prefixes(),
    sprintf("SELECT ?s WHERE { ?s %s %s }", predicate, object)
  )
  result <- rdflib::rdf_query(rdf, query)
  if (nrow(result) == 0) {
    return(tibble::tibble(s = character(0)))
  }
  tibble::as_tibble(result)
}

#' Domain helper: tibble of framework metadata
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Calls one single-BGP query per metadata property and inner-joins on the
#' framework URI. The set of frameworks is anchored by the `rdf:type` triple
#' (`?s a cybed:Framework`), so frameworks missing any property still appear
#' in the output (with `NA` in the missing column) thanks to `left_join`.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `framework`, `name`, `jurisdiction`,
#'   `sector`, `specificity`. One row per framework typed as
#'   `cybed:Framework`.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' framework_metadata(rdf)
#' }
framework_metadata <- function(rdf) {
  fw      <- sparql_subjects(rdf, "a", "cybed:Framework")
  names_  <- sparql_pairs(rdf, "schema:name")
  juris   <- sparql_pairs(rdf, "cybed:jurisdiction")
  sectors <- sparql_pairs(rdf, "cybed:sector")
  specs   <- sparql_pairs(rdf, "cybed:specificity")

  fw |>
    dplyr::transmute(framework = s) |>
    dplyr::left_join(dplyr::rename(names_,  name         = o), by = c("framework" = "s")) |>
    dplyr::left_join(dplyr::rename(juris,   jurisdiction = o), by = c("framework" = "s")) |>
    dplyr::left_join(dplyr::rename(sectors, sector       = o), by = c("framework" = "s")) |>
    dplyr::left_join(dplyr::rename(specs,   specificity  = o), by = c("framework" = "s"))
}

#' Domain helper: role-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (role, framework) pair where the partOf target is itself
#' typed as `cybed:Framework`. Roles without a `cybed:partOf` triple, or
#' whose partOf target is not a Framework, are excluded.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `role`, `role_name`, `framework`,
#'   `framework_name`.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' role_framework_bindings(rdf)
#' }
role_framework_bindings <- function(rdf) {
  roles      <- sparql_subjects(rdf, "a", "cybed:Role")
  fws        <- sparql_subjects(rdf, "a", "cybed:Framework")
  role_names <- sparql_pairs(rdf, "schema:name")
  partof     <- sparql_pairs(rdf, "cybed:partOf")
  fw_names   <- sparql_pairs(rdf, "schema:name")

  roles |>
    dplyr::transmute(role = s) |>
    dplyr::inner_join(dplyr::rename(partof, framework = o), by = c("role" = "s")) |>
    dplyr::semi_join(dplyr::rename(fws, framework = s), by = "framework") |>
    dplyr::left_join(dplyr::rename(role_names, role_name = o),     by = c("role" = "s")) |>
    dplyr::left_join(dplyr::rename(fw_names,   framework_name = o), by = c("framework" = "s"))
}

#' Domain helper: element-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (element, framework) pair where the partOf target is itself
#' typed as `cybed:Framework`. Elements without a `cybed:partOf` triple, or
#' whose partOf target is not a Framework, are excluded.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `element`, `framework`, `framework_name`.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' element_framework_bindings(rdf)
#' }
element_framework_bindings <- function(rdf) {
  elements <- sparql_subjects(rdf, "a", "cybed:RoleElement")
  fws      <- sparql_subjects(rdf, "a", "cybed:Framework")
  partof   <- sparql_pairs(rdf, "cybed:partOf")
  fw_names <- sparql_pairs(rdf, "schema:name")

  elements |>
    dplyr::transmute(element = s) |>
    dplyr::inner_join(dplyr::rename(partof, framework = o), by = c("element" = "s")) |>
    dplyr::semi_join(dplyr::rename(fws, framework = s), by = "framework") |>
    dplyr::left_join(dplyr::rename(fw_names, framework_name = o), by = c("framework" = "s"))
}

#' Domain helper: role-to-element bindings
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (role, element) pair derived from `cybed:hasElement` triples.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `role`, `element`.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' role_element_bindings(rdf)
#' }
role_element_bindings <- function(rdf) {
  has_element <- sparql_pairs(rdf, "cybed:hasElement")
  dplyr::transmute(has_element, role = s, element = o)
}
