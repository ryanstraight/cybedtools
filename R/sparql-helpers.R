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
#
# JOIN HAZARD, confirmed 2026-08-14 stress test: every domain helper below
# shares the `framework` and/or `framework_name` columns. An unqualified
# dplyr::inner_join() between any two of them (no `by =` argument) silently
# joins on those shared columns instead of erroring -- dplyr does emit a
# message + "many-to-many relationship" warning, not an error, so a script
# that doesn't inspect stderr gets a plausible-looking but massively
# inflated garbage result (confirmed: joining organizing_unit_framework_
# bindings() [428 rows] to element_framework_bindings() [7,435 rows]
# without an explicit `by =` produces 521,270 rows, ~36x the correct
# 14,583-row parent-child join). Always pass an explicit `by =` when
# joining two of these tibbles together.

#' Derive a framework's stable slug from its framework IRI
#'
#' Framework nodes are minted at `cybed:framework/{framework_id}`
#' ([build_framework_node()]), and `framework_id` is exactly the slug
#' documented on [framework_summary]`$framework_slug` (e.g. `"nice-v2"`).
#' This helper takes the text after the final `/` of the expanded IRI, which
#' recovers that slug without a round trip through the framework's
#' `schema:name` literal.
#'
#' @param framework_uri Character vector of framework IRIs (the `framework`
#'   column of `framework_metadata()` and the `*_bindings()` helpers).
#' @return Character vector of slugs, same length as `framework_uri`. `NA`
#'   input yields `NA` output.
#' @noRd
framework_slug_of <- function(framework_uri) {
  sub(".*/", "", framework_uri)
}

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
#'   `sector`, `specificity`, `framework_slug`. One row per framework typed
#'   as `cybed:Framework`. `framework_slug` is added (v0.4.0) as a stable
#'   join key across frameworks; every existing column is unchanged and
#'   row order is unchanged.
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
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
    dplyr::transmute(framework = .data$s) |>
    dplyr::left_join(
      dplyr::rename(names_, name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::left_join(
      dplyr::rename(juris, jurisdiction = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::left_join(
      dplyr::rename(sectors, sector = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::left_join(
      dplyr::rename(specs, specificity = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: role-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (role, framework) pair where the role is typed
#' `cybed:Role` and its `partOf` target is typed `cybed:Framework`. As of
#' v0.2.0, `cybed:Role` is reserved for workforce frameworks (NICE work
#' roles, DCWF work roles, ENISA ECSF profiles, CyQUAL work roles, CCSSF
#' work roles, OTCCF job roles); SFIA skills, Cyber.org
#' K-12 grade-band x sub-concept cells, CSTA level x concept cells, CSEC2017
#' Knowledge Areas, and DigComp competence areas are not roles and are
#' not returned by this helper. Use [organizing_unit_framework_bindings()]
#' for the cross-framework "top-level enumerated unit" cut that includes
#' every framework in the corpus.
#'
#' Roles without a `cybed:partOf` triple, or whose partOf target is not
#' typed `cybed:Framework`, are excluded.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `role`, `role_name`, `framework`,
#'   `framework_name`, `framework_slug` (added v0.4.0, a stable join key).
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
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
  # One schema:name scan serves both the role and the framework labels.
  role_names <- sparql_pairs(rdf, "schema:name")
  partof     <- sparql_pairs(rdf, "cybed:partOf")
  fw_names   <- role_names

  roles |>
    dplyr::transmute(role = .data$s) |>
    dplyr::inner_join(
      dplyr::rename(partof, framework = "o"),
      by = c("role" = "s")
    ) |>
    dplyr::semi_join(
      dplyr::rename(fws, framework = "s"),
      by = "framework"
    ) |>
    dplyr::left_join(
      dplyr::rename(role_names, role_name = "o"),
      by = c("role" = "s")
    ) |>
    dplyr::left_join(
      dplyr::rename(fw_names, framework_name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: organizing-unit-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (organizing unit, framework) pair across every framework in
#' the corpus. Queries on the cross-framework abstract type
#' `cybed:OrganizingUnit`, which every framework's top-level enumerated
#' unit asserts (work roles, work profiles, skills, grade-band x sub-concept cells,
#' level x concept cells, Knowledge Areas, competence areas). Use this
#' helper for cross-framework parent-level analysis. Use
#' [role_framework_bindings()] when the question is workforce-specific
#' (NICE work roles, DCWF work roles, ENISA ECSF profiles only).
#'
#' Units without a `cybed:partOf` triple, or whose partOf target is not
#' typed `cybed:Framework`, are excluded.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `unit`, `unit_name`, `framework`,
#'   `framework_name`, `framework_slug` (added v0.4.0, a stable join key).
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
#'   Confirmed 2026-08-14: a helper written as `function(framework, ...)
#'   filter(units, str_detect(framework_name, framework))` silently
#'   returned zero rows every time.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' organizing_unit_framework_bindings(rdf)
#' }
organizing_unit_framework_bindings <- function(rdf) {
  units      <- sparql_subjects(rdf, "a", "cybed:OrganizingUnit")
  fws        <- sparql_subjects(rdf, "a", "cybed:Framework")
  # One schema:name scan serves both the unit and the framework labels.
  unit_names <- sparql_pairs(rdf, "schema:name")
  partof     <- sparql_pairs(rdf, "cybed:partOf")
  fw_names   <- unit_names

  units |>
    dplyr::transmute(unit = .data$s) |>
    dplyr::inner_join(
      dplyr::rename(partof, framework = "o"),
      by = c("unit" = "s")
    ) |>
    dplyr::semi_join(
      dplyr::rename(fws, framework = "s"),
      by = "framework"
    ) |>
    dplyr::left_join(
      dplyr::rename(unit_names, unit_name = "o"),
      by = c("unit" = "s")
    ) |>
    dplyr::left_join(
      dplyr::rename(fw_names, framework_name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: element-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (element, framework) pair where the element is typed
#' `cybed:RoleElement` (which includes parent elements, `cybed:Subpoint`
#' children, and `cybed:Example` children) and its `partOf` target is
#' typed `cybed:Framework`. Elements without a `cybed:partOf` triple, or
#' whose partOf target is not a Framework, are excluded.
#'
#' This helper is the broad cut. Use [example_framework_bindings()] when
#' you need only the `cybed:Example` subset (e.g., for the "with-examples"
#' counting column in `framework_summary`).
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `element`, `framework`, `framework_name`,
#'   `framework_slug` (added v0.4.0, a stable join key).
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
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
    dplyr::transmute(element = .data$s) |>
    dplyr::inner_join(
      dplyr::rename(partof, framework = "o"),
      by = c("element" = "s")
    ) |>
    dplyr::semi_join(
      dplyr::rename(fws, framework = "s"),
      by = "framework"
    ) |>
    dplyr::left_join(
      dplyr::rename(fw_names, framework_name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: example-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (example, framework) pair where the example is typed
#' `cybed:Example` (the pedagogical-scaffolding subtype reserved for
#' Cyber.org K-12 and CSTA "Clarification statement:" content) and its
#' `partOf` target is typed `cybed:Framework`. Examples without a valid
#' framework partOf are excluded.
#'
#' Examples are a strict subset of the elements returned by
#' [element_framework_bindings()]. Use this helper when reporting on the
#' Subpoint-vs-Example split for a framework, or when constructing a
#' "strict" native element count by subtracting both Example counts (this
#' helper) and Subpoint counts ([subpoint_framework_bindings()]) from the
#' total element count.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `example`, `framework`, `framework_name`,
#'   `framework_slug` (added v0.4.0, a stable join key).
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' example_framework_bindings(rdf)
#' }
example_framework_bindings <- function(rdf) {
  examples <- sparql_subjects(rdf, "a", "cybed:Example")
  fws      <- sparql_subjects(rdf, "a", "cybed:Framework")
  partof   <- sparql_pairs(rdf, "cybed:partOf")
  fw_names <- sparql_pairs(rdf, "schema:name")

  examples |>
    dplyr::transmute(example = .data$s) |>
    dplyr::inner_join(
      dplyr::rename(partof, framework = "o"),
      by = c("example" = "s")
    ) |>
    dplyr::semi_join(
      dplyr::rename(fws, framework = "s"),
      by = "framework"
    ) |>
    dplyr::left_join(
      dplyr::rename(fw_names, framework_name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: subpoint-to-framework bindings with framework name attached
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (subpoint, framework) pair where the subpoint is typed
#' `cybed:Subpoint` (the generic enumeration-list-splitting subtype --
#' "such as X, Y, and Z" / "including A and B" -- parsed out of a single
#' native unit's text at JSON-LD assembly time, applied uniformly across
#' the corpus) and its `partOf` target is typed
#' `cybed:Framework`. Subpoints without a valid framework partOf are
#' excluded.
#'
#' Subpoints are a strict subset of the elements returned by
#' [element_framework_bindings()], and a distinct subtype from
#' [example_framework_bindings()]'s `cybed:Example` (the Cyber.org K-12 /
#' CSTA Clarification-statement pedagogical-scaffolding subtype
#' specifically). Use this helper together with
#' [example_framework_bindings()] when constructing a "strict" native
#' element count by subtracting both Subpoint and Example counts from the
#' total element count -- see `framework_summary`'s `element_count_strict`
#' column, which does exactly this.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `subpoint`, `framework`, `framework_name`,
#'   `framework_slug` (added v0.4.0, a stable join key).
#' @note The `framework` column holds the framework's full URI. Avoid
#'   naming a local variable or function parameter `framework` in code
#'   that filters or mutates this tibble -- dplyr's data masking silently
#'   resolves a bare `framework` reference inside `filter()`/`mutate()`
#'   to this COLUMN rather than your same-named variable, with no error
#'   and no warning, only a wrong (often zero-row) result surfacing later.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' subpoint_framework_bindings(rdf)
#' }
subpoint_framework_bindings <- function(rdf) {
  subpoints <- sparql_subjects(rdf, "a", "cybed:Subpoint")
  fws       <- sparql_subjects(rdf, "a", "cybed:Framework")
  partof    <- sparql_pairs(rdf, "cybed:partOf")
  fw_names  <- sparql_pairs(rdf, "schema:name")

  subpoints |>
    dplyr::transmute(subpoint = .data$s) |>
    dplyr::inner_join(
      dplyr::rename(partof, framework = "o"),
      by = c("subpoint" = "s")
    ) |>
    dplyr::semi_join(
      dplyr::rename(fws, framework = "s"),
      by = "framework"
    ) |>
    dplyr::left_join(
      dplyr::rename(fw_names, framework_name = "o"),
      by = c("framework" = "s")
    ) |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework))
}

#' Domain helper: statement text keyed by element
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per element that carries a `cybed:elementText` literal, from
#' the single basic graph pattern `sparql_pairs(rdf, "cybed:elementText")`
#' renamed from `s`/`o`. This is the statement text itself -- the task,
#' knowledge, skill, competency, or standard wording as the framework
#' publishes it.
#'
#' @details
#' Nothing is filtered, normalised, or de-duplicated beyond what the graph
#' holds. Elements without a `cybed:elementText` triple simply do not
#' appear, and an element carrying more than one `cybed:elementText`
#' literal yields one row per literal, so `element` is not guaranteed
#' unique. A graph with no `cybed:elementText` triples at all returns a
#' zero-row tibble with the same two columns.
#'
#' Sub-points and examples are elements too, and they carry their own
#' text: a `cybed:Subpoint` holds the enumerated fragment lifted out of
#' its parent's wording, and a `cybed:Example` holds the pedagogical
#' "Clarification statement:" content. A caller who wants parent
#' statements only should anti-join both child sets away, matching each
#' helper's own identifier column against `element`:
#' [subpoint_framework_bindings()] returns `subpoint`, and
#' [example_framework_bindings()] returns `example`.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `element` (character, the element's full
#'   URI) and `text` (character, the statement literal).
#' @family SPARQL helpers
#' @seealso [element_framework_bindings()] to attach framework
#'   attribution, [subpoint_framework_bindings()] and
#'   [example_framework_bindings()] to separate child elements from
#'   parent statements.
#' @export
#' @examples
#' rdf <- make_demo_graph()
#' # The demo graph carries no cybed:elementText, so this is a zero-row
#' # tibble with the columns `element` and `text`.
#' element_text(rdf)
#'
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' texts <- element_text(rdf)
#'
#' # Parent statements only: drop sub-points and examples.
#' texts |>
#'   dplyr::anti_join(
#'     dplyr::rename(subpoint_framework_bindings(rdf), element = "subpoint"),
#'     by = "element"
#'   ) |>
#'   dplyr::anti_join(
#'     dplyr::rename(example_framework_bindings(rdf), element = "example"),
#'     by = "element"
#'   )
#' }
element_text <- function(rdf) {
  texts <- sparql_pairs(rdf, "cybed:elementText")
  dplyr::transmute(texts, element = .data$s, text = .data$o)
}

#' Domain helper: organizing-unit-to-element bindings
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' One row per (parent, element) pair derived from `cybed:hasElement`
#' triples. Despite the "role" naming, the `role` column is NOT restricted
#' to `cybed:Role` subjects -- `cybed:hasElement` is the universal parent-
#' child link used across every framework in the corpus, so this returns
#' element bindings for every `cybed:OrganizingUnit` (SFIA skills,
#' Cyber.org K-12 and CSTA standards, etc.), not just NICE/DCWF/ECSF work
#' roles. Confirmed by a 2026-08-14 stress test: most distinct values in
#' the `role` column are not actual `cybed:Role` subjects. Low practical
#' risk when
#' immediately joined against [role_framework_bindings()] or
#' [organizing_unit_framework_bindings()] (the mismatches drop out), but a
#' standalone aggregate over this tibble's `role` column (e.g. "average
#' elements per role") will silently include non-role parents. Filter to
#' `cybed:Role` first via [role_framework_bindings()] if that distinction
#' matters for your analysis.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `role`, `element`, `framework_slug`.
#'   `framework_slug` (added v0.4.0) is the slug of the `role` (organizing
#'   unit) subject's own framework, taken from
#'   [organizing_unit_framework_bindings()]; a `role` with no valid
#'   `cybed:partOf` to a `cybed:Framework` carries `NA` here rather than
#'   dropping the row, so this helper's row count is unchanged from before
#'   v0.4.0.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' unit_element_bindings(rdf)
#' }
unit_element_bindings <- function(rdf) {
  has_element <- sparql_pairs(rdf, "cybed:hasElement")
  bindings <- dplyr::transmute(has_element, role = .data$s, element = .data$o)

  units <- organizing_unit_framework_bindings(rdf) |>
    dplyr::transmute(role = .data$unit, framework_slug = .data$framework_slug)

  bindings |>
    dplyr::left_join(units, by = "role")
}

#' Deprecated alias for [unit_element_bindings()]
#'
#' @description
#' `r lifecycle::badge("deprecated")`
#'
#' `role_element_bindings()` is deprecated as of cybedtools 0.4.0 in favor of
#' [unit_element_bindings()], which returns the identical result (all
#' organizing units, not just `cybed:Role` subjects) under a name that
#' doesn't overstate the role restriction. This alias will be removed in a
#' future minor version; update call sites to `unit_element_bindings()`.
#'
#' @inheritParams unit_element_bindings
#' @return See [unit_element_bindings()].
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' role_element_bindings(rdf)
#' }
role_element_bindings <- function(rdf) {
  warning(
    paste(
      "`role_element_bindings()` was deprecated in cybedtools 0.4.0.",
      "Use `unit_element_bindings()` instead."
    ),
    call. = FALSE
  )
  unit_element_bindings(rdf)
}

#' Domain helper: unit-to-unit relation bindings
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' One row per `cybed:UnitRelation` node ([build_unit_relation_node()]),
#' giving the related pair of organizing units plus the relation's own
#' framework attribution. `relation` is `NA` for a plain (unlabeled)
#' relation; `framework_slug` is `NA` when the relation node carries no
#' `cybed:partOf`, or one whose target is not typed `cybed:Framework`.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `from_unit`, `relation`, `to_unit`,
#'   `framework_slug`.
#' @family SPARQL helpers
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' unit_relation_bindings(rdf)
#' }
unit_relation_bindings <- function(rdf) {
  relations <- sparql_subjects(rdf, "a", "cybed:UnitRelation") |>
    dplyr::transmute(relation_id = .data$s)
  from_unit <- sparql_pairs(rdf, "cybed:fromUnit")
  to_unit   <- sparql_pairs(rdf, "cybed:toUnit")
  labels    <- sparql_pairs(rdf, "cybed:relationLabel")
  partof    <- sparql_pairs(rdf, "cybed:partOf")
  fws       <- sparql_subjects(rdf, "a", "cybed:Framework")

  fw_of_relation <- partof |>
    dplyr::rename(relation_id = "s", framework = "o") |>
    dplyr::semi_join(dplyr::rename(fws, framework = "s"), by = "framework") |>
    dplyr::mutate(framework_slug = framework_slug_of(.data$framework)) |>
    dplyr::select("relation_id", "framework_slug")

  relations |>
    dplyr::left_join(
      dplyr::rename(from_unit, relation_id = "s", from_unit = "o"),
      by = "relation_id"
    ) |>
    dplyr::left_join(
      dplyr::rename(to_unit, relation_id = "s", to_unit = "o"),
      by = "relation_id"
    ) |>
    dplyr::left_join(
      dplyr::rename(labels, relation_id = "s", relation = "o"),
      by = "relation_id"
    ) |>
    dplyr::left_join(fw_of_relation, by = "relation_id") |>
    dplyr::select("from_unit", "relation", "to_unit", "framework_slug")
}
