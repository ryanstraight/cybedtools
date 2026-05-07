# JSON-LD Helpers, Framework-Agnostic `cybed:` Layer
#
# Utilities for generating JSON-LD semantic web representations of
# cybersecurity workforce competency frameworks and learning-standards
# frameworks across jurisdictions and structural types (role-first,
# competence-first, skill-first, learning-standards).
#
# Two-tier namespace architecture (see the namespace-architecture article):
#   Tier 1: `cybed:` (framework-agnostic base vocabulary)
#   Tier 2: per-framework prefixes (nice, dcwf, ecf, sfia, ecsf, cyberorg,
#           csta, csec, digcomp), each defining subclasses of Tier 1 types

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
  digcomp   = "https://ec.europa.eu/jrc/digcomp/terms#"
)

# Valid framework prefixes (Tier 2). Workforce + pedagogical.
valid_framework_prefixes <- c(
  # Workforce competency frameworks
  "nice", "dcwf", "ecf", "sfia", "ecsf",
  # Pedagogical learning-standards / curriculum frameworks
  "cyberorg", "csta", "csec", "digcomp"
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
#'   Workforce: `"nice"`, `"dcwf"`, `"ecf"`, `"sfia"`, `"ecsf"`.
#'   Pedagogical: `"cyberorg"`, `"csta"`, `"csec"`, `"digcomp"`.
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
#' @param jurisdiction Character, one of `"US"`, `"EU"`, `"UK"`, `"global"`.
#' @param sector Character, one of `"civilian"`, `"defense"`, `"general"`.
#' @param specificity Character, one of `"general-IT"`,
#'   `"cybersecurity-specific"`.
#' @param license Character, license URI or SPDX identifier.
#' @param date_published Character, ISO-8601 date.
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
                                 date_published = NA_character_) {
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

  node
}

# ---------------------------------------------------------------------------
# Tier 2: Role construction (per-framework subclasses)
# ---------------------------------------------------------------------------

#' Construct a `cybed:Role` node
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' A "role" in the cybed sense is the top-level organizing unit the framework
#' uses. For role-first frameworks (NICE, DCWF, ECSF) it is a work role or
#' role profile. For competence-first frameworks (e-CF) it is a competence-at-
#' proficiency-level. For skill-first frameworks (SFIA) it is a skill-at-
#' responsibility-level.
#'
#' @param role_id Character, framework-local identifier (e.g., `"OG-WRL-015"`).
#' @param role_name Character, human-readable name.
#' @param framework_prefix Character, Tier 2 prefix.
#' @param framework_role_type Character, specific subclass name within the
#'   framework vocabulary (e.g., `"WorkRole"`, `"RoleProfile"`,
#'   `"Competence"`).
#' @param description Character, role description text.
#' @param element_ids Character vector of role-element identifiers to link.
#' @param framework_id Character, framework identifier (e.g., `"nice-v2"`) to
#'   populate `cybed:partOf`. Enables SPARQL queries that traverse role to
#'   framework. Recommended. Defaults to `NA` for backward compatibility.
#' @param metadata Named list, optional additional fields to include.
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
#' role[["@id"]]
#' role[["cybed:partOf"]]
build_role_node <- function(role_id,
                            role_name,
                            framework_prefix,
                            framework_role_type,
                            description = NA_character_,
                            element_ids = character(0),
                            framework_id = NA_character_,
                            metadata = list()) {
  node <- list(
    `@id`            = glue::glue("{framework_prefix}:{role_id}"),
    `@type`          = c(glue::glue("{framework_prefix}:{framework_role_type}"),
                         "cybed:Role"),
    `schema:name`    = role_name
  )

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

# ---------------------------------------------------------------------------
# Tier 2: Role element construction
# ---------------------------------------------------------------------------

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
                                    framework_id = NA_character_) {
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
                                        framework_prefix) {
  list(
    `@context` = build_jsonld_context(framework_prefix),
    `@graph`   = c(list(framework_node), role_nodes, element_nodes)
  )
}

# Backward-compatible stub marker so scripts/000-build.R's existence check passes.
.jsonld_helpers_stub <- function() {
  message("jsonld-helpers.R is loaded. Framework-agnostic cybed: layer active.")
  invisible(NULL)
}
