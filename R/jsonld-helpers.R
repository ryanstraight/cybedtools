# JSON-LD Helpers, Framework-Agnostic `cybed:` Layer
#
# Utilities for generating JSON-LD semantic web representations of
# cybersecurity workforce competency frameworks and learning-standards
# frameworks across jurisdictions and structural types (role-first,
# competence-first, skill-first, learning-standards).
#
# Two-tier namespace architecture (see the namespace-architecture article):
#   Tier 1: `cybed:` (framework-agnostic base vocabulary)
#   Tier 2: per-framework prefixes (nice, dcwf, ecf, sfia, ecsf, cyqual,
#           ccssf, otccf, scywf, cyberorg, csta, csta2026, csec, digcomp,
#           cybok), each defining
#           subclasses of Tier 1 types

# ---------------------------------------------------------------------------
# Namespace constants
# ---------------------------------------------------------------------------

cybed_namespaces <- list(
  schema    = "http://schema.org/",
  skos      = "http://www.w3.org/2004/02/skos/core#",
  rdfs      = "http://www.w3.org/2000/01/rdf-schema#",
  cybed      = "https://w3id.org/cybed/ontology#",
  nice      = "https://nice.nist.gov/framework/terms#",
  dcwf      = "https://public.cyber.mil/wid/dcwf/terms#",
  ecf       = "https://ec.europa.eu/ecf/terms#",
  sfia      = "https://sfia-online.org/en/terms#",
  ecsf      = "https://enisa.europa.eu/ecsf/terms#",
  # Pedagogical frameworks (Tier 2 subclasses):
  cyberorg  = "https://cyber.org/standards/terms#",
  csta      = "https://csteachers.org/k12standards/terms#",
  csec      = "https://cybered.acm.org/csec2017/terms#",
  digcomp   = "https://ec.europa.eu/jrc/digcomp/terms#",
  # Frameworks ingested by written steward permission (v0.3.0). Their Tier 2
  # terms are minted under the cybed namespace, not the steward's own
  # domain, so a package-coined subtype is never mistaken for an identifier
  # the steward issued.
  cyqual    = "https://w3id.org/cybed/framework/cyqual#",
  ccssf     = "https://w3id.org/cybed/framework/ccssf#",
  otccf     = "https://w3id.org/cybed/framework/otccf#",
  # The 2026 CSTA PK-12 standards are a separate framework from the 2017
  # edition, with their own identifier scheme. Their package-coined terms
  # (csta2026:StandardGroup and the per-standard literal properties) are
  # minted under the cybed namespace for the same reason as above.
  csta2026  = "https://w3id.org/cybed/framework/csta2026#",
  # Saudi Cybersecurity Workforce Framework, ingested by written permission
  # of the National Cybersecurity Authority. Its package-coined terms
  # (scywf:JobRole, the group subtypes and the derived hierarchy predicates)
  # are minted under the cybed namespace for the same reason as above.
  scywf     = "https://w3id.org/cybed/framework/scywf#",
  # Cyber Security Body of Knowledge (NCSC, Open Government Licence v3.0).
  # CyBOK publishes no vocabulary of its own, so its package-coined terms
  # (cybok:KnowledgeArea, cybok:Topic, cybok:IndicativeMaterial and
  # cybok:category) are minted under the cybed namespace as above.
  cybok     = "https://w3id.org/cybed/framework/cybok#"
)

# Valid framework prefixes (Tier 2). Workforce + pedagogical.
valid_framework_prefixes <- c(
  # Workforce competency frameworks
  "nice", "dcwf", "ecf", "sfia", "ecsf", "cyqual", "ccssf", "otccf", "scywf",
  # Pedagogical learning-standards / curriculum frameworks and bodies of
  # knowledge
  "cyberorg", "csta", "csta2026", "csec", "digcomp", "cybok"
)

#' Build a standard JSON-LD `@context` block
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Only the relevant framework prefix is included alongside base vocabularies,
#' keeping per-framework contexts compact. For multi-framework graphs used
#' in cross-framework queries, use [build_multi_framework_context()].
#'
#' @param framework_prefix Character, one of the valid framework prefixes.
#'   Workforce: `"nice"`, `"dcwf"`, `"ecf"`, `"sfia"`, `"ecsf"`, `"cyqual"`,
#'   `"ccssf"`, `"otccf"`, `"scywf"`.
#'   Pedagogical: `"cyberorg"`, `"csta"`, `"csta2026"`, `"csec"`, `"digcomp"`,
#'   `"cybok"`.
#' @return Named list suitable for use as JSON-LD `@context`.
#' @family JSON-LD construction
#' @export
#' @examples
#' ctx <- build_jsonld_context("nice")
#' names(ctx)
#' # "schema" "skos" "rdfs" "cybed" "nice"
build_jsonld_context <- function(framework_prefix) {
  framework_prefix <- match.arg(framework_prefix, choices = valid_framework_prefixes)

  base_prefixes <- c("schema", "skos", "rdfs", "cybed")
  included_prefixes <- c(base_prefixes, framework_prefix)
  cybed_namespaces[included_prefixes]
}

#' Build a JSON-LD `@context` block covering multiple frameworks
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Use when assembling a combined graph that spans more than one framework,
#' so a single SPARQL query can traverse all included vocabularies.
#'
#' @param framework_prefixes Character vector of framework prefixes.
#' @return Named list suitable for use as JSON-LD `@context`.
#' @family JSON-LD construction
#' @export
#' @examples
#' ctx <- build_multi_framework_context(c("nice", "sfia", "ecsf"))
#' names(ctx)
#' # "schema" "skos" "rdfs" "cybed" "nice" "sfia" "ecsf"
build_multi_framework_context <- function(framework_prefixes) {
  invalid <- setdiff(framework_prefixes, valid_framework_prefixes)
  if (length(invalid) > 0) {
    rlang::abort(
      c(
        "Unknown framework prefix(es) supplied to `build_multi_framework_context()`.",
        "x" = paste0("Got unknown: ", paste(invalid, collapse = ", "), "."),
        "i" = paste0("Valid prefixes are: ",
                     paste(valid_framework_prefixes, collapse = ", "), ".")
      ),
      class = "cybedtools_unknown_prefix"
    )
  }

  base_prefixes <- c("schema", "skos", "rdfs", "cybed")
  included_prefixes <- c(base_prefixes, framework_prefixes)
  cybed_namespaces[included_prefixes]
}

# ---------------------------------------------------------------------------
# Tier 1: Framework-level construction
# ---------------------------------------------------------------------------

