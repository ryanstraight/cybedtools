# JSON-LD adapter for the Saudi Cybersecurity Workforce Framework
# (SCyWF – 1.5: 2026), issued by the National Cybersecurity Authority (NCA).
#
# Sourced by scripts/020-assemble-jsonld.R, which reads the staged tables and
# calls build_scywf_parts(). Kept in its own file so the test suite can drive
# the adapter with a small synthetic fixture instead of the staged data.
# Requires the cybedtools JSON-LD constructors (build_*_node,
# build_related_unit_metadata) to be loaded.
#
# scripts/ is .Rbuildignore'd, so nothing here ships in the package.
#
# NCA's permission is conditional. Everything NCA published is carried
# verbatim: codes, titles, descriptions and statement text, copied by
# scripts/010-ingest-scywf.R and checked there against an independent
# extraction. Everything cybedtools derives is kept on predicates cybedtools
# mints for the purpose, so it can never be read as NCA content.
#
# Mapping onto the cybed: layer, following NICE and DCWF.
#
#   Task, Knowledge and   cybed:RoleElement, subtypes scywf:TaskStatement,
#   Skill statements      scywf:KnowledgeStatement and scywf:SkillStatement.
#                         The element id is the code as printed in Appendix
#                         B (T0036, K0001, S0001) and the element text is the
#                         statement as printed. Skills also carry NCA's
#                         "Technical?" column verbatim as scywf:technical
#                         ("Yes" or "No").
#   Job role              cybed:Role, subtype scywf:JobRole, keyed by the
#                         printed Job Role ID (CARD-CA-001). Name and
#                         description are the card's own. cybed:hasElement
#                         links the role to every code printed on its card.
#   Competency area       cybed:OrganizingUnit only, subtype
#                         scywf:CompetencyArea, keyed by its CA code (CA001),
#                         with Appendix C's name and description. NCA
#                         publishes no statement membership for a competency
#                         area, so it has no cybed:hasElement.
#   Specialty area,       cybed:OrganizingUnit only, subtypes
#   category              scywf:SpecialtyArea and scywf:Category. The ID is
#                         the segment NCA uses inside its job role IDs, and
#                         the name is the card's Category or Specialty Area
#                         field. Category ICSOT and specialty area ICSOT
#                         share one ID, so both kinds of unit carry an IRI
#                         discriminator (scywf:category-ICSOT,
#                         scywf:specialty-ICSOT) and keep the printed ID as
#                         schema:identifier.
#
# Unit IRIs and statement IRIs cannot collide: job role IDs, CA codes and
# statement codes have different shapes, and the group units carry a
# discriminator. docs/framework-invariants.yml therefore declares no
# unit_iri_prefix for scywf.
#
# Derived edges (cybedtools, not NCA):
#
#   scywf:inSpecialtyArea  job role -> its specialty area unit
#   scywf:inCategory       specialty area unit -> its category unit
#
# NCA prints each role's category and specialty area as text fields on the
# role card and encodes them in the role ID. The two predicates turn that
# into graph edges. They are cybedtools terms, minted under the cybed
# namespace, and state a hierarchy cybedtools built.
#
# Card literals (verbatim):
#
#   scywf:competencyAreasText  the card's Competency Areas field as printed,
#                              including cards whose field names no CA code
#                              ("All competencies relevant to the fields of
#                              research.")
#   scywf:competencyAreasNote  the footnote NCA attaches to that field with
#                              an asterisk, where it does
#
# The card's CA codes are also carried as cybed:relatedUnit links to the
# competency area units, which is the plain "the publisher relates these
# units" edge.
#
# Sub-point parser: disabled. SCyWF's statements are published statements,
# and a parser-split fragment of one would be text NCA did not print.

scywf_framework_id <- "scywf-1.5"
scywf_prefix       <- "scywf"

scywf_statement_subtype <- c(
  task      = "TaskStatement",
  knowledge = "KnowledgeStatement",
  skill     = "SkillStatement"
)

