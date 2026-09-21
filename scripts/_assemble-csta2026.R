# JSON-LD adapter for the 2026 CSTA PK-12 Computer Science Standards.
#
# Sourced by scripts/020-assemble-jsonld.R, which reads the staged tables and
# calls build_csta2026_parts(). Kept in its own file so the test suite can
# drive the adapter with a small synthetic fixture instead of the staged data.
# Requires the cybedtools JSON-LD constructors (build_*_node,
# expand_with_subpoints, extend_role_element_ids) to be loaded.
#
# scripts/ is .Rbuildignore'd, so nothing here ships in the package.
#
# Mapping onto the cybed: layer.
#
#   Standard (331)       cybed:RoleElement, subtype csta2026:Standard. The
#                        element id is CSTA's code verbatim (MS-ALG-PS-01,
#                        S1-CYB-ND-01) and the element text is the standard
#                        as published.
#   StandardGroup        cybed:OrganizingUnit only, never cybed:Role. The
#                        foundational tier groups by level x concept (EK, E1
#                        to E5, MS, HS x 5 concepts). The specialty tier
#                        groups by tier level x specialty area (S1, S2 x the
#                        areas observed at that level). Units are built from
#                        the observed pairs, so X+CS, which CSTA publishes at
#                        Specialty I only, gets no empty S2 unit. The unit id
#                        is CSTA's own code prefix (MS-ALG, S1-CYB). CSTA
#                        names the level, concept and specialty area but not
#                        the group itself, so the subtype is the descriptive
#                        csta2026:StandardGroup, as for csta-2017 and
#                        Cyber.org K-12. No subconcept-level units: the
#                        subconcept is recorded on each standard instead.
#   Implementation       cybed:Example, one per published example, linked
#   example              from its standard by cybed:hasExample and never by
#                        cybed:hasElement, the treatment csta-2017 gives its
#                        clarification column.
#
# Per-standard literals. No existing cybed: predicate carries a curricular
# tier, a specialty area code, a boundary statement or a publisher flag, and
# no other framework in the package mints framework-level predicates yet, so
# these are csta2026: terms:
#
#   csta2026:tier               "foundational" or "specialty"
#   csta2026:specialtyArea      specialty area code (AIN, CYB, DSC, GMD, PHY,
#                               SWD, XCS), specialty standards only
#   csta2026:subconcept         subconcept, or specialty subarea, as published
#   csta2026:boundaryStatement  one literal per published boundary paragraph.
#                               Boundary statements set the limits of what a
#                               standard asks for. They are part of the
#                               standard, not teaching examples, so they are
#                               not cybed:Example nodes.
#   csta2026:aiStandard         boolean, CSTA's "AI standard" flag
#   csta2026:exampleType        on each Example: Unplugged, Computer-based or
#                               Teacher choice, as published
#
# cybed:sourceSection carries level.concept.subconcept, e.g.
# "MS.Algorithms & Design.Algorithmic Problem Solving".
#
# Not modelled yet: practices, dispositions, progressions, specialty to
# foundation progressions and interdisciplinary connections.

csta2026_framework_id <- "csta-2026"
csta2026_prefix       <- "csta2026"

csta2026_level_labels <- c(
  EK = "PK/Kindergarten", E1 = "Grade 1", E2 = "Grade 2", E3 = "Grade 3",
  E4 = "Grade 4", E5 = "Grade 5", MS = "Middle School", HS = "High School",
  S1 = "Specialty I", S2 = "Specialty II"
)