#' Construct a `cybed:Framework` top-level node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Every framework rendered through cybedtools produces exactly one of these
#' nodes. Downstream Role and RoleElement nodes attach to it via
#' `cybed:partOf`.
#'
#' @param framework_id Character, internal identifier (e.g., `"nice-v2"`,
#'   `"ecf-2.0"`, `"ecsf-2022"`, `"sfia-9"`, `"dcwf-2024"`).
#' @param framework_name Character, human-readable name.
#' @param framework_prefix Character, the Tier 2 prefix for this framework.
#' @param version Character, publisher version string.
#' @param publisher Character, publisher name.
#' @param jurisdiction Character: `"US"`, `"EU"`, `"UK"`, `"global"`, or an
#'   ISO 3166-1 alpha-2 country code for a national framework (e.g., `"CZ"`,
#'   `"CA"`, `"SG"`).
#' @param sector Character, one of `"civilian"`, `"defense"`, `"general"`.
#' @param specificity Character, one of `"general-IT"`,
#'   `"cybersecurity-specific"`.
#' @param license Character, license URI or SPDX identifier.
#' @param date_published Character, ISO-8601 date.
#' @param attribution Character, the attribution statement the framework's
#'   steward requires, recorded verbatim as `schema:creditText`. Supply it
#'   exactly as the steward worded it.
#' @param in_language Character, BCP 47 language tag of the framework's
#'   statement text (e.g., `"cs"`), recorded as `schema:inLanguage`. Omit for
#'   English-language frameworks.
#' @return Named list (JSON-LD node) describing the framework.
#' @family JSON-LD construction
#' @export
#' @examples
#' fw <- build_framework_node(
#'   framework_id     = "nice-v2",
#'   framework_name   = "NICE Framework v2",
#'   framework_prefix = "nice",
#'   version          = "2.0.0",
#'   publisher        = "NIST",
#'   jurisdiction     = "US",
#'   sector           = "civilian",
#'   specificity      = "cybersecurity-specific"
#' )
#' fw[["@id"]]
#' fw[["@type"]]
build_framework_node <- function(framework_id,
                                 framework_name,
                                 framework_prefix,
                                 version,
                                 publisher,
                                 jurisdiction,
                                 sector,
                                 specificity,
                                 license = NA_character_,
                                 date_published = NA_character_,
                                 attribution = NA_character_,
                                 in_language = NA_character_) {
  node <- list(
    `@id`                 = glue::glue("cybed:framework/{framework_id}"),
    `@type`               = c(glue::glue("{framework_prefix}:Framework"), "cybed:Framework"),
    `schema:name`         = framework_name,
    `schema:version`      = version,
    `schema:publisher`    = publisher,
    `cybed:jurisdiction`   = jurisdiction,
    `cybed:sector`         = sector,
    `cybed:specificity`    = specificity
  )

  if (!is.na(license))         node[["schema:license"]] <- license
  if (!is.na(date_published))  node[["schema:datePublished"]] <- date_published
  if (!is.na(attribution))     node[["schema:creditText"]] <- attribution
  if (!is.na(in_language))     node[["schema:inLanguage"]] <- in_language

  node
}

# ---------------------------------------------------------------------------
# Tier 2: Organizing-unit construction (per-framework subclasses)
# ---------------------------------------------------------------------------

#' Construct a `cybed:OrganizingUnit` node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Every framework's top-level enumerated unit is an instance of
#' `cybed:OrganizingUnit` (subClassOf `skos:Concept`), the cross-framework
#' abstract that lets one SPARQL query reach every framework's parent
#' units uniformly. Workforce frameworks (NICE, DCWF, ENISA ECSF) where the
#' unit is genuinely a work role or work profile additionally assert
#' `cybed:Role` (itself `subClassOf cybed:OrganizingUnit`); pass `is_role =
#' TRUE` for those. Non-workforce frameworks (SFIA enumerates skills;
#' Cyber.org K-12, CSTA, CSEC2017, DigComp 3.0 enumerate other organizing
#' units) assert `cybed:OrganizingUnit` only.
#'
#' Each unit also carries a per-framework subtype (e.g., `nice:WorkRole`,
#' `sfia:Skill`, `csta:StandardGroup`, `cyberorg:StandardGroup`).
#' Cross-framework queries target `cybed:OrganizingUnit`; framework-specific
#' queries target the per-framework subtype; workforce-only queries target
#' `cybed:Role`.
#'
#' For backward-compatible workforce-only construction, see [build_role_node()].
#'
#' @param unit_id Character, framework-local identifier
#'   (e.g., `"OG-WRL-015"`, `"PROG"`, `"3A-AP-13"`).
#' @param unit_name Character, human-readable name.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_subtype Character, the framework's specific subtype name
#'   (e.g., `"WorkRole"`, `"Skill"`, `"StandardGroup"`,
#'   `"StandardGroup"`, `"KnowledgeArea"`, `"CompetenceArea"`).
#' @param is_role Logical, whether to additionally assert `cybed:Role`.
#'   `TRUE` for NICE work roles, DCWF work roles, and ENISA ECSF profiles;
#'   `FALSE` for SFIA skills, Cyber.org K-12 grade-band cells, CSTA
#'   level x concept cells, CSEC2017 Knowledge Areas, and DigComp competence
#'   areas. Defaults to `FALSE`.
#' @param description Character, unit description text.
#' @param element_ids Character vector of role-element identifiers to link
#'   via `cybed:hasElement`.
#' @param framework_id Character, framework identifier (e.g., `"nice-v2"`)
#'   to populate `cybed:partOf`.
#' @param metadata Named list, optional additional fields to include.
#' @param unit_iri_prefix Character, optional discriminator inserted in front
#'   of `unit_id` in the minted IRI, so the unit becomes
#'   `{framework_prefix}:{unit_iri_prefix}{unit_id}` instead of
#'   `{framework_prefix}:{unit_id}`. Use it when a framework numbers its
#'   units and its statements out of one id space, which makes a unit IRI and
#'   a statement IRI collide and fuses two nodes into one. DCWF numbers work
#'   roles and task/KSA statements from the same range, and Cyber.org K-12
#'   names a grade-band cell after the standard it holds; both are minted
#'   with a prefix for that reason. When a prefix is supplied the unit's own
#'   printed code is retained as a `schema:identifier` literal, so nothing
#'   the IRI used to carry is lost. Defaults to `NULL`, which mints the bare
#'   IRI and adds no literal: existing behaviour for every other framework
#'   and for a user's own.
#' @return Named list (JSON-LD node).
#' @family JSON-LD construction
#' @export
#' @examples
#' # Workforce framework: assert cybed:Role.
#' role <- build_organizing_unit_node(
#'   unit_id           = "OG-WRL-015",
#'   unit_name         = "Cybersecurity Architecture",
#'   framework_prefix  = "nice",
#'   framework_subtype = "WorkRole",
#'   is_role           = TRUE,
#'   description       = "Designs enterprise security architectures.",
#'   element_ids       = c("T0001", "K0001"),
#'   framework_id      = "nice-v2"
#' )
#' role[["@type"]]
#' # c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")
#'
#' # Non-workforce framework: cybed:OrganizingUnit only.
#' bucket <- build_organizing_unit_node(
#'   unit_id           = "3A-IC",
#'   unit_name         = "Level 3A / Impacts of Computing",
#'   framework_prefix  = "csta",
#'   framework_subtype = "StandardGroup",
#'   is_role           = FALSE,
#'   framework_id      = "csta-2017"
#' )
#' bucket[["@type"]]
#' # c("csta:StandardGroup", "cybed:OrganizingUnit")
#'
#' # A framework whose unit ids and statement ids share one space.
#' cell <- build_organizing_unit_node(
#'   unit_id           = "K-2.SEC.AUTH",
#'   unit_name         = "K-2 / Security / Authentication",
#'   framework_prefix  = "cyberorg",
#'   framework_subtype = "StandardGroup",
#'   unit_iri_prefix   = "cell-"
#' )
#' cell[["@id"]]
#' cell[["schema:identifier"]]
build_organizing_unit_node <- function(unit_id,
                                        unit_name,
                                        framework_prefix,
                                        framework_subtype,
                                        is_role = FALSE,
                                        description = NA_character_,
                                        element_ids = character(0),
                                        framework_id = NA_character_,
                                        metadata = list(),
                                        unit_iri_prefix = NULL) {
  type_set <- c(glue::glue("{framework_prefix}:{framework_subtype}"))
  if (isTRUE(is_role)) {
    type_set <- c(type_set, "cybed:Role")
  }
  # cybed:OrganizingUnit is asserted explicitly because librdf does not
  # perform subClassOf inference; cross-framework queries against the
  # abstract type require the triple to be present in the graph.
  type_set <- c(type_set, "cybed:OrganizingUnit")

  # A discriminator is only ever prepended to the IRI. The element ids below
  # are untouched, because the collision is between a unit and a statement,
  # not between two statements, and statement IRIs are the codes people cite.
  discriminator <- if (is.null(unit_iri_prefix)) "" else as.character(unit_iri_prefix)
  if (length(discriminator) != 1L || is.na(discriminator)) discriminator <- ""

  node <- list(
    `@id`            = glue::glue("{framework_prefix}:{discriminator}{unit_id}"),
    `@type`          = type_set,
    `schema:name`    = unit_name
  )

  # The printed code left the IRI, so it is asserted as data instead. Emitted
  # only under a discriminator: the frameworks that mint bare IRIs already
  # carry their code in the IRI, and adding a literal there would change
  # graphs that have no defect to fix.
  if (nzchar(discriminator)) {
    node[["schema:identifier"]] <- unit_id
  }

  if (!is.na(description)) {
    node[["schema:description"]] <- description
  }

  if (!is.na(framework_id)) {
    node[["cybed:partOf"]] <- list(`@id` = glue::glue("cybed:framework/{framework_id}"))
  }

  if (length(element_ids) > 0) {
    node[["cybed:hasElement"]] <- purrr::map(
      element_ids,
      \(eid) list(`@id` = glue::glue("{framework_prefix}:{eid}"))
    )
  }

  c(node, metadata)
}