#' Build the SCyWF framework, unit and element nodes.
#'
#' @param categories Tibble: category_id, category_name.
#' @param specialty_areas Tibble: specialty_area_id, specialty_area_name,
#'   category_id.
#' @param roles Tibble, one row per job role card: role_id, role_name,
#'   specialty_area_id, description, competency_areas_text,
#'   competency_areas_note.
#' @param statements Tibble: statement_id, statement_type, text, technical.
#' @param role_statements Tibble: role_id, statement_id, statement_type,
#'   ordinal.
#' @param competency_areas Tibble: ca_id, ca_name, description.
#' @param role_competency_areas Tibble: role_id, ca_id, ordinal.
#' @param prov List, the parsed provenance manifest.
#' @return List with framework, roles, elements and prefix, the shape the
#'   other assemblers return.
build_scywf_parts <- function(categories, specialty_areas, roles, statements,
                              role_statements, competency_areas,
                              role_competency_areas, prov) {
  framework_node <- build_framework_node(
    framework_id     = scywf_framework_id,
    framework_name   = prov$framework_version,
    framework_prefix = scywf_prefix,
    version          = prov$framework_version,
    publisher        = prov$publisher,
    jurisdiction     = "SA",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = as.character(prov$framework_date),
    attribution      = prov$licensing$attribution
  )

  element_nodes <- statements |>
    purrr::pmap(function(statement_id, statement_type, text, technical, ...) {
      node <- build_role_element_node(
        element_id             = statement_id,
        framework_prefix       = scywf_prefix,
        framework_element_type = unname(scywf_statement_subtype[statement_type]),
        element_text           = text,
        framework_id           = scywf_framework_id
      )
      if (!is.na(technical) && nzchar(technical)) {
        node[["scywf:technical"]] <- technical
      }
      node
    })

  type_rank <- c(task = 1L, knowledge = 2L, skill = 3L)
  role_nodes <- roles |>
    purrr::pmap(function(role_id, role_name, specialty_area_id, description,
                         competency_areas_text, competency_areas_note, ...) {
      rs <- role_statements[role_statements$role_id == role_id, ]
      rs <- rs[order(type_rank[rs$statement_type], rs$ordinal), ]
      ca <- role_competency_areas[role_competency_areas$role_id == role_id, ]
      ca <- ca[order(ca$ordinal), ]

      meta <- list(`scywf:inSpecialtyArea` =
                     list(`@id` = paste0(scywf_prefix, ":specialty-", specialty_area_id)))
      meta <- c(meta, build_related_unit_metadata(ca$ca_id, scywf_prefix))
      meta[["scywf:competencyAreasText"]] <- competency_areas_text
      if (!is.na(competency_areas_note) && nzchar(competency_areas_note)) {
        meta[["scywf:competencyAreasNote"]] <- competency_areas_note
      }

      build_role_node(
        role_id             = role_id,
        role_name           = role_name,
        framework_prefix    = scywf_prefix,
        framework_role_type = "JobRole",
        description         = description,
        element_ids         = unique(rs$statement_id),
        framework_id        = scywf_framework_id,
        metadata            = meta
      )
    })

  ca_nodes <- competency_areas |>
    purrr::pmap(function(ca_id, ca_name, description, ...) {
      build_organizing_unit_node(
        unit_id           = ca_id,
        unit_name         = ca_name,
        framework_prefix  = scywf_prefix,
        framework_subtype = "CompetencyArea",
        is_role           = FALSE,
        description       = description,
        framework_id      = scywf_framework_id
      )
    })

  specialty_nodes <- specialty_areas |>
    purrr::pmap(function(specialty_area_id, specialty_area_name, category_id, ...) {
      build_organizing_unit_node(
        unit_id           = specialty_area_id,
        unit_name         = specialty_area_name,
        framework_prefix  = scywf_prefix,
        framework_subtype = "SpecialtyArea",
        is_role           = FALSE,
        framework_id      = scywf_framework_id,
        metadata          = list(`scywf:inCategory` =
                                   list(`@id` = paste0(scywf_prefix, ":category-", category_id))),
        unit_iri_prefix   = "specialty-"
      )
    })

  category_nodes <- categories |>
    purrr::pmap(function(category_id, category_name, ...) {
      build_organizing_unit_node(
        unit_id           = category_id,
        unit_name         = category_name,
        framework_prefix  = scywf_prefix,
        framework_subtype = "Category",
        is_role           = FALSE,
        framework_id      = scywf_framework_id,
        unit_iri_prefix   = "category-"
      )
    })

  list(framework = framework_node,
       roles     = c(role_nodes, ca_nodes, specialty_nodes, category_nodes),
       elements  = element_nodes,
       prefix    = scywf_prefix)
}