#' Build the csta-2026 framework, unit and element nodes.
#'
#' @param standards Tibble, one row per standard: code, level, tier, concept,
#'   subconcept, specialty_area_code, title, ai_standard, source_section.
#' @param boundaries Tibble: code, ordinal, text.
#' @param examples Tibble: code, ordinal, example_type, text.
#' @param units Tibble: unit_id, level, tier, concept, concept_code,
#'   specialty_area_code.
#' @param prov List, the parsed provenance manifest.
#' @param unit_iri_prefix Optional unit IRI discriminator, passed through.
#' @return List with framework, roles, elements and prefix, the shape the
#'   other assemblers return.
build_csta2026_parts <- function(standards, boundaries, examples, units, prov,
                                 unit_iri_prefix = NULL) {
  framework_node <- build_framework_node(
    framework_id     = csta2026_framework_id,
    framework_name   = prov$framework_version,
    framework_prefix = csta2026_prefix,
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "US",
    sector           = "K-12-education",
    specificity      = "general-computing",
    license          = prov$licensing$source_license,
    date_published   = prov$version_date,
    attribution      = paste0(prov$suggested_citation, " DOI: https://doi.org/",
                              prov$doi)
  )

  boundary_lookup <- split(boundaries$text[order(boundaries$code, boundaries$ordinal)],
                           boundaries$code[order(boundaries$code, boundaries$ordinal)])

  parent_element_nodes <- standards |>
    purrr::pmap(function(code, tier, subconcept, specialty_area_code, title,
                         ai_standard, source_section, ...) {
      node <- build_role_element_node(
        element_id             = code,
        framework_prefix       = csta2026_prefix,
        framework_element_type = "Standard",
        element_text           = title,
        source_section         = source_section,
        framework_id           = csta2026_framework_id
      )
      extra <- list(`csta2026:tier` = tier)
      if (!is.na(specialty_area_code) && nzchar(specialty_area_code)) {
        extra[["csta2026:specialtyArea"]] <- specialty_area_code
      }
      extra[["csta2026:subconcept"]] <- subconcept
      bounds <- boundary_lookup[[code]]
      if (length(bounds) > 0) {
        extra[["csta2026:boundaryStatement"]] <- unname(bounds)
      }
      extra[["csta2026:aiStandard"]] <- isTRUE(as.logical(ai_standard))
      c(node, extra)
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = csta2026_prefix,
    framework_id     = csta2026_framework_id,
    framework_slug   = csta2026_framework_id
  )

  # Implementation examples are numbered from 1 per standard. The parser only
  # mints Examples from an inline "Clarification statement:" segment, which
  # CSTA's 2026 text does not use; if it ever did, its IRIs would collide
  # with these, so stop rather than merge two sources under one number.
  if (any(expanded$subnode_index$node_type == "Example")) {
    stop("csta-2026: the sub-point parser produced Example nodes; ",
         "implementation-example IRIs would collide.")
  }

  example_nodes <- examples |>
    purrr::pmap(function(code, ordinal, example_type, text, ...) {
      ex <- build_example_node(
        parent_element_id = code,
        ordinal           = as.integer(ordinal),
        text              = text,
        framework_prefix  = csta2026_prefix,
        framework_id      = csta2026_framework_id
      )
      if (!is.na(example_type) && nzchar(example_type)) {
        ex[["csta2026:exampleType"]] <- example_type
      }
      ex
    })

  example_iris <- split(
    vapply(example_nodes, \(ex) as.character(ex[["@id"]]), character(1)),
    paste0(csta2026_prefix, ":", examples$code)
  )

  expanded$nodes <- lapply(expanded$nodes, function(node) {
    iri <- as.character(node[["@id"]])
    if (!is.null(example_iris[[iri]])) {
      node[["cybed:hasExample"]] <- purrr::map(unname(example_iris[[iri]]),
                                               \(eid) list(`@id` = eid))
    }
    node
  })

  unit_nodes <- units |>
    purrr::pmap(function(unit_id, level, tier, concept, concept_code,
                         specialty_area_code, ...) {
      child_standards <- standards$code[standards$level == level &
                                          startsWith(standards$code,
                                                     paste0(level, "-", concept_code, "-"))]
      child_standards <- extend_role_element_ids(child_standards, expanded$subnode_index)

      unit_meta <- list(`csta2026:tier` = tier)
      if (!is.na(specialty_area_code) && nzchar(specialty_area_code)) {
        unit_meta[["csta2026:specialtyArea"]] <- specialty_area_code
      }

      build_organizing_unit_node(
        unit_id           = unit_id,
        unit_name         = paste(level, concept, sep = " / "),
        framework_prefix  = csta2026_prefix,
        framework_subtype = "StandardGroup",
        is_role           = FALSE,
        description       = paste0(unname(csta2026_level_labels[level]), ", ", concept),
        element_ids       = child_standards,
        framework_id      = csta2026_framework_id,
        metadata          = unit_meta,
        unit_iri_prefix   = unit_iri_prefix
      )
    })

  list(framework = framework_node, roles = unit_nodes,
       elements = c(expanded$nodes, example_nodes), prefix = csta2026_prefix)
}