#' Construct a `cybed:Role` node (workforce frameworks)
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Convenience wrapper around [build_organizing_unit_node()] for workforce
#' frameworks (NICE, DCWF, ENISA ECSF). Asserts `cybed:Role` in addition to
#' `cybed:OrganizingUnit` and the per-framework subtype. For non-workforce
#' frameworks (SFIA, Cyber.org K-12, CSTA, CSEC2017, DigComp 3.0), call
#' [build_organizing_unit_node()] directly with `is_role = FALSE`.
#'
#' @param role_id Character, framework-local identifier (e.g., `"OG-WRL-015"`).
#' @param role_name Character, human-readable name.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_role_type Character, specific subclass name within the
#'   framework vocabulary (e.g., `"WorkRole"`, `"RoleProfile"`).
#' @param description Character, role description text.
#' @param element_ids Character vector of role-element identifiers to link.
#' @param framework_id Character, framework identifier (e.g., `"nice-v2"`) to
#'   populate `cybed:partOf`. Enables SPARQL queries that traverse role to
#'   framework. Recommended. Defaults to `NA` for backward compatibility.
#' @param opm_codes Character vector of OPM occupational-series codes to
#'   attach as the multi-valued literal property `cybed:opmCode`. NICE
#'   v2.2.0 publishes Federal-use OPM cybersecurity data standard codes per
#'   work role; a role may carry zero, one, or several codes (e.g., NICE
#'   `DD-WRL-004` carries two). The codes are modeled as literals, not
#'   nodes: the published `opm_code` elements have no descriptive payload
#'   (title/text are empty; the code is the identifier). Empty vector (the
#'   default) and `NA` entries omit the property. Merged via the same
#'   metadata-merge path used for `cybed:ecfCrossReference`,
#'   `cybed:cybokCrossReference`, and `cybed:niceCrossReference` (the
#'   framework's own cited NICE work-role ids, recorded as literals where the
#'   cited ids do not resolve to elements in this graph).
#' @param metadata Named list, optional additional fields to include.
#' @param unit_iri_prefix Character, optional discriminator for the minted
#'   role IRI, passed through to [build_organizing_unit_node()]. Supply it for
#'   a framework that numbers its roles and its statements out of one id
#'   space, such as DCWF, where a work-role code and a task/KSA number can be
#'   the same number. The role's printed code is then kept as a
#'   `schema:identifier` literal. Defaults to `NULL`, the bare IRI.
#' @return Named list (JSON-LD node).
#' @family JSON-LD construction
#' @export
#' @examples
#' role <- build_role_node(
#'   role_id              = "OG-WRL-015",
#'   role_name            = "Cybersecurity Architecture",
#'   framework_prefix     = "nice",
#'   framework_role_type  = "WorkRole",
#'   description          = "Designs enterprise security architectures.",
#'   element_ids          = c("T0001", "K0001"),
#'   framework_id         = "nice-v2"
#' )
#' role[["@type"]]
#' # c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")
#'
#' # Multi-valued OPM codes (NICE v2.2.0 Federal-use annotation).
#' role_opm <- build_role_node(
#'   role_id              = "DD-WRL-004",
#'   role_name            = "Enterprise Architecture",
#'   framework_prefix     = "nice",
#'   framework_role_type  = "WorkRole",
#'   framework_id         = "nice-v2",
#'   opm_codes            = c("631", "632")
#' )
#' role_opm[["cybed:opmCode"]]
#'
#' # DCWF numbers work roles and task/KSA statements from one range, so its
#' # role IRIs carry a discriminator and the printed code becomes a literal.
#' dcwf_role <- build_role_node(
#'   role_id             = "462",
#'   role_name           = "Systems Security Analyst",
#'   framework_prefix    = "dcwf",
#'   framework_role_type = "WorkRole",
#'   framework_id        = "dcwf-v5.1",
#'   unit_iri_prefix     = "role-"
#' )
#' dcwf_role[["@id"]]
#' dcwf_role[["schema:identifier"]]
build_role_node <- function(role_id,
                            role_name,
                            framework_prefix,
                            framework_role_type,
                            description = NA_character_,
                            element_ids = character(0),
                            framework_id = NA_character_,
                            opm_codes = character(0),
                            metadata = list(),
                            unit_iri_prefix = NULL) {
  opm_codes <- as.character(opm_codes)
  opm_codes <- opm_codes[!is.na(opm_codes) & nzchar(opm_codes)]
  if (length(opm_codes) > 0) {
    metadata <- c(metadata, list(`cybed:opmCode` = opm_codes))
  }

  build_organizing_unit_node(
    unit_id           = role_id,
    unit_name         = role_name,
    framework_prefix  = framework_prefix,
    framework_subtype = framework_role_type,
    is_role           = TRUE,
    description       = description,
    element_ids       = element_ids,
    framework_id      = framework_id,
    metadata          = metadata,
    unit_iri_prefix   = unit_iri_prefix
  )
}

# ---------------------------------------------------------------------------
# Tier 1: Unit-to-unit relations
# ---------------------------------------------------------------------------

