# JSON-LD adapter for the Cyber Security Body of Knowledge (CyBOK) v1.1.0,
# published by the National Cyber Security Centre (NCSC) under the Open
# Government Licence v3.0.
#
# Sourced by scripts/020-assemble-jsonld.R, which reads the staged tables and
# calls build_cybok_parts(). Kept in its own file so the test suite can drive
# the adapter with a small synthetic fixture instead of the staged data.
# Requires the cybedtools JSON-LD constructors (build_*_node) to be loaded.
#
# scripts/ is .Rbuildignore'd, so nothing here ships in the package.
#
# CyBOK is a body of knowledge, not a workforce framework: it asserts no roles
# and no proficiency levels, so nothing here asserts cybed:Role. Its own
# structure is Knowledge Area, then Topic, then Indicative Material, read by
# scripts/010-ingest-cybok.R from each KA's Knowledge Tree.
#
# Mapping onto the cybed: layer.
#
#   Knowledge Area        cybed:OrganizingUnit, subtype cybok:KnowledgeArea,
#                         keyed by the acronym CyBOK's A-to-Z uses for it
#                         (RMG, AAA, ...). Name as printed in Figure 2 of the
#                         Introduction. Its category (one of the five of
#                         Figure 2) is the literal cybok:category, and the
#                         KA's own document version is schema:version, because
#                         CyBOK versions every KA separately.
#   Topic                 cybed:RoleElement, subtype cybok:Topic, keyed by
#                         the KA acronym and the Topic's place in its tree
#                         (RMG-01). The element text is the Topic as printed
#                         in the tree. CyBOK prints no Topic codes, so the
#                         number is cybedtools' own and follows the tree from
#                         top to bottom.
#   Indicative Material   cybed:Subpoint of its Topic (cybok:RMG-01.sub.1),
#                         also typed cybok:IndicativeMaterial, linked back by
#                         cybed:elaborates. cybed:Subpoint is the package's
#                         class for a child the framework itself enumerates
#                         under a parent element, which is what CyBOK defines
#                         Indicative Material to be. The sub-point parser is
#                         off: nothing is split out of any text, and every
#                         Subpoint here is a node the tree draws.
#
# A KA's cybed:hasElement lists its Topics and their Indicative Material, as
# frameworks with Subpoints do elsewhere.

cybok_framework_id <- "cybok-v1.1.0"
cybok_prefix       <- "cybok"

#' Build the CyBOK framework, unit and element nodes.
#'
#' @param knowledge_areas Tibble: ka_acronym, ka_name, category_name,
#'   ka_order, version.
#' @param topics Tibble: ka_acronym, topic_id, ordinal, title.
#' @param indicative_material Tibble: ka_acronym, topic_id, ordinal, term.
#' @param prov List, the parsed provenance manifest.
#' @return List with framework, roles, elements and prefix, the shape the
#'   other assemblers return.
build_cybok_parts <- function(knowledge_areas, topics, indicative_material, prov) {
  framework_node <- build_framework_node(
    framework_id     = cybok_framework_id,
    framework_name   = prov$framework_version,
    framework_prefix = cybok_prefix,
    version          = prov$framework_version,
    publisher        = prov$publisher,
    jurisdiction     = "UK",
    sector           = "general",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = as.character(prov$framework_date),
    attribution      = prov$licensing$attribution
  )

  topic_nodes <- topics |>
    purrr::pmap(function(topic_id, title, ...) {
      build_role_element_node(
        element_id             = topic_id,
        framework_prefix       = cybok_prefix,
        framework_element_type = "Topic",
        element_text           = title,
        framework_id           = cybok_framework_id
      )
    })

  im_nodes <- indicative_material |>
    purrr::pmap(function(topic_id, ordinal, term, ...) {
      build_subpoint_node(
        parent_element_id = topic_id,
        ordinal           = ordinal,
        text              = term,
        framework_prefix  = cybok_prefix,
        framework_id      = cybok_framework_id,
        parent_subtype    = "IndicativeMaterial"
      )
    })

  topic_rank <- setNames(topics$ordinal, topics$topic_id)
  ka_nodes <- knowledge_areas |>
    dplyr::arrange(ka_order) |>
    purrr::pmap(function(ka_acronym, ka_name, category_name, version, ...) {
      ka_topics <- topics[topics$ka_acronym == ka_acronym, ]
      ka_topics <- ka_topics[order(ka_topics$ordinal), ]
      ka_im <- indicative_material[indicative_material$ka_acronym == ka_acronym, ]
      ka_im <- ka_im[order(topic_rank[ka_im$topic_id], ka_im$ordinal), ]
      build_organizing_unit_node(
        unit_id           = ka_acronym,
        unit_name         = ka_name,
        framework_prefix  = cybok_prefix,
        framework_subtype = "KnowledgeArea",
        is_role           = FALSE,
        element_ids       = c(ka_topics$topic_id,
                              paste0(ka_im$topic_id, ".sub.", ka_im$ordinal)),
        framework_id      = cybok_framework_id,
        metadata          = list(`cybok:category` = category_name,
                                 `schema:version` = as.character(version))
      )
    })

  list(framework = framework_node,
       roles     = ka_nodes,
       elements  = c(topic_nodes, im_nodes),
       prefix    = cybok_prefix)
}