#' Build `cybed:relatedUnit` metadata for an organizing unit
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Some frameworks relate one organizing unit to another: a job role to the
#' skills it requires, a knowledge unit to the outcomes it supports. The
#' plain `cybed:relatedUnit` edge records that the publisher relates the two
#' units and nothing more, so "which units does this unit point at" stays a
#' one-hop query. When the publisher qualifies the relation (a required
#' proficiency level, a named relation type), also emit a
#' [build_unit_relation_node()] for the pair.
#'
#' Pass the result as (part of) the `metadata` argument of
#' [build_organizing_unit_node()] or [build_role_node()]. Call it ONCE per
#' source unit with every target that unit has: two calls merged with `c()`
#' give the node two `cybed:relatedUnit` keys, which is not valid JSON-LD.
#' Targets in several frameworks go in one call, with `to_prefix` given per
#' target.
#'
#' @param to_unit_ids Character vector of target unit identifiers.
#' @param to_prefix Character, Tier 2 prefix the targets live under: one
#'   value for all targets, or one per target. Differs from the source
#'   unit's prefix when the relation crosses frameworks.
#' @return Named list with one entry, `cybed:relatedUnit`, or an empty list
#'   when there are no targets.
#' @family JSON-LD construction
#' @export
#' @examples
#' build_related_unit_metadata(c("skill-a", "skill-b"), "otccf")
#'
#' # Targets in two frameworks, one call.
#' build_related_unit_metadata(c("skill-a", "OG-WRL-015"), c("otccf", "nice"))
build_related_unit_metadata <- function(to_unit_ids, to_prefix) {
  to_unit_ids <- as.character(to_unit_ids)
  if (!length(to_prefix) %in% c(1L, length(to_unit_ids))) {
    rlang::abort(
      c(
        "`to_prefix` must have length 1 or the length of `to_unit_ids`.",
        "x" = paste0("Got ", length(to_prefix), " prefix(es) for ",
                     length(to_unit_ids), " target(s).")
      ),
      class = "cybedtools_bad_length"
    )
  }
  to_prefix <- rep_len(as.character(to_prefix), length(to_unit_ids))

  # Guard before pasting: paste0() recycles a zero-length vector as "", so an
  # empty target set would otherwise mint one bogus ":" target.
  keep <- !is.na(to_unit_ids) & nzchar(to_unit_ids)
  if (!any(keep)) return(list())

  targets <- unique(paste0(to_prefix[keep], ":", to_unit_ids[keep]))

  list(`cybed:relatedUnit` = purrr::map(targets, \(iri) list(`@id` = iri)))
}

# Reversible IRI-safe encoding for the free-text parts of a relation id.
# Percent-encoding keeps "3, 4", "3-4" and "3 4" distinct where a plain
# squash to "-" would merge them.
#' @noRd
relation_id_part <- function(x) {
  gsub("%", "_", utils::URLencode(as.character(x), reserved = TRUE), fixed = TRUE)
}

#' Construct a `cybed:UnitRelation` node
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A qualified relation between two organizing units, used when the publisher
#' says more than "these are related": a required proficiency level, or a
#' named relation type. The matching plain edge is asserted separately with
#' [build_related_unit_metadata()].
#'
#' A statement's identity is (from unit, to unit and its framework, relation
#' label, level), and the node `@id` is built from all of them, so the same
#' pair at two levels, under two labels, or pointing into two frameworks
#' gives distinct nodes. Identical inputs give identical nodes: when a source
#' prints the same statement twice, deduplicate rows before calling.
#'
#' `proficiency_level` is stored as a string exactly as printed. Pass it as
#' character. Frameworks use incompatible scales (1 to 6, 1 to 5, Basic /
#' Intermediate / Advanced), and a shared numeric type would assert a
#' comparability the sources do not.
#'
#' @param from_unit_id,to_unit_id Character, unit identifiers.
#' @param from_prefix Character, Tier 2 prefix of the source unit. The
#'   relation node is minted under this prefix.
#' @param to_prefix Character, Tier 2 prefix of the target unit. Defaults to
#'   `from_prefix`; set it when the relation crosses frameworks.
#' @param relation_label Character, the publisher's own word for the relation
#'   (e.g., `"requires"`, `"supports"`).
#' @param proficiency_level Character, the level as printed.
#' @param source_section Character, where the relation appears in the source.
#' @param framework_id Character, framework identifier to populate
#'   `cybed:partOf`.
#' @return Named list (JSON-LD node).
#' @family JSON-LD construction
#' @export
#' @examples
#' rel <- build_unit_relation_node(
#'   from_unit_id      = "ot-security-engineer",
#'   to_unit_id        = "network-security",
#'   from_prefix       = "otccf",
#'   relation_label    = "requires",
#'   proficiency_level = "4",
#'   framework_id      = "otccf-v1.1"
#' )
#' rel[["@type"]]
#' rel[["cybed:proficiencyLevel"]]
build_unit_relation_node <- function(from_unit_id,
                                     to_unit_id,
                                     from_prefix,
                                     to_prefix = from_prefix,
                                     relation_label = NA_character_,
                                     proficiency_level = NA_character_,
                                     source_section = NA_character_,
                                     framework_id = NA_character_) {
  proficiency_level <- as.character(proficiency_level)

  # One node is one statement. A vector here would reach the scalar
  # is.na() guards below and fail without saying which argument was wrong.
  for (arg in c("from_unit_id", "to_unit_id", "relation_label", "proficiency_level")) {
    if (length(get(arg)) != 1L) {
      rlang::abort(
        c(
          paste0("`", arg, "` must be a single value."),
          "x" = paste0("Got length ", length(get(arg)), "."),
          "i" = "Build one node per statement, e.g. with `purrr::pmap()` over the rows."
        ),
        class = "cybedtools_scalar_input"
      )
    }
  }

  # Everything that distinguishes one published statement from another goes
  # into the id. The target's prefix appears only when it differs, so
  # same-framework ids stay short.
  to_part <- if (identical(to_prefix, from_prefix)) to_unit_id else paste0(to_prefix, ".", to_unit_id)
  id_parts <- c(from_unit_id, to_part)
  if (!is.na(relation_label)) {
    id_parts <- c(id_parts, relation_id_part(relation_label))
  }
  if (!is.na(proficiency_level)) {
    id_parts <- c(id_parts, paste0("L", relation_id_part(proficiency_level)))
  }

  node <- list(
    `@id`            = glue::glue("{from_prefix}:relation/{paste(id_parts, collapse = '--')}"),
    `@type`          = "cybed:UnitRelation",
    `cybed:fromUnit` = list(`@id` = glue::glue("{from_prefix}:{from_unit_id}")),
    `cybed:toUnit`   = list(`@id` = glue::glue("{to_prefix}:{to_unit_id}"))
  )

  if (!is.na(relation_label))    node[["cybed:relationLabel"]]    <- relation_label
  if (!is.na(proficiency_level)) node[["cybed:proficiencyLevel"]] <- proficiency_level
  if (!is.na(source_section))    node[["cybed:sourceSection"]]    <- source_section

  if (!is.na(framework_id)) {
    node[["cybed:partOf"]] <- list(`@id` = glue::glue("cybed:framework/{framework_id}"))
  }

  node
}

# ---------------------------------------------------------------------------
# Tier 2: Role element construction
# ---------------------------------------------------------------------------

#' Construct a `cybed:Subpoint` node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' A subpoint is a granular pedagogical or specification fragment lifted out
#' of a parent element's prose (typically from a "such as", "examples of",
#' or semicolon-delimited list inside `cybed:elementText`). Subpoints carry
#' the framework-native subtype `cybed:Subpoint` plus the parent's framework
#' subtype, retain `cybed:partOf` to the cluster, and link back to the
#' parent element via `cybed:elaborates`.
#'
#' Use [parse_subpoints()] to derive subpoint records from a parent's text;
#' this constructor turns one such record into a JSON-LD node.
#'
#' @param parent_element_id Character, the framework-local id of the parent
#'   element (without prefix), e.g., `"K-2.SEC.AUTH"`.
#' @param ordinal Integer, the 1-based subpoint ordinal within the parent.
#' @param text Character, the subpoint's text fragment.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_id Character, framework identifier for `cybed:partOf`.
#' @param parent_subtype Character, the parent element's framework subtype
#'   (e.g., `"Standard"`, `"SkillLevel"`). The subpoint is also typed as
#'   this subtype so it appears in framework-native queries.
#' @return Named list (JSON-LD node) for the subpoint.
#' @family Sub-point parsing
#' @export
#' @examples
#' sp <- build_subpoint_node(
#'   parent_element_id = "K-2.SEC.AUTH",
#'   ordinal           = 1,
#'   text              = "not using common words as passwords",
#'   framework_prefix  = "cyberorg",
#'   framework_id      = "cyberorg-k12-v1.0",
#'   parent_subtype    = "Standard"
#' )
#' sp[["@id"]]
#' sp[["cybed:elaborates"]]
build_subpoint_node <- function(parent_element_id,
                                ordinal,
                                text,
                                framework_prefix,
                                framework_id,
                                parent_subtype = "RoleElement") {
  parent_iri  <- glue::glue("{framework_prefix}:{parent_element_id}")
  subpoint_iri <- glue::glue("{parent_iri}.sub.{ordinal}")

  list(
    `@id`                = subpoint_iri,
    `@type`              = c(
      glue::glue("{framework_prefix}:{parent_subtype}"),
      "cybed:Subpoint",
      "cybed:RoleElement"
    ),
    `cybed:elementText`  = text,
    `cybed:partOf`       = list(`@id` = glue::glue("cybed:framework/{framework_id}")),
    `cybed:elaborates`   = list(`@id` = parent_iri)
  )
}

#' Construct a `cybed:Example` node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' An Example is a pedagogical-scaffolding fragment lifted from a parent
#' element's "Clarification statement:" prose. Distinct from
#' [build_subpoint_node()], which represents enumerated sub-statements that
#' the framework specifies as part of a parent element's normative content.
#' Examples carry `@type` `[cybed:Example, cybed:RoleElement]` and no
#' framework-native subtype: Cyber.org K-12 and CSTA Clarification examples
#' are teacher-facing scaffolding rather than enumerable sub-standards, so
#' framework-native typing would overstate what the framework specifies.
#'
#' Examples connect to their parent through the parent element's
#' `cybed:hasExample` predicate (parent → example direction). Examples do
#' not carry a back-pointer such as `cybed:elaborates`; the parent owns the
#' Example, not the converse. Examples are excluded from default
#' `cybed:hasElement` traversals: a role-level query for "all elements"
#' returns Subpoints but not Examples. Reach Examples by traversing the
#' parent element's `cybed:hasExample`.
#'
#' [parse_subpoints()] flags rows from "Clarification statement:" sources as
#' `node_type == "Example"`; [expand_with_subpoints()] routes those rows to
#' this constructor and emits the parent's `cybed:hasExample` triples.
#'
#' @param parent_element_id Character, the framework-local id of the parent
#'   element (without prefix), e.g., `"K-2.SEC.AUTH"`.
#' @param ordinal Integer, the 1-based example ordinal within the parent.
#' @param text Character, the example's text fragment.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_id Character, framework identifier for `cybed:partOf`.
#' @return Named list (JSON-LD node) for the example.
#' @family Sub-point parsing
#' @export
#' @examples
#' ex <- build_example_node(
#'   parent_element_id = "K-2.SEC.AUTH",
#'   ordinal           = 1,
#'   text              = "not using common words as passwords",
#'   framework_prefix  = "cyberorg",
#'   framework_id      = "cyberorg-k12-v1.0"
#' )
#' ex[["@id"]]
#' ex[["@type"]]
build_example_node <- function(parent_element_id,
                                ordinal,
                                text,
                                framework_prefix,
                                framework_id) {
  parent_iri  <- glue::glue("{framework_prefix}:{parent_element_id}")
  example_iri <- glue::glue("{parent_iri}.example.{ordinal}")

  list(
    `@id`                = example_iri,
    `@type`              = c("cybed:Example", "cybed:RoleElement"),
    `cybed:elementText`  = text,
    `cybed:partOf`       = list(`@id` = glue::glue("cybed:framework/{framework_id}"))
  )
}

#' Parse subpoints out of a parent element's text
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Heuristic regex parser. Extracts enumerated child fragments from a
#' parent element's prose, returning a tibble of one row per fragment.
#' Returns an empty tibble for atomic statements that have no list to
#' lift.
#'
#' Two source patterns are recognized, and each row is tagged with the
#' `node_type` it should be promoted to in the JSON-LD graph:
#'
#' - **"Clarification statement:" segments** (Cyber.org K-12 and CSTA
#'   convention). These are teacher-facing pedagogical scaffolding rather
#'   than framework-as-specified enumerations. Rows derived from this
#'   pattern carry `node_type == "Example"` and are promoted to
#'   [cybed:Example][build_example_node()] nodes by [expand_with_subpoints()].
#' - **"such as / including / examples of ..." patterns** (NICE, SFIA,
#'   ECSF, CSEC2017). These are within-text enumerations the framework
#'   specifies as part of the parent's normative content. Rows derived
#'   from this pattern carry `node_type == "Subpoint"` and are promoted
#'   to [cybed:Subpoint][build_subpoint_node()] nodes.
#'
#' The full algorithm and known limitations are documented in
#' `docs/framework-data-sources.md`.
#'
#' Per-framework opt-out: set the `CYBED_DISABLE_SUBPOINT_PARSER` env var
#' (comma-separated framework slugs) and pass the slug as `framework_slug`.
#'
#' @param text Character scalar. A parent element's `cybed:elementText`.
#' @param framework_slug Character, optional. Framework slug for the
#'   per-framework opt-out check. Defaults to `NULL` (no opt-out).
#' @return Tibble with columns `ordinal` (integer, 1-based), `text`
#'   (character), and `node_type` (character, `"Subpoint"` or `"Example"`).
#'   Empty tibble (with the same column shape) when fewer than two
#'   fragments are found.
#' @family Sub-point parsing
#' @export
#' @examples
#' # Cyber.org K-12 "Clarification statement:" pattern -> Examples.
#' parse_subpoints(
#'   "Describe a good password. Clarification statement: At this level,
#'   focus on examples such as not using common words; using pass phrases;
#'   combining letters, numbers, and symbols."
#' )
#'
#' # "Such as ..." comma list -> Subpoints. Common in SFIA, NICE, CSEC2017.
#' parse_subpoints(
#'   "Authentication methods such as certificate, token-based, two-factor,
#'   multifactor, and biometric."
#' )
#'
#' # Atomic statement returns an empty tibble.
#' parse_subpoints(
#'   "Provides authoritative consultation on financial impact assessment."
#' )
parse_subpoints <- function(text, framework_slug = NULL) {
  empty <- tibble::tibble(
    ordinal   = integer(0),
    text      = character(0),
    node_type = character(0)
  )

  # Guard against null / NA / zero-length inputs. Each is a legal R value
  # the parser may receive (e.g., when a parent element has no elementText
  # property bound, or a role element column is sliced to zero rows and
  # yields character(0)). The original scalar-only guard crashed on
  # character(0) ("argument is of length zero") and on length > 1 vectors
  # ("condition has length > 1" pre-R-4.2, hard error since); both are now
  # part of the explicit contract: zero-length returns the empty tibble,
  # length > 1 signals a classed error so vectorized misuse fails loudly
  # instead of silently parsing only the first element.
  if (is.null(text) || length(text) == 0L) return(empty)
  if (length(text) > 1L) {
    rlang::abort(
      c(
        "`text` must be a length-1 character vector.",
        "x" = paste0("Got length ", length(text), "."),
        "i" = "Call parse_subpoints() once per element (e.g., via lapply())."
      ),
      class = "cybedtools_scalar_input"
    )
  }
  if (is.na(text) || nchar(text) == 0) return(empty)

  # Per-framework opt-out via env var. Allows users to disable parsing
  # for a specific framework (e.g., if a steward objects to sub-point
  # promotion for their framework) without modifying ingestion code.
  if (!is.null(framework_slug)) {
    disabled <- Sys.getenv("CYBED_DISABLE_SUBPOINT_PARSER", "")
    if (nzchar(disabled)) {
      disabled_slugs <- trimws(strsplit(disabled, ",")[[1]])
      if (framework_slug %in% disabled_slugs) return(empty)
    }
  }

  # Detect the "Clarification statement:" header BEFORE stripping it. Its
  # presence signals teacher-facing pedagogical scaffolding rather than a
  # framework-as-specified enumeration; the parsed items will be tagged
  # node_type = "Example" instead of "Subpoint", and downstream emission
  # routes them to cybed:Example with a cybed:hasExample link from the
  # parent (excluded from default cybed:hasElement traversals). Other
  # introducer patterns ("such as", "including", semicolon-list) produce
  # framework-as-specified Subpoints.
  has_clarification <- grepl("(?i)Clarification statement:", text, perl = TRUE)
  fragment_node_type <- if (has_clarification) "Example" else "Subpoint"

  # Strip the "Clarification statement:" header so the list-bearing tail
  # is the canonical body for the rest of the function. A no-op on
  # frameworks that do not use the convention.
  body <- sub("(?i)^.*?Clarification statement:\\s*", "", text, perl = TRUE)

  # "e.g." is matched as its own alternative, outside the \b...\b group.
  # \b requires a word/non-word transition on BOTH sides; "e.g." ends in a
  # period (non-word) that is itself almost always followed by another
  # non-word character (a comma or space), so the trailing \b never finds
  # a transition and the alternative silently never matches -- confirmed
  # 2026-08-14 stress test: grepl("(?i)\\be\\.g\\.\\b", "(e.g., foo)",
  # perl=TRUE) is FALSE. Real-world impact traced against DCWF's newly
  # (same-day) parseable text: ~9% of DCWF elements whose only enumeration
  # cue is "(e.g., ...)" produced zero Subpoints as a result, and several
  # more had the swallowed "(e.g." token corrupt an adjacent item. Leading
  # \b is kept (safe: "e" is a word char, reliably preceded by "(" or
  # whitespace); trailing \b is dropped since it cannot match reliably.
  intro_pattern <- "(?i)\\b(such as|examples? of|examples? include|including|for example)\\b|(?i)\\be\\.g\\."
  intro_locs <- gregexpr(intro_pattern, body, perl = TRUE)[[1]]

  # Fallback when no introducer is present: a body with two or more
  # semicolons is treated as an explicit list even without a preamble.
  if (length(intro_locs) == 1 && intro_locs[1] == -1) {
    if (length(gregexpr(";", body, fixed = TRUE)[[1]]) >= 2) {
      items <- strsplit(body, "\\s*;\\s*", perl = TRUE)[[1]]
      items <- trimws(items)
      items <- truncate_at_sentence_boundary(items)
      items <- filter_subpoint_items(items)
      if (length(items) >= 2) {
        return(tibble::tibble(
          ordinal   = seq_along(items),
          text      = items,
          node_type = fragment_node_type
        ))
      }
    }
    return(empty)
  }

  # Take from the LAST introducer to end-of-text as the candidate list,
  # then truncate at the first internal sentence boundary. Without this
  # stop, multi-sentence prose ("data collection. Tests disaster
  # recovery...") gets captured as a single sub-point spanning two
  # statements. The bug surfaced first in SFIA responsibility text.
  last_intro_end <- max(intro_locs + attr(intro_locs, "match.length") - 1L)
  list_segment <- substr(body, last_intro_end + 1, nchar(body))
  list_segment <- sub("\\.\\s*$", "", list_segment)

  # If the introducer sits inside an open parenthetical -- e.g. "...cloud
  # service models (e.g., SaaS, IaaS, and PaaS) for compliance" -- the
  # list must stop at the closing paren, not bleed into whatever clause
  # follows it. Detected by an unmatched "(" earlier in the body than the
  # introducer (a "(" that opened before the intro and hasn't been closed
  # yet). Surfaced by the e.g. fix above: fixing a dead introducer pattern
  # exposed this pre-existing gap, confirmed independently against real
  # DCWF text the same day ("...political) that results in access" --
  # enumeration content bleeding past its closing paren into an unrelated
  # trailing clause).
  before_intro <- substr(body, 1, last_intro_end)
  open_count  <- sum(unlist(gregexpr("(", before_intro, fixed = TRUE)) > 0)
  close_count <- sum(unlist(gregexpr(")", before_intro, fixed = TRUE)) > 0)
  if (open_count > close_count) {
    close_paren_pos <- regexpr(")", list_segment, fixed = TRUE)
    if (close_paren_pos != -1) {
      list_segment <- substr(list_segment, 1, close_paren_pos - 1)
    }
  }

  # A bare single "\n" used to be treated as an unconditional sentence
  # break on its own, terminating the candidate list at the first line
  # wrap regardless of whether that wrap fell mid-sentence. Confirmed
  # 2026-08-14 stress test: real ingested text (Excel-cell-wrapped DCWF
  # prose) legitimately contains soft-wrap newlines that are not sentence
  # boundaries, and the old pattern silently dropped every item after the
  # wrap with no warning (e.g. a 5-item list wrapped after item 3 returned
  # only 3). Newline is now treated symmetrically with "." -- either must
  # be followed by whitespace/newline and an uppercase letter to count as
  # a real boundary; a bare mid-list wrap no longer truncates.
  sentence_break <- regexpr("[.\\n][\\s\\n]+(?=[A-Z])", list_segment, perl = TRUE)
  if (sentence_break != -1) {
    list_segment <- substr(list_segment, 1, sentence_break - 1)
  }

  # Semicolons delimit complex sub-points unambiguously, so they win when
  # present. Otherwise, normalize terminal " and "/" or " to commas so a
  # single comma split handles "A, B, and C" correctly.
  if (grepl(";", list_segment, fixed = TRUE)) {
    items <- strsplit(list_segment, "\\s*;\\s*(?:and\\s+|or\\s+)?", perl = TRUE)[[1]]
  } else {
    norm <- gsub("\\s+(and|or)\\s+", ", ", list_segment, perl = TRUE)
    items <- strsplit(norm, "\\s*,\\s*", perl = TRUE)[[1]]
  }

  # Final clean pass. truncate_at_sentence_boundary handles any individual
  # item that itself contains a sentence break; filter_subpoint_items drops
  # too-short artifacts and pure connective words like "and" or "the" that
  # appear when source data has dangling lists.
  items <- trimws(items)
  items <- truncate_at_sentence_boundary(items)
  items <- filter_subpoint_items(items)

  if (length(items) < 2) return(empty)

  tibble::tibble(
    ordinal   = seq_along(items),
    text      = items,
    node_type = fragment_node_type
  )
}

# Truncate each item at an internal sentence boundary. If an item contains
# "X. Y" where Y starts with uppercase, keep "X" and drop "Y".
#' @noRd
truncate_at_sentence_boundary <- function(items) {
  vapply(items, function(it) {
    sub("\\.[\\s]+(?=[A-Z]).*$", "", it, perl = TRUE)
  }, character(1), USE.NAMES = FALSE)
}

# Filter list items that are too short, are pure connectives (and/or/the),
# or contain mid-item linebreaks (a heuristic signal of accidental capture
# across statement boundaries).
#' @noRd
filter_subpoint_items <- function(items) {
  items <- trimws(items)
  items <- items[nchar(items) >= 3]
  # Drop pure-connective single-word items (artifacts of dangling lists)
  connectives <- c("and", "or", "the", "but", "however", "etc",
                   "etc.", "etcetera")
  items <- items[!tolower(items) %in% connectives]
  # Drop items that contain newlines in the middle (cross-statement bleed)
  items <- items[!grepl("\\n.*[A-Z]", items)]
  items
}

#' Expand parent element nodes with sub-point and example child nodes
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Walks a list of parent element nodes, parses each one's
#' `cybed:elementText` for enumerated child fragments, and returns a list
#' with the parents plus newly-minted child nodes. Each child is routed
#' per its parsed `node_type`:
#'
#' - `node_type == "Subpoint"` (framework-as-specified enumeration from
#'   "such as", "including", semicolon-list patterns) becomes a
#'   [cybed:Subpoint][build_subpoint_node()] node, carries its parent's
#'   framework subtype, and appears in default `cybed:hasElement`
#'   traversals.
#' - `node_type == "Example"` (pedagogical scaffolding from "Clarification
#'   statement:" sources) becomes a [cybed:Example][build_example_node()]
#'   node, carries no framework-native subtype, and is reachable only via
#'   the parent's `cybed:hasExample` predicate (Examples are excluded from
#'   default `cybed:hasElement` collections).
#'
#' Parents that emit any Example children are mutated in place to add
#' `cybed:hasExample` triples linking to those Examples. Parents whose
#' text yields no fragments pass through unchanged. The returned list
#' preserves parent order and appends children after their parents.
#'
#' Child IRIs are deterministic: `<parent_iri>.sub.<ordinal>` for
#' Subpoints and `<parent_iri>.example.<ordinal>` for Examples.
#'
#' @param element_nodes List of named lists produced by
#'   [build_role_element_node()].
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_id Character, framework identifier.
#' @param framework_slug Character, framework slug for per-framework opt-out
#'   via `CYBED_DISABLE_SUBPOINT_PARSER` env var. Optional.
#' @param parent_subtype Character, the framework's element subtype name
#'   (e.g., `"Standard"`, `"SkillLevel"`). Defaults to `"RoleElement"` if
#'   unknown.
#' @return List with two named entries: `nodes` (the expanded list of
#'   parent + child nodes) and `subnode_index` (a tibble with one row
#'   per child: `parent_id`, `subnode_id`, `ordinal`, `node_type`). The
#'   index drives [extend_role_element_ids()], which back-fills the parent
#'   role's `cybed:hasElement` list with Subpoint IDs (Examples excluded).
#' @family Sub-point parsing
#' @export
expand_with_subpoints <- function(element_nodes,
                                  framework_prefix,
                                  framework_id,
                                  framework_slug = NULL,
                                  parent_subtype = NULL) {
  result_nodes <- list()
  index_rows   <- list()

  prefix_pat <- paste0("^", framework_prefix, ":")

  for (parent in element_nodes) {
    if (is.null(parent)) next

    parent_text <- parent[["cybed:elementText"]]
    if (is.null(parent_text)) {
      result_nodes[[length(result_nodes) + 1L]] <- parent
      next
    }

    fragments <- parse_subpoints(parent_text, framework_slug = framework_slug)
    if (nrow(fragments) == 0) {
      result_nodes[[length(result_nodes) + 1L]] <- parent
      next
    }

    parent_iri      <- parent[["@id"]]
    parent_local_id <- sub(prefix_pat, "", parent_iri)

    # Derive parent subtype from the parent node's @type unless caller supplied
    # one. Used only for Subpoint construction; Examples carry no
    # framework-native subtype.
    derived_subtype <- if (is.null(parent_subtype)) {
      ptypes <- parent[["@type"]]
      framework_typed <- ptypes[startsWith(ptypes, paste0(framework_prefix, ":"))]
      if (length(framework_typed) >= 1) {
        sub(prefix_pat, "", framework_typed[[1]])
      } else {
        "RoleElement"
      }
    } else {
      parent_subtype
    }

    fragment_nodes <- list()
    example_iris   <- character(0)

    for (i in seq_len(nrow(fragments))) {
      ordinal_i <- fragments$ordinal[[i]]
      text_i    <- fragments$text[[i]]
      type_i    <- fragments$node_type[[i]]

      if (identical(type_i, "Example")) {
        child <- build_example_node(
          parent_element_id = parent_local_id,
          ordinal           = ordinal_i,
          text              = text_i,
          framework_prefix  = framework_prefix,
          framework_id      = framework_id
        )
        example_iris <- c(example_iris, as.character(child[["@id"]]))
      } else {
        child <- build_subpoint_node(
          parent_element_id = parent_local_id,
          ordinal           = ordinal_i,
          text              = text_i,
          framework_prefix  = framework_prefix,
          framework_id      = framework_id,
          parent_subtype    = derived_subtype
        )
      }

      fragment_nodes[[length(fragment_nodes) + 1L]] <- child
      index_rows[[length(index_rows) + 1L]] <- tibble::tibble(
        parent_id  = parent_local_id,
        subnode_id = sub(prefix_pat, "", as.character(child[["@id"]])),
        ordinal    = as.integer(ordinal_i),
        node_type  = type_i
      )
    }

    # When any Example children are emitted, attach cybed:hasExample triples
    # to the parent. This is the only path by which Examples are reachable
    # from above (they are deliberately excluded from cybed:hasElement
    # traversals so role-level "all elements" queries remain restricted to
    # framework-as-specified content).
    if (length(example_iris) > 0) {
      parent[["cybed:hasExample"]] <- purrr::map(
        example_iris,
        \(eid) list(`@id` = eid)
      )
    }

    result_nodes[[length(result_nodes) + 1L]] <- parent
    for (fn in fragment_nodes) {
      result_nodes[[length(result_nodes) + 1L]] <- fn
    }
  }

  list(
    nodes         = result_nodes,
    subnode_index = if (length(index_rows) > 0) {
      dplyr::bind_rows(index_rows)
    } else {
      tibble::tibble(
        parent_id  = character(0),
        subnode_id = character(0),
        ordinal    = integer(0),
        node_type  = character(0)
      )
    }
  )
}

#' Append Subpoint IDs to a role's child-element id list
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Helper for the assembly pipeline. Given a vector of parent element IDs
#' (the role's children before sub-point expansion) and a sub-node index
#' from [expand_with_subpoints()], returns the original IDs plus all
#' Subpoint IDs whose parent is in the input vector. Preserves order:
#' parents first, Subpoints second. De-duplicates.
#'
#' Example IDs are deliberately excluded. `cybed:Example` instances are
#' reachable via the parent element's `cybed:hasExample` predicate rather
#' than via the role's `cybed:hasElement` collection; including them here
#' would route teacher-facing pedagogical scaffolding into role-level
#' "all elements" traversals where it does not belong.
#'
#' @param parent_element_ids Character vector of parent element IDs.
#' @param subnode_index A tibble with columns `parent_id`, `subnode_id`,
#'   `ordinal`, `node_type` (typically the `subnode_index` field returned
#'   by [expand_with_subpoints()]).
#' @return Character vector of parent IDs plus matching Subpoint IDs.
#' @family Sub-point parsing
#' @export
extend_role_element_ids <- function(parent_element_ids, subnode_index) {
  if (length(parent_element_ids) == 0 || nrow(subnode_index) == 0) {
    return(unique(parent_element_ids))
  }
  # Restrict to Subpoint rows. Examples are reached only via the parent
  # element's cybed:hasExample predicate.
  subpoint_rows <- subnode_index[
    subnode_index$node_type == "Subpoint" &
      subnode_index$parent_id %in% parent_element_ids, ,
    drop = FALSE
  ]
  unique(c(parent_element_ids, subpoint_rows$subnode_id))
}

#' Construct a `cybed:RoleElement` node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' A role element is one atomic statement attached to a role: a task, a
#' knowledge statement, a skill statement, a competence description, etc.
#' Framework-specific element types become subclasses of `cybed:RoleElement`.
#'
#' @param element_id Character, framework-local identifier.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_element_type Character, specific subclass name within the
#'   framework vocabulary (e.g., `"TaskStatement"`, `"KnowledgeStatement"`,
#'   `"SkillStatement"`, `"Competence"`).
#' @param element_text Character, full statement text.
#' @param source_section Character, where this element appears in the source.
#' @param framework_id Character, framework identifier to populate
#'   `cybed:partOf`.
#' @param source_category Character, the source framework's own per-element
#'   provenance tag, when the publisher labels which upstream body a
#'   statement was drawn from (e.g., DCWF's Master Task & KSA List tags
#'   each row `"NICE"`, `"JCT-T"`, `"JCT-KSA"`, `"Other-T"`, or
#'   `"Other-KSA"`). This is a categorical tag as published, not a link to
#'   a specific element in the named framework -- the source data does not
#'   carry that level of precision. Distinct from `source_section`, which
#'   locates content within the SAME document rather than attributing it to
#'   a different one. 2026-08-14: added after a DCWF-vs-NICE alignment
#'   query returned an implausibly weak result and traced to this
#'   provenance column being dropped at ingest.
#' @return Named list (JSON-LD node).
#' @family JSON-LD construction
#' @export
#' @examples
#' el <- build_role_element_node(
#'   element_id             = "T0001",
#'   framework_prefix       = "nice",
#'   framework_element_type = "TaskStatement",
#'   element_text           = "Acquire and manage the necessary resources.",
#'   framework_id           = "nice-v2"
#' )
#' el[["cybed:elementText"]]
#' el[["cybed:partOf"]]
build_role_element_node <- function(element_id,
                                    framework_prefix,
                                    framework_element_type,
                                    element_text,
                                    source_section = NA_character_,
                                    framework_id = NA_character_,
                                    source_category = NA_character_) {
  node <- list(
    `@id`               = glue::glue("{framework_prefix}:{element_id}"),
    `@type`             = c(glue::glue("{framework_prefix}:{framework_element_type}"),
                            "cybed:RoleElement"),
    `cybed:elementText`  = element_text
  )

  if (!is.na(source_section)) {
    node[["cybed:sourceSection"]] <- source_section
  }

  if (!is.na(framework_id)) {
    node[["cybed:partOf"]] <- list(`@id` = glue::glue("cybed:framework/{framework_id}"))
  }

  if (!is.na(source_category)) {
    node[["cybed:sourceCategory"]] <- source_category
  }

  node
}

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

#' Validate a JSON-LD node's minimum required structure
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Checks presence of `@context` (when top-level), `@id`, `@type`. Does NOT
#' perform full JSON-LD 1.1 compliance checking. Use an external validator
#' for that.
#'
#' @param jsonld_node A named list representing a JSON-LD node.
#' @param require_context Logical, `TRUE` if this is a top-level document.
#' @return A named list with elements `valid` (logical) and `missing_fields`
#'   (character vector).
#' @family Validation
#' @export
#' @examples
#' good <- list(`@id` = "x", `@type` = "Y")
#' validate_jsonld_node(good)
#'
#' bad <- list(`@id` = "x")
#' validate_jsonld_node(bad)
validate_jsonld_node <- function(jsonld_node, require_context = FALSE) {
  required <- c("@id", "@type")
  if (require_context) required <- c("@context", required)

  present <- names(jsonld_node)
  missing_fields <- setdiff(required, present)

  list(
    valid          = length(missing_fields) == 0,
    missing_fields = missing_fields
  )
}

# ---------------------------------------------------------------------------
# File I/O
# ---------------------------------------------------------------------------

#' Write a JSON-LD document to file
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Writes a JSON-LD document with pretty-printing and `auto_unbox = TRUE`,
#' the convention used throughout the cybedtools pipeline. Creates the
#' parent directory if it does not exist.
#'
#' @param jsonld_document A named list with `@context` and `@graph` (or a
#'   single node with `@context` and `@id`).
#' @param file_path Character path.
#' @return Invisibly returns `file_path`.
#' @family File I/O
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".jsonld")
#' doc <- list(
#'   `@context` = build_jsonld_context("nice"),
#'   `@graph`   = list(build_framework_node(
#'     framework_id     = "nice-v2",
#'     framework_name   = "NICE",
#'     framework_prefix = "nice",
#'     version          = "2.0.0",
#'     publisher        = "NIST",
#'     jurisdiction     = "US",
#'     sector           = "civilian",
#'     specificity      = "cybersecurity-specific"
#'   ))
#' )
#' write_jsonld_document(doc, tmp)
#' file.exists(tmp)
#' unlink(tmp)
write_jsonld_document <- function(jsonld_document, file_path) {
  if (!dir.exists(dirname(file_path))) {
    dir.create(dirname(file_path), recursive = TRUE)
  }

  jsonlite::write_json(
    jsonld_document,
    path      = file_path,
    pretty    = TRUE,
    auto_unbox = TRUE
  )

  message("JSON-LD written: ", file_path)
  invisible(file_path)
}

#' Read a JSON-LD document from file
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Reads a JSON-LD document via [jsonlite::fromJSON()] without simplifying
#' nested vectors. Preserves the JSON-LD list-of-objects structure.
#'
#' @param file_path Character path.
#' @return Named list.
#' @family File I/O
#' @export
#' @examples
#' tmp <- tempfile(fileext = ".jsonld")
#' write_jsonld_document(
#'   list(`@context` = build_jsonld_context("nice"), `@graph` = list()),
#'   tmp
#' )
#' read_jsonld_document(tmp)
#' unlink(tmp)
read_jsonld_document <- function(file_path) {
  if (!file.exists(file_path)) {
    rlang::abort(
      c(
        "JSON-LD file not found.",
        "x" = paste0("Path: ", file_path, "."),
        "i" = "Check the working directory or pass an absolute path."
      ),
      class = "cybedtools_file_not_found"
    )
  }
  jsonlite::fromJSON(file_path, simplifyVector = FALSE)
}

#' Assemble a framework-level `@graph` document
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Convenience constructor that wraps the supplied framework, role, and
#' element nodes into a single top-level JSON-LD document with the
#' appropriate `@context`.
#'
#' @param framework_node Named list produced by [build_framework_node()].
#' @param role_nodes List of named lists produced by [build_role_node()].
#' @param element_nodes List of named lists produced by
#'   [build_role_element_node()].
#' @param framework_prefix Character, the Tier 2 prefix.
#' @param relation_nodes List of named lists produced by
#'   [build_unit_relation_node()]. Optional: frameworks that publish no
#'   qualified unit-to-unit statements pass nothing and the `@graph` is
#'   unchanged.
#' @return Top-level JSON-LD document with `@context` and `@graph`.
#' @family JSON-LD construction
#' @export
#' @examples
#' fw <- build_framework_node(
#'   framework_id     = "nice-v2",
#'   framework_name   = "NICE",
#'   framework_prefix = "nice",
#'   version          = "2.0.0",
#'   publisher        = "NIST",
#'   jurisdiction     = "US",
#'   sector           = "civilian",
#'   specificity      = "cybersecurity-specific"
#' )
#' role <- build_role_node(
#'   role_id              = "OG-WRL-015",
#'   role_name            = "Cybersecurity Architecture",
#'   framework_prefix     = "nice",
#'   framework_role_type  = "WorkRole",
#'   framework_id         = "nice-v2"
#' )
#' doc <- assemble_framework_document(fw, list(role), list(), "nice")
#' names(doc)
assemble_framework_document <- function(framework_node,
                                        role_nodes,
                                        element_nodes,
                                        framework_prefix,
                                        relation_nodes = list()) {
  list(
    `@context` = build_jsonld_context(framework_prefix),
    `@graph`   = c(list(framework_node), role_nodes, element_nodes,
                   relation_nodes)
  )
}
