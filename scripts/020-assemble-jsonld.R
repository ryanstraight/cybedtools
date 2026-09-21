# 020-assemble-jsonld.R
#
# Assemble framework-level JSON-LD documents from the tidy CSV staging
# produced by scripts/010-ingest-*.R scripts. Uses the cybed: two-tier
# namespace architecture defined in R/jsonld-helpers.R.
#
# Per-framework adapters translate each framework's native structure into
# the cybed:OrganizingUnit / cybed:RoleElement abstractions. Workforce
# frameworks where the unit is genuinely a work role or work profile
# (NICE, DCWF, CyQUAL and CCSSF work roles, ENISA ECSF profiles, OTCCF job
# roles) additionally assert cybed:Role via build_role_node(). Frameworks
# that relate one unit to another (OTCCF's roles to the skills they
# require) also return cybed:UnitRelation nodes. Non-workforce frameworks
# (SFIA enumerates skills; Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2
# enumerate other organizing units) call build_organizing_unit_node()
# directly with is_role = FALSE.
#
# Per-framework subtype mapping:
#   nice:WorkRole, dcwf:WorkRole, ecsf:RoleProfile,
#   cyqual:WorkRole, ccssf:WorkRole, ccssf:AdjacentRole,
#   otccf:JobRole                                      -> subClassOf cybed:Role
#   sfia:Skill, csec:KnowledgeArea, digcomp:CompetenceArea,
#   cyberorg:StandardGroup, csta:StandardGroup,
#   csta2026:StandardGroup,
#   nice:CompetencyArea, cyqual:Competency,
#   otccf:TechnicalSkillCompetency,
#   otccf:CriticalCoreSkill                            -> subClassOf cybed:OrganizingUnit
#
# Output: data/processed/jsonld/<framework>.jsonld per framework + a
# combined multi-framework graph at data/processed/jsonld/_combined.jsonld.
#
# Run: Rscript scripts/020-assemble-jsonld.R

suppressPackageStartupMessages({
  library(here)
  library(readr)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(yaml)
  library(jsonlite)
  library(glue)
  library(stringr)
})

# Load helpers from the in-tree package source when running from a working
# tree, otherwise fall back to the installed cybedtools.
if (requireNamespace("pkgload", quietly = TRUE) && file.exists(here("DESCRIPTION"))) {
  pkgload::load_all(here(), quiet = TRUE)
} else {
  library(cybedtools)
}

# The csta-2026 adapter lives in its own file so the test suite can drive it
# with a synthetic fixture.
source(here("scripts", "_assemble-csta2026.R"), local = TRUE)

assembly_config <- list(
  raw_dir         = here("data", "raw"),
  output_dir      = here("data", "processed", "jsonld"),
  invariants_path = here("docs", "framework-invariants.yml")
)

# ---------------------------------------------------------------------------
# Unit IRI discriminators
# ---------------------------------------------------------------------------

# Most frameworks number their organizing units and their statements out of
# separate id spaces, so a bare local id is enough to keep a unit IRI and a
# statement IRI apart. Two do not. DCWF draws work-role codes and task/KSA
# numbers from one numeric range, and Cyber.org K-12 names a grade-band cell
# after the standard it holds. For those, docs/framework-invariants.yml
# declares a unit_iri_prefix, the assembler mints unit IRIs with it, and the
# unit's printed code is carried as a schema:identifier literal instead of
# only in the IRI. A framework that declares nothing keeps the IRIs it has
# always had.
framework_invariants <- read_yaml(assembly_config$invariants_path)

unit_iri_prefix_for <- function(framework_slug) {
  entry <- framework_invariants$frameworks[[framework_slug]]
  if (is.null(entry) || is.null(entry$unit_iri_prefix)) {
    return(NULL)
  }
  as.character(entry$unit_iri_prefix)
}

# ---------------------------------------------------------------------------
# Provenance loader
# ---------------------------------------------------------------------------

load_framework_provenance <- function(framework_slug) {
  manifest_path <- file.path(assembly_config$raw_dir, framework_slug, "provenance.yml")
  if (!file.exists(manifest_path)) {
    stop("Provenance manifest missing for ", framework_slug)
  }
  read_yaml(manifest_path)
}

read_framework_table <- function(framework_slug, table_name) {
  path <- file.path(assembly_config$raw_dir, framework_slug, "tables",
                    paste0(table_name, ".csv"))
  if (!file.exists(path)) {
    stop("Table missing: ", path)
  }
  read_csv(path, show_col_types = FALSE)
}

# ---------------------------------------------------------------------------
# Per-framework adapters
# ---------------------------------------------------------------------------

assemble_nice <- function() {
  prov <- load_framework_provenance("nice")
  work_roles  <- read_framework_table("nice", "work-roles")
  assocs      <- read_framework_table("nice", "role-tks-associations")
  tasks       <- read_framework_table("nice", "tasks")
  knowledge   <- read_framework_table("nice", "knowledge")
  skills      <- read_framework_table("nice", "skills")
  # v2.2.0 additions: competency areas with K/S membership, and Federal-use
  # OPM occupational-series codes per work role.
  comp_areas  <- read_framework_table("nice", "competency-areas")
  ca_ks       <- read_framework_table("nice", "competency-area-ks-associations")
  role_opm    <- read_framework_table("nice", "role-opm-codes")

  framework_node <- build_framework_node(
    framework_id     = "nice-v2",
    framework_name   = prov$framework_version,
    framework_prefix = "nice",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "US",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$framework_date
  )

  # Iterate the source TKS tables directly so orphan statements (TKS that
  # exist in NIST's catalog but are not yet bound to a work role in the
  # associations table) are still represented in the graph. Iterating the
  # associations table alone drops orphans silently.
  all_elements <- dplyr::bind_rows(tasks, knowledge, skills) |>
    dplyr::distinct(element_id, element_type, text)

  parent_element_nodes <- all_elements |>
    purrr::pmap(function(element_id, element_type, text, ...) {
      subclass <- switch(element_type,
        task      = "TaskStatement",
        knowledge = "KnowledgeStatement",
        skill     = "SkillStatement",
        "RoleElement"
      )
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "nice",
        framework_element_type = subclass,
        element_text           = text,
        framework_id           = "nice-v2"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "nice",
    framework_id     = "nice-v2",
    framework_slug   = "nice"
  )

  role_nodes <- work_roles |>
    purrr::pmap(function(element_id, title, text, ...) {
      child_ids <- assocs |>
        filter(work_role_id == element_id) |>
        pull(statement_id)

      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      # Federal-use OPM occupational-series codes (v2.2.0). Multi-valued
      # literal: DD-WRL-004 carries two codes; three roles carry none.
      role_opm_codes <- role_opm |>
        filter(work_role_id == element_id) |>
        pull(opm_code) |>
        as.character()

      build_role_node(
        role_id              = element_id,
        role_name            = title,
        framework_prefix     = "nice",
        framework_role_type  = "WorkRole",
        description          = text,
        element_ids          = child_ids,
        framework_id         = "nice-v2",
        opm_codes            = role_opm_codes
      )
    })

  # Competency areas (v2.2.0): NICE's second grouping axis over the same
  # K/S catalog. Not work roles, so cybed:OrganizingUnit only (is_role =
  # FALSE), with cybed:hasElement to their member knowledge/skill
  # statements. Reuses the existing predicate set; no new vocabulary.
  comp_area_nodes <- comp_areas |>
    purrr::pmap(function(element_id, title, text, ...) {
      member_ids <- ca_ks |>
        filter(competency_area_id == element_id) |>
        pull(statement_id)

      member_ids <- extend_role_element_ids(member_ids, expanded$subnode_index)

      build_organizing_unit_node(
        unit_id           = element_id,
        unit_name         = title,
        framework_prefix  = "nice",
        framework_subtype = "CompetencyArea",
        is_role           = FALSE,
        description       = text,
        element_ids       = member_ids,
        framework_id      = "nice-v2"
      )
    })

  list(framework = framework_node, roles = c(role_nodes, comp_area_nodes),
       elements = expanded$nodes, prefix = "nice")
}

assemble_sfia <- function() {
  prov          <- load_framework_provenance("sfia")
  skills        <- read_framework_table("sfia", "skill")
  skill_levels  <- read_framework_table("sfia", "skill-level")
  # CyBOK-SFIA mapping (Tier A crosswalk, not full CyBOK ingestion): 104 rows
  # across 21 CyBOK Knowledge Areas, keyed on SFIA skill code. See
  # data/raw/cybok/provenance.yml.
  cybok_sfia    <- read_framework_table("cybok", "cybok-sfia-mapping")

  framework_node <- build_framework_node(
    framework_id     = "sfia-9",
    framework_name   = prov$framework_version,
    framework_prefix = "sfia",
    version          = prov$framework_version,
    publisher        = "SFIA Foundation",
    jurisdiction     = "global",
    sector           = "general",
    specificity      = "general-IT",
    license          = prov$licensing$sfia_text_license,
    date_published   = prov$framework_date
  )

  # Role = Skill. Element = SkillLevel (a skill at a specific level).
  parent_element_nodes <- skill_levels |>
    purrr::pmap(function(code, level, description, ...) {
      level_id <- paste0(code, "-L", level)
      build_role_element_node(
        element_id             = level_id,
        framework_prefix       = "sfia",
        framework_element_type = "SkillLevel",
        element_text           = description,
        source_section         = paste0("SFIA ", code, " Level ", level),
        framework_id           = "sfia-9"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "sfia",
    framework_id     = "sfia-9",
    framework_slug   = "sfia"
  )

  role_nodes <- skills |>
    purrr::pmap(function(code, name, description, guidance_notes, ...) {
      level_ids <- skill_levels |>
        filter(code == !!code) |>
        mutate(level_id = paste0(code, "-L", level)) |>
        pull(level_id)

      level_ids <- extend_role_element_ids(level_ids, expanded$subnode_index)

      skill_cybok_refs <- cybok_sfia |>
        filter(sfia_code == !!code) |>
        mutate(formatted = glue::glue("{ka}: {skill_name} (SFIA levels {levels})")) |>
        pull(formatted)

      skill_metadata <- if (length(skill_cybok_refs) > 0) {
        list(`cybed:cybokCrossReference` = skill_cybok_refs)
      } else {
        list()
      }

      # SFIA enumerates skills, not roles. Assert cybed:OrganizingUnit (via
      # is_role = FALSE) so cross-framework queries reach SFIA skills, while
      # leaving cybed:Role unasserted (SFIA skills are not roles in the
      # workforce-framework sense).
      build_organizing_unit_node(
        unit_id           = code,
        unit_name         = name,
        framework_prefix  = "sfia",
        framework_subtype = "Skill",
        is_role           = FALSE,
        description       = description,
        element_ids       = level_ids,
        framework_id      = "sfia-9",
        metadata          = skill_metadata
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "sfia")
}

assemble_dcwf <- function() {
  prov         <- load_framework_provenance("dcwf")
  roles        <- read_framework_table("dcwf", "dcwf-roles")
  elements     <- read_framework_table("dcwf", "master-task-ksa")
  role_content <- read_framework_table("dcwf", "per-role-content-long")

  # Identify the statement-id column (varies by extraction)
  id_col <- intersect(c("dcwf_number", "dcwf_num"), names(elements))[1]
  if (is.na(id_col)) {
    stop("Could not identify DCWF element id column in master-task-ksa.csv")
  }
  elements <- elements |>
    rename(statement_id = !!sym(id_col))

  # Identify text and type columns. "task_ksa" (janitor::clean_names() of
  # the XLSX's "Task/KSA" header) is the ROW-TYPE label ("Task" or "KSA"),
  # NOT the statement text -- confirmed 2026-08-14 after finding every
  # shipped DCWF elementText was literally the string "Task"/"KSA" since
  # DCWF's original ingestion; the real description column has a blank
  # header cell in the source workbook and lands one position over,
  # positionally named "x5". A name that has already been silently wrong
  # once is not trustworthy going forward, so select by CONTENT instead:
  # the text column is whichever character column (excluding id/type) has
  # the longest median string length, with a hard failure if that median
  # is implausibly short for real statement text -- guards against this
  # exact failure mode recurring silently on a future re-extraction.
  type_col <- intersect(c("task_ksa", "task_or_ksa"), names(elements))[1]
  candidate_cols <- elements |>
    select(where(is.character)) |>
    select(-any_of(c("statement_id", type_col))) |>
    names()
  text_col <- candidate_cols[
    which.max(vapply(candidate_cols,
                     \(cn) median(nchar(elements[[cn]]), na.rm = TRUE),
                     numeric(1)))
  ]
  stopifnot(
    "DCWF text column selection looks wrong (median length too short for real statement text)" =
      median(nchar(elements[[text_col]]), na.rm = TRUE) > 30
  )

  # Source-category column: the source XLSX's Master Task & KSA List sheet
  # tags each row with DoD's own provenance category -- NICE / JCT-T /
  # JCT-KSA / Other-T / Other-KSA -- in a column whose header cell is blank
  # in the publisher's workbook, so janitor::clean_names() assigns it the
  # positional placeholder "x8". Confirmed by direct inspection of the
  # source XLSX (2026-08-14); ~31% of DCWF's task/KSA statements are
  # tagged NICE-derived. Previously read into this function's `...` and
  # silently discarded -- no cross-framework provenance was queryable.
  category_col <- intersect("x8", names(elements))[1]

  framework_node <- build_framework_node(
    framework_id     = "dcwf-v5.1",
    framework_name   = prov$framework_version,
    framework_prefix = "dcwf",
    version          = prov$framework_version,
    publisher        = prov$source$authority,
    jurisdiction     = "US",
    sector           = "defense",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$framework_date
  )

  elements_distinct <- elements |>
    filter(!is.na(statement_id)) |>
    distinct(statement_id, .keep_all = TRUE)

  parent_element_nodes <- elements_distinct |>
    purrr::pmap(function(statement_id, ...) {
      args <- list(...)
      text_val <- args[[text_col]] %||% NA_character_
      if (is.na(text_val) || text_val == "") return(NULL)
      category_val <- if (!is.na(category_col)) {
        args[[category_col]] %||% NA_character_
      } else {
        NA_character_
      }
      if (!is.na(category_val) && category_val %in% c("N/A", "NA")) {
        category_val <- NA_character_
      }
      build_role_element_node(
        element_id             = statement_id,
        framework_prefix       = "dcwf",
        framework_element_type = "TaskOrKSA",
        element_text           = text_val,
        framework_id           = "dcwf-v5.1",
        source_category        = category_val
      )
    }) |>
    compact()

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "dcwf",
    framework_id     = "dcwf-v5.1",
    framework_slug   = "dcwf"
  )

  # Role-to-element associations: each per-role sheet (raw-dumped to
  # per-role-content-long.csv) lists its Task/KSA rows after a "DCWF #,
  # Task/KSA,..." header line, keyed by the same statement id used in
  # master-task-ksa.csv. role_code is prefixed ("IT-411"); dcwf_code in
  # dcwf-roles.csv is the bare number ("411") -- match on the numeric
  # suffix. Previously never parsed; every DCWF role shipped with zero
  # bound elements (element_ids = character(0)), so any full-document
  # analysis over DCWF roles saw only the one-paragraph role definition,
  # never the actual task/KSA content.
  role_element_map <- role_content |>
    filter(`...4` %in% c("Task", "KSA"), !is.na(`...3`), `...3` != "NA") |>
    transmute(
      dcwf_code = str_extract(role_code, "\\d+"),
      element_id = `...3`
    ) |>
    filter(element_id %in% elements_distinct$statement_id) |>
    distinct()

  role_nodes <- roles |>
    filter(!is.na(dcwf_code)) |>
    purrr::pmap(function(dcwf_code, work_role, work_role_definition, ...) {
      child_ids <- role_element_map |>
        filter(dcwf_code == !!dcwf_code) |>
        pull(element_id)
      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      build_role_node(
        role_id              = dcwf_code,
        role_name            = work_role,
        framework_prefix     = "dcwf",
        framework_role_type  = "WorkRole",
        description          = work_role_definition,
        element_ids          = child_ids,
        framework_id         = "dcwf-v5.1",
        unit_iri_prefix      = unit_iri_prefix_for("dcwf")
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "dcwf")
}

assemble_ecsf <- function() {
  prov      <- load_framework_provenance("ecsf")
  profiles  <- read_framework_table("ecsf", "profiles")
  elements  <- read_framework_table("ecsf", "profile-elements-long")
  # e-CF 4.0 cross-references: already cleanly staged (profile_id, ecf_code,
  # ecf_competence_name, proficiency_level) but never read by assembly --
  # confirmed 2026-08-14. This is the exact EU cross-framework link the
  # package's own docs describe as "not currently materialized as RDF
  # triples," except the raw crosswalk was already extracted and sitting
  # unused, same failure shape as DCWF's dropped NICE-provenance column.
  ecf_refs  <- read_framework_table("ecsf", "ecf-cross-references")
  # CyBOK-ECSF mapping (Tier A crosswalk, not full CyBOK ingestion): primary
  # CyBOK Knowledge Area per ECSF role, plus the source study's per-role
  # descriptor-coverage percentage. Keyed on ECSF profile title (verbatim
  # match confirmed against profiles.title, including the CISO parenthetical
  # and the comma in "Cyber Legal, Policy & Compliance Officer"). See
  # data/raw/cybok/provenance.yml.
  cybok_ecsf <- read_framework_table("cybok", "cybok-ecsf-mapping")

  framework_node <- build_framework_node(
    framework_id     = "ecsf-v1",
    framework_name   = prov$framework_version,
    framework_prefix = "ecsf",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "EU",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$framework_date
  )

  parent_element_nodes <- elements |>
    purrr::pmap(function(profile_id, element_type, element_index, element_text, ...) {
      element_id <- paste0(profile_id, "-", element_type, "-", element_index)
      subclass <- switch(element_type,
        main_tasks    = "Task",
        key_skills    = "Skill",
        key_knowledge = "Knowledge",
        deliverables  = "Deliverable",
        "RoleElement"
      )
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "ecsf",
        framework_element_type = subclass,
        element_text           = element_text,
        source_section         = paste(profile_id, element_type),
        framework_id           = "ecsf-v1"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "ecsf",
    framework_id     = "ecsf-v1",
    framework_slug   = "ecsf"
  )

  role_nodes <- profiles |>
    purrr::pmap(function(profile_id, title, mission, ...) {
      child_ids <- elements |>
        filter(profile_id == !!profile_id) |>
        mutate(element_id = paste0(profile_id, "-", element_type, "-", element_index)) |>
        pull(element_id)

      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      profile_ecf_refs <- ecf_refs |>
        filter(profile_id == !!profile_id) |>
        mutate(formatted = glue::glue(
          "{ecf_code} {ecf_competence_name} (proficiency level {proficiency_level})"
        )) |>
        pull(formatted)

      profile_cybok_refs <- cybok_ecsf |>
        filter(ecsf_role == !!title) |>
        mutate(formatted = ifelse(
          primary_ka == "N/A",
          glue::glue("No primary CyBOK Knowledge Area identified (CyBOK-ECSF descriptor coverage {coverage_pct}%)"),
          glue::glue("{primary_ka} (CyBOK-ECSF descriptor coverage {coverage_pct}%)")
        )) |>
        pull(formatted)

      role_metadata <- c(
        if (length(profile_ecf_refs) > 0) list(`cybed:ecfCrossReference` = profile_ecf_refs) else list(),
        if (length(profile_cybok_refs) > 0) list(`cybed:cybokCrossReference` = profile_cybok_refs) else list()
      )

      build_role_node(
        role_id              = profile_id,
        role_name            = title,
        framework_prefix     = "ecsf",
        framework_role_type  = "RoleProfile",
        description          = mission,
        element_ids          = child_ids,
        framework_id         = "ecsf-v1",
        metadata             = role_metadata
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "ecsf")
}

assemble_cyberorg <- function() {
  prov      <- load_framework_provenance("cyberorg-k12")
  standards <- read_framework_table("cyberorg-k12", "standards")
  subcons   <- read_framework_table("cyberorg-k12", "sub-concepts")

  framework_node <- build_framework_node(
    framework_id     = "cyberorg-k12-v1.0",
    framework_name   = prov$framework_version,
    framework_prefix = "cyberorg",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "US",
    sector           = "K-12-education",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$version_date
  )

  # Role = grade_band x sub_concept cell (pedagogical "organizing unit").
  # Element = individual standard statement.
  cells <- standards |>
    distinct(grade_band, theme, sub_concept) |>
    mutate(cell_id = paste(grade_band, theme, sub_concept, sep = "."))

  parent_element_nodes <- standards |>
    purrr::pmap(function(standard_id, grade_band, theme, sub_concept, sequence,
                         statement_text, ...) {
      build_role_element_node(
        element_id             = standard_id,
        framework_prefix       = "cyberorg",
        framework_element_type = "Standard",
        element_text           = statement_text,
        source_section         = paste(grade_band, theme, sub_concept, sep = "."),
        framework_id           = "cyberorg-k12-v1.0"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "cyberorg",
    framework_id     = "cyberorg-k12-v1.0",
    framework_slug   = "cyberorg-k12"
  )

  role_nodes <- cells |>
    purrr::pmap(function(grade_band, theme, sub_concept, cell_id, ...) {
      child_standards <- standards |>
        filter(grade_band == !!grade_band,
               theme      == !!theme,
               sub_concept == !!sub_concept) |>
        pull(standard_id)

      child_standards <- extend_role_element_ids(child_standards, expanded$subnode_index)

      sc_name <- subcons |>
        filter(theme == !!theme, sub_concept == !!sub_concept) |>
        pull(sub_concept_name) |> first()

      # Cyber.org K-12's organizing unit is the (grade band, theme,
      # sub-concept) cell that groups numbered standards within the
      # framework's structural axes. Cyber.org's published documentation
      # does not name the cell, so cybedtools labels it cyberorg:StandardGroup
      # (descriptive, framework-neutral) rather than coining a pedagogy
      # term the framework did not originate. Assert cybed:OrganizingUnit
      # only; cybed:Role is reserved for frameworks that genuinely
      # enumerate work roles or work profiles.
      build_organizing_unit_node(
        unit_id           = cell_id,
        unit_name         = paste(grade_band, theme, sc_name %||% sub_concept, sep = " / "),
        framework_prefix  = "cyberorg",
        framework_subtype = "StandardGroup",
        is_role           = FALSE,
        description       = paste("Grade-band x sub-concept group of standards for", grade_band, "students on", sc_name %||% sub_concept),
        element_ids       = child_standards,
        framework_id      = "cyberorg-k12-v1.0",
        unit_iri_prefix   = unit_iri_prefix_for("cyberorg-k12")
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "cyberorg")
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

assemble_csta <- function() {
  prov      <- load_framework_provenance("csta")
  standards <- read_framework_table("csta", "standards")

  framework_node <- build_framework_node(
    framework_id     = "csta-2017",
    framework_name   = prov$framework_version,
    framework_prefix = "csta",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "US",
    sector           = "K-12-education",
    specificity      = "general-computing",
    license          = prov$licensing$source_license,
    date_published   = prov$version_date
  )

  # Role = Level × Concept cluster. Element = individual standard.
  clusters <- standards |>
    distinct(level, concept) |>
    mutate(cluster_id = paste(level, str_replace_all(concept, "[^A-Za-z]+", ""), sep = "-"))

  parent_element_nodes <- standards |>
    purrr::pmap(function(identifier, level, concept, standard, ...) {
      build_role_element_node(
        element_id             = identifier,
        framework_prefix       = "csta",
        framework_element_type = "Standard",
        element_text           = standard,
        source_section         = paste(level, concept, sep = "."),
        framework_id           = "csta-2017"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "csta",
    framework_id     = "csta-2017",
    framework_slug   = "csta"
  )

  # CSTA-specific Example extraction. CSTA stores its clarification
  # content in a separate `clarification` column rather than appending it
  # to the standard text under a "Clarification statement:" header (the
  # Cyber.org K-12 convention). The clarification content is
  # pedagogical scaffolding describing teacher level-of-rigor
  # expectations: structurally equivalent to Cyber.org K-12's
  # Clarifications and so emitted as cybed:Example nodes (one per
  # non-empty clarification) with cybed:hasExample links from the parent
  # standard. The Examples carry no framework-native subtype and are
  # excluded from default cybed:hasElement traversals, matching the
  # Cyber.org K-12 treatment.
  example_nodes <- list()
  parent_examples <- list()  # named list: parent_id -> character vector of example IRIs
  for (i in seq_len(nrow(standards))) {
    std <- standards[i, ]
    clar <- std$clarification
    if (is.null(clar) || is.na(clar) || nchar(trimws(clar)) == 0) next

    ex <- build_example_node(
      parent_element_id = std$identifier,
      ordinal           = 1L,
      text              = trimws(clar),
      framework_prefix  = "csta",
      framework_id      = "csta-2017"
    )
    example_nodes[[length(example_nodes) + 1L]] <- ex

    parent_iri <- paste0("csta:", std$identifier)
    parent_examples[[parent_iri]] <- as.character(ex[["@id"]])
  }

  # Mutate each parent in expanded$nodes to carry cybed:hasExample for
  # its clarification-derived Example. expand_with_subpoints already
  # handles cybed:hasExample for Example-style routing in the
  # inline-Clarification-statement path (Cyber.org K-12 convention), but
  # CSTA's Examples come from the column-extraction path above and are
  # not visible to that orchestrator.
  if (length(parent_examples) > 0) {
    expanded$nodes <- lapply(expanded$nodes, function(node) {
      iri <- as.character(node[["@id"]])
      if (!is.null(parent_examples[[iri]])) {
        existing <- node[["cybed:hasExample"]]
        new_link <- list(`@id` = parent_examples[[iri]])
        node[["cybed:hasExample"]] <- c(existing %||% list(), list(new_link))
      }
      node
    })
  }

  all_element_nodes <- c(expanded$nodes, example_nodes)

  role_nodes <- clusters |>
    purrr::pmap(function(level, concept, cluster_id, ...) {
      child_standards <- standards |>
        filter(level == !!level, concept == !!concept) |>
        pull(identifier)

      child_standards <- extend_role_element_ids(child_standards, expanded$subnode_index)

      # CSTA's organizing unit is the (level, concept) cell that groups
      # standards (e.g., "Level 3A / Impacts of Computing"). CSTA's
      # published terminology uses level / concept / subconcept / practice
      # but does not name the cell itself, so cybedtools labels it
      # csta:StandardGroup (descriptive, framework-neutral). Assert
      # cybed:OrganizingUnit only; cybed:Role is reserved for workforce
      # frameworks.
      build_organizing_unit_node(
        unit_id           = cluster_id,
        unit_name         = paste(level, concept, sep = " / "),
        framework_prefix  = "csta",
        framework_subtype = "StandardGroup",
        is_role           = FALSE,
        description       = paste("Level", level, "-", concept),
        element_ids       = child_standards,
        framework_id      = "csta-2017"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = all_element_nodes,
       prefix = "csta")
}

# The 2026 CSTA PK-12 standards: a separate framework from csta-2017, with
# its own prefix and identifier scheme. The mapping is documented in
# scripts/_assemble-csta2026.R.
assemble_csta2026 <- function() {
  build_csta2026_parts(
    standards       = read_framework_table("csta-2026", "standards"),
    boundaries      = read_framework_table("csta-2026", "boundaries"),
    examples        = read_framework_table("csta-2026", "examples"),
    units           = read_framework_table("csta-2026", "units"),
    prov            = load_framework_provenance("csta-2026"),
    unit_iri_prefix = unit_iri_prefix_for("csta-2026")
  )
}

assemble_csec2017 <- function() {
  prov       <- load_framework_provenance("csec2017")
  kas        <- read_framework_table("csec2017", "knowledge-areas")
  essentials <- read_framework_table("csec2017", "essentials")

  framework_node <- build_framework_node(
    framework_id     = "csec2017-v1",
    framework_name   = prov$framework_version,
    framework_prefix = "csec",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "global",
    sector           = "higher-education",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$version_date
  )

  parent_element_nodes <- essentials |>
    purrr::pmap(function(element_id, ka_id, element_type, element_text, ...) {
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "csec",
        framework_element_type = "Essential",
        element_text           = element_text,
        source_section         = ka_id,
        framework_id           = "csec2017-v1"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "csec",
    framework_id     = "csec2017-v1",
    framework_slug   = "csec2017"
  )

  role_nodes <- kas |>
    purrr::pmap(function(ka_id, section, name, short_name, ...) {
      child_essentials <- essentials |>
        filter(ka_id == !!ka_id) |>
        pull(element_id)

      child_essentials <- extend_role_element_ids(child_essentials, expanded$subnode_index)

      # CSEC2017's 8 Knowledge Areas are thought-model groupings for
      # cybersecurity curricular design, not roles. CSEC2017 itself does
      # not specify roles. Assert cybed:OrganizingUnit only.
      build_organizing_unit_node(
        unit_id           = ka_id,
        unit_name         = name,
        framework_prefix  = "csec",
        framework_subtype = "KnowledgeArea",
        is_role           = FALSE,
        description       = paste("CSEC2017", section, name),
        element_ids       = child_essentials,
        framework_id      = "csec2017-v1"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "csec")
}

assemble_digcomp <- function() {
  prov        <- load_framework_provenance("digcomp")
  areas       <- read_framework_table("digcomp", "competence-areas")
  competences <- read_framework_table("digcomp", "competences")
  descs       <- read_framework_table("digcomp", "competence-descriptions")

  framework_node <- build_framework_node(
    framework_id     = "digcomp-2.2",
    framework_name   = prov$framework_version,
    framework_prefix = "digcomp",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "EU",
    sector           = "citizen-education",
    specificity      = "general-digital-competence",
    license          = prov$licensing$source_license,
    date_published   = prov$version_date
  )

  # Role = Competence Area. Element = Competence.
  parent_element_nodes <- descs |>
    purrr::pmap(function(element_id, competence_id, competence_name, description, ...) {
      text_val <- if (!is.na(description) && description != "") description else competence_name
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "digcomp",
        framework_element_type = "Competence",
        element_text           = text_val,
        source_section         = paste0("DigComp ", competence_id, " ", competence_name),
        framework_id           = "digcomp-2.2"
      )
    })

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "digcomp",
    framework_id     = "digcomp-2.2",
    framework_slug   = "digcomp"
  )

  role_nodes <- areas |>
    purrr::pmap(function(area_id, area_number, area_name, ...) {
      child_competence_ids <- competences |>
        filter(area_id == !!area_id) |>
        mutate(element_id = paste0("COMP-", competence_id)) |>
        pull(element_id)

      child_competence_ids <- extend_role_element_ids(child_competence_ids, expanded$subnode_index)

      # DigComp 2.2 organizes content by competence area (5 areas: Information
      # and data literacy, Communication and collaboration, Digital content
      # creation, Safety, Problem solving). DigComp does not specify roles;
      # it is a citizen self-assessment instrument. Assert
      # cybed:OrganizingUnit only.
      build_organizing_unit_node(
        unit_id           = area_id,
        unit_name         = area_name,
        framework_prefix  = "digcomp",
        framework_subtype = "CompetenceArea",
        is_role           = FALSE,
        description       = paste("DigComp 2.2 Area", area_number, "-", area_name),
        element_ids       = child_competence_ids,
        framework_id      = "digcomp-2.2"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "digcomp")
}

assemble_cyqual <- function() {
  prov          <- load_framework_provenance("cyqual")
  work_roles    <- read_framework_table("cyqual", "work-roles")
  tasks         <- read_framework_table("cyqual", "tasks")
  requirements  <- read_framework_table("cyqual", "requirements")
  competencies  <- read_framework_table("cyqual", "competencies")
  comp_groups   <- read_framework_table("cyqual", "competency-groups")
  spec_areas    <- read_framework_table("cyqual", "specialization-areas")
  categories    <- read_framework_table("cyqual", "categories")
  wr_tasks      <- read_framework_table("cyqual", "work-role-tasks")
  wr_reqs       <- read_framework_table("cyqual", "work-role-requirements")

  # The steward requires this attribution verbatim, and the staged text is
  # Czech unless an English export has been ingested, so the language tag
  # comes from provenance rather than being assumed.
  framework_node <- build_framework_node(
    framework_id     = "cyqual-v1.2.0",
    framework_name   = paste("CyQUAL", prov$framework_version),
    framework_prefix = "cyqual",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "CZ",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$retrieval$retrieved_date,
    attribution      = paste(
      "CyQUAL, the Czech national cybersecurity qualifications framework,",
      "developed at Masaryk University. Open data, version 1.2.0,",
      "https://platform.cyqual.cz/"
    ),
    in_language      = if (identical(prov$language, "en")) NA_character_ else prov$language
  )

  # Tasks and requirements are shared across work roles, as NICE TKS
  # statements are, so each is emitted once and roles reference it by id.
  # Iterating the source tables rather than the association tables also keeps
  # the 107 tasks and 50 requirements bound to no role in the graph; they are
  # part of the published framework.
  task_nodes <- tasks |>
    purrr::pmap(function(code, description, ...) {
      build_role_element_node(
        element_id             = code,
        framework_prefix       = "cyqual",
        framework_element_type = "Task",
        element_text           = description,
        framework_id           = "cyqual-v1.2.0"
      )
    })

  requirement_nodes <- requirements |>
    purrr::pmap(function(code, description, ...) {
      build_role_element_node(
        element_id             = code,
        framework_prefix       = "cyqual",
        framework_element_type = "Requirement",
        element_text           = description,
        framework_id           = "cyqual-v1.2.0"
      )
    })

  # Sub-point parser runs on the English export, where parse_subpoints()'s
  # English-only introducer patterns apply. It stays off if the Czech export is
  # the one staged, where those patterns would miss real enumerations and split
  # on false ones. Elements are shared across roles, so subpoints are minted
  # once against the shared parents; each role and competency then extends its
  # own id list from the same index.
  expanded <- if (identical(prov$language, "en")) {
    expand_with_subpoints(
      element_nodes    = c(task_nodes, requirement_nodes),
      framework_prefix = "cyqual",
      framework_id     = "cyqual-v1.2.0",
      framework_slug   = "cyqual"
    )
  } else {
    list(
      nodes         = c(task_nodes, requirement_nodes),
      subnode_index = tibble::tibble(
        parent_id  = character(0),
        subnode_id = character(0),
        ordinal    = integer(0),
        node_type  = character(0)
      )
    )
  }

  # Role location in the published hierarchy (category -> specialization area
  # -> work role), carried as a cybed:sourceSection literal. No new cybed:
  # term is coined for it.
  role_sections <- work_roles |>
    select(code, specializationArea) |>
    left_join(
      spec_areas |> select(sa_code = code, sa_title = title, category),
      by = c("specializationArea" = "sa_code")
    ) |>
    left_join(
      categories |> select(cat_code = code, cat_title = title),
      by = c("category" = "cat_code")
    ) |>
    mutate(section = paste0(category, " ", cat_title, " / ",
                            specializationArea, " ", sa_title))

  role_nodes <- work_roles |>
    purrr::pmap(function(code, title, description, ...) {
      child_ids <- c(
        wr_tasks |> filter(workRole == !!code) |> pull(task),
        wr_reqs  |> filter(workRole == !!code) |> pull(requirement)
      )
      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      section <- role_sections |> filter(code == !!code) |> pull(section)

      build_role_node(
        role_id              = code,
        role_name            = title,
        framework_prefix     = "cyqual",
        framework_role_type  = "WorkRole",
        description          = description,
        element_ids          = child_ids,
        framework_id         = "cyqual-v1.2.0",
        metadata             = list(`cybed:sourceSection` = section)
      )
    })

  # Competencies are CyQUAL's second grouping axis over the requirement
  # catalog, the same shape as NICE v2.2.0 competency areas: not work roles,
  # so cybed:OrganizingUnit only, with cybed:hasElement to their member
  # requirements and the competency group as a cybed:sourceSection literal.
  competency_nodes <- competencies |>
    purrr::pmap(function(code, title, description, competencyGroup, ...) {
      member_ids <- requirements |>
        filter(competency == !!code) |>
        pull(code)
      member_ids <- extend_role_element_ids(member_ids, expanded$subnode_index)

      group_title <- comp_groups |> filter(code == !!competencyGroup) |> pull(title)

      build_organizing_unit_node(
        unit_id           = code,
        unit_name         = title,
        framework_prefix  = "cyqual",
        framework_subtype = "Competency",
        is_role           = FALSE,
        description       = description,
        element_ids       = member_ids,
        framework_id      = "cyqual-v1.2.0",
        metadata          = list(
          `cybed:sourceSection` = paste0(competencyGroup, " ", group_title)
        )
      )
    })

  list(framework = framework_node, roles = c(role_nodes, competency_nodes),
       elements = expanded$nodes, prefix = "cyqual")
}

# The Competencies field of a core role block prints proficiency and scoping
# lead-in lines above the runs they govern, and the ingester kept each one as
# its own row rather than as a heading (see data/raw/ccssf/provenance.yml,
# extraction_limitations). This is the closed set of those lead-ins, taken
# verbatim from the staged text. Rows matching it are not emitted as element
# nodes; their text is carried as cybed:sourceSection on the competency rows
# that follow, which restores the one level of nesting the source printed.
# Colon-terminated rows outside this set (e.g. "Organizational threats and
# vulnerabilities including:") are substantive competency statements and stay
# as elements.
ccssf_competency_headers <- c(
  "Basic application of the following KSAs:",
  "Advanced application of the following KSAs:",
  "Basic level of application of the following KSAs:",
  "Advanced level of application of the following KSAs:",
  "KSAs applied at the basic level:",
  "KSAs applied at an advanced level:",
  "KSAs applied at the advanced level:",
  "The following KSA are applied at a basic level:",
  "The following KSA are applied at an advanced level:",
  "The following KSA are applied at an advanced level. All of the above plus:",
  "In addition to the relevant KSAs above, the follow applied at the basic level:",
  "In addition, in High Assurance, Encryption, and Cryptographic environments:",
  "In addition, within Operational Technology (ICS/OCS/SCADA) environments:",
  paste("The security engineer/engineering technologist requires a basic level of",
        "application of the following KSAs while the security engineer requires an",
        "advanced level of application of the following KSAs:"),
  paste("Appreciating that not all OT analysts will necessarily have an IT",
        "background, the following basic application of the following KSAs are",
        "relevant:"),
  paste("Underpinning this occupation are those competencies demonstrated for an",
        "activity manager as well as the Information Systems Security Manager",
        "within the NICE framework. Specifically, this work requires:")
)

# Staged element_type -> Tier 2 subtype. Only these three of the thirteen
# staged types become element nodes; the rest are role-level attributes.
ccssf_element_subtypes <- c(
  tasks                = "Task",
  competencies         = "Competency",
  tools_and_technology = "ToolOrTechnology"
)

# Pull the NICE work-role title out of the framework's printed reference
# string. The string is comma-separated as "<activity area>, <NICE id>,
# <title>" in some roles and "<activity area>, <title>, <NICE id>" in others,
# so the id segment is dropped by match and the leading activity-area segment
# by position. Roles whose reference is a bare id (all of Annex E) yield no
# label.
ccssf_nice_label <- function(reference_raw, nice_id) {
  vapply(seq_along(reference_raw), function(i) {
    parts <- trimws(strsplit(reference_raw[[i]], ",", fixed = TRUE)[[1]])
    parts <- parts[nzchar(parts)]
    parts <- parts[!grepl(nice_id[[i]], parts, fixed = TRUE)]
    if (length(parts) <= 1) "" else paste(parts[-1], collapse = ", ")
  }, character(1))
}

assemble_ccssf <- function() {
  prov           <- load_framework_provenance("ccssf")
  roles          <- read_framework_table("ccssf", "roles")
  elements       <- read_framework_table("ccssf", "role-elements-long")
  adjacent       <- read_framework_table("ccssf", "adjacent-roles")
  adj_comps      <- read_framework_table("ccssf", "adjacent-role-competencies-long")
  activity_areas <- read_framework_table("ccssf", "activity-areas")
  crosswalk      <- read_framework_table("ccssf", "nice-crosswalk")

  # The Centre asked that ITSM.00.039 be referenced wherever the material is
  # used, so the attribution is recorded verbatim.
  # No landing page is recorded in provenance (the PDF was supplied directly
  # by the steward), so none is cited rather than guessing one.
  version_string <- paste(
    "Canadian Cyber Security Skills Framework 2022",
    "(ITSM.00.039, Revision 1, effective 2023-04-19)"
  )

  framework_node <- build_framework_node(
    framework_id     = "ccssf-2022",
    framework_name   = version_string,
    framework_prefix = "ccssf",
    version          = version_string,
    publisher        = prov$source$publisher,
    jurisdiction     = "CA",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$framework_date,
    attribution      = paste(
      "Canadian Centre for Cyber Security, The Canadian Cyber Security Skills",
      "Framework (ITSM.00.039), 2022 edition. Copyright Government of Canada.",
      "Referenced as the Canadian Centre for Cyber Security asked."
    )
  )

  # Competency rows: drop the lead-in headings and carry each one forward as
  # the source section of the rows it governs, until the next heading.
  competency_rows <- elements |>
    filter(element_type == "competencies") |>
    arrange(role_id, element_index) |>
    mutate(is_header = element_text %in% ccssf_competency_headers) |>
    group_by(role_id) |>
    mutate(source_section = {
      carried <- rep(NA_character_, dplyr::n())
      current <- NA_character_
      for (i in seq_along(carried)) {
        if (is_header[i]) current <- element_text[i] else carried[i] <- current
      }
      carried
    }) |>
    ungroup() |>
    filter(!is_header)

  # Elements are per-role, not shared: the source prints a private list under
  # each role block, so ids are generated per role as ECSF's are.
  core_element_rows <- bind_rows(
    elements |>
      filter(element_type %in% c("tasks", "tools_and_technology")) |>
      mutate(source_section = NA_character_),
    competency_rows |>
      select(role_id, element_type, element_index, element_text, source_section)
  ) |>
    transmute(
      owner_id       = role_id,
      element_id     = paste0(role_id, "-", element_type, "-", element_index),
      subtype        = unname(ccssf_element_subtypes[element_type]),
      element_text   = element_text,
      source_section = source_section
    )

  # Annex E adjacent roles carry key competencies only.
  adjacent_element_rows <- adj_comps |>
    transmute(
      owner_id       = adjacent_role_id,
      element_id     = paste0(adjacent_role_id, "-competencies-", element_index),
      subtype        = "Competency",
      element_text   = competency,
      source_section = NA_character_
    )

  all_element_rows <- bind_rows(core_element_rows, adjacent_element_rows)

  # The source prints some bullets nested under a colon-terminated parent
  # bullet. The ingester recorded that nesting as parent_index. Those rows are
  # the publisher's own sub-bullets, so they become cybed:Subpoint children of
  # their parent rather than sibling top-level elements.
  subbullet_rows <- elements |>
    filter(!is.na(parent_index)) |>
    arrange(role_id, element_type, parent_index, element_index) |>
    transmute(
      owner_id          = role_id,
      parent_element_id = paste0(role_id, "-", element_type, "-", parent_index),
      element_id        = paste0(role_id, "-", element_type, "-", element_index),
      subtype           = unname(ccssf_element_subtypes[element_type]),
      element_text      = element_text
    ) |>
    group_by(parent_element_id) |>
    mutate(ordinal = dplyr::row_number()) |>
    ungroup()

  # Parents that already carry source-printed children are withheld from the
  # sub-point parser: the parser would split the same colon-terminated stem a
  # second time and duplicate what the source already enumerates. Withholding
  # them also keeps the .sub.N ordinal space free, so the source-printed
  # children can use the same id shape without colliding.
  source_parent_ids <- unique(subbullet_rows$parent_element_id)

  parent_element_rows <- all_element_rows |>
    filter(!element_id %in% subbullet_rows$element_id)

  element_node_of <- function(rows) {
    rows |>
      purrr::pmap(function(owner_id, element_id, subtype, element_text,
                           source_section, ...) {
        build_role_element_node(
          element_id             = element_id,
          framework_prefix       = "ccssf",
          framework_element_type = subtype,
          element_text           = element_text,
          source_section         = source_section,
          framework_id           = "ccssf-2022"
        )
      })
  }

  parsed_rows <- parent_element_rows |> filter(!element_id %in% source_parent_ids)
  held_rows   <- parent_element_rows |> filter(element_id %in% source_parent_ids)

  expanded <- expand_with_subpoints(
    element_nodes    = element_node_of(parsed_rows),
    framework_prefix = "ccssf",
    framework_id     = "ccssf-2022",
    framework_slug   = "ccssf"
  )

  # Same constructor and same typing as parser-made sub-points, so both kinds
  # answer the same queries and reach roles through the same index.
  subbullet_nodes <- subbullet_rows |>
    purrr::pmap(function(parent_element_id, ordinal, element_text, subtype, ...) {
      build_subpoint_node(
        parent_element_id = parent_element_id,
        ordinal           = ordinal,
        text              = element_text,
        framework_prefix  = "ccssf",
        framework_id      = "ccssf-2022",
        parent_subtype    = subtype
      )
    })

  expanded$nodes <- c(expanded$nodes, element_node_of(held_rows), subbullet_nodes)
  expanded$subnode_index <- bind_rows(
    expanded$subnode_index,
    subbullet_rows |>
      transmute(
        parent_id  = parent_element_id,
        subnode_id = paste0(parent_element_id, ".sub.", ordinal),
        ordinal    = as.integer(ordinal),
        node_type  = "Subpoint"
      )
  )

  # NICE cross-references are cited at work-role granularity in the
  # framework's own old-style NICE ids, which do not match the NICE v2.2.0
  # ids in this graph. Literals, never links. Roles printing "None" have no
  # id staged and get no triple.
  # The literal carries the normalized id so the citation is usable, and the
  # printed form alongside it wherever the source's own id is malformed, so
  # the typo is not silently corrected away.
  nice_refs <- crosswalk |>
    filter(!is.na(nice_work_role_id_normalized)) |>
    mutate(
      label     = ccssf_nice_label(nice_reference_raw, nice_work_role_id_as_printed),
      cited     = ifelse(nzchar(label),
                         paste0(nice_work_role_id_normalized, " (", label, ")"),
                         nice_work_role_id_normalized),
      formatted = ifelse(id_malformed_in_source %in% TRUE,
                         paste0(cited, " [printed as: ", nice_work_role_id_as_printed, "]"),
                         cited)
    )

  # Activity area as printed, prefixed by the annex letter that carries it.
  area_labels <- activity_areas |>
    mutate(section = paste(annex, activity_area))

  role_nodes <- roles |>
    purrr::pmap(function(role_id, title, grouping, description, ...) {
      child_ids <- parent_element_rows |> filter(owner_id == !!role_id) |> pull(element_id)
      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      section <- area_labels |>
        filter(annex == substr(!!role_id, 1, 1)) |>
        pull(section)

      role_nice <- nice_refs |>
        filter(source_table == "core_role", role_id == !!role_id) |>
        pull(formatted)

      role_metadata <- c(
        list(`cybed:sourceSection` = section),
        if (length(role_nice) > 0) list(`cybed:niceCrossReference` = role_nice) else list()
      )

      # roles.csv$description is the block's Functional description field,
      # staged a second time in role-elements-long for completeness.
      build_role_node(
        role_id              = role_id,
        role_name            = title,
        framework_prefix     = "ccssf",
        framework_role_type  = "WorkRole",
        description          = description,
        element_ids          = child_ids,
        framework_id         = "ccssf-2022",
        metadata             = role_metadata
      )
    })

  # Annex E cyber adjacent roles: roles the framework names as bordering
  # cyber security work without detailing them as core roles. The source
  # gives them no identifier, so the ingester generated slugs from the
  # printed titles.
  adjacent_role_nodes <- adjacent |>
    purrr::pmap(function(adjacent_role_id, title, activity_area, responsibility, ...) {
      child_ids <- adjacent_element_rows |>
        filter(owner_id == !!adjacent_role_id) |>
        pull(element_id)
      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      section <- area_labels |>
        filter(activity_area == !!activity_area) |>
        pull(section)

      role_nice <- nice_refs |>
        filter(source_table == "adjacent_role", role_id == !!adjacent_role_id) |>
        pull(formatted)

      role_metadata <- c(
        list(`cybed:sourceSection` = section),
        if (length(role_nice) > 0) list(`cybed:niceCrossReference` = role_nice) else list()
      )

      build_role_node(
        role_id              = adjacent_role_id,
        role_name            = title,
        framework_prefix     = "ccssf",
        framework_role_type  = "AdjacentRole",
        description          = responsibility,
        element_ids          = child_ids,
        framework_id         = "ccssf-2022",
        metadata             = role_metadata
      )
    })

  list(framework = framework_node, roles = c(role_nodes, adjacent_role_nodes),
       elements = expanded$nodes, prefix = "ccssf")
}

# Staged TSC level-grid section -> Tier 2 subtype. The staged names are the
# source's own row labels in the proficiency grid.
otccf_level_subtypes <- c(
  knowledge         = "Knowledge",
  ability           = "Ability",
  level_description = "ProficiencyDescription"
)

# Slug rule replicated from slugify() in scripts/010-ingest-otccf.R, which is
# not reachable from this script (the ingest scripts are not sourced here).
# The ingester's leading repair_ligatures() step is omitted: it repairs PDF
# extraction artifacts, and the staged titles are already repaired.
otccf_slugify <- function(x) {
  x |>
    str_replace_all("&", " and ") |>
    str_replace_all("[^A-Za-z0-9]+", "-") |>
    str_remove_all("^-+|-+$") |>
    str_to_lower()
}

assemble_otccf <- function() {
  prov        <- load_framework_provenance("otccf")
  roles       <- read_framework_table("otccf", "job-roles")
  role_els    <- read_framework_table("otccf", "role-elements-long")
  role_track  <- read_framework_table("otccf", "role-tracks")
  tscs        <- read_framework_table("otccf", "tscs")
  tsc_levels  <- read_framework_table("otccf", "tsc-levels-long")
  tsc_roa     <- read_framework_table("otccf", "tsc-range-of-application")
  tsc_map     <- read_framework_table("otccf", "role-tsc-map")
  core_skills <- read_framework_table("otccf", "role-critical-core-skills") |>
    mutate(skill_slug = otccf_slugify(skill_name))

  # CSA's permission is conditional on this attribution string being
  # reproduced verbatim, so it is read from the manifest and passed through
  # rather than retyped here. The document is published in English, so no
  # schema:inLanguage is asserted.
  framework_node <- build_framework_node(
    framework_id     = "otccf-v1.1",
    framework_name   = paste("Operational Technology Cybersecurity Competency",
                             "Framework (OTCCF) version 1.1"),
    framework_prefix = "otccf",
    version          = "1.1",
    publisher        = prov$publisher,
    jurisdiction     = "SG",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = "2021-10-08",
    attribution      = prov$licensing$attribution
  )

  # The eight TSCs CSA marks "#Extracted from SkillsFuture ICT Framework" are
  # not CSA original content. Every element beneath them carries the marker as
  # cybed:sourceCategory, which is exactly the publisher's own upstream-body
  # tag that term exists for.
  skillsfuture_slugs <- tscs |> filter(skillsfuture_derived) |> pull(tsc_slug)
  skillsfuture_tag <- "SkillsFuture ICT Framework"
  tag_for <- function(slug) {
    ifelse(slug %in% skillsfuture_slugs, skillsfuture_tag, NA_character_)
  }

  # Critical Work Functions are a merged-cell heading over their key tasks,
  # not a published node type. Carrying the heading verbatim as the task's
  # cybed:sourceSection restores the nesting CSA printed without inventing a
  # unit the framework does not enumerate.
  cwf_titles <- role_els |>
    filter(element_type == "critical_work_function") |>
    select(role_slug, parent = element_index, cwf_text = element_text)

  task_rows <- role_els |>
    filter(element_type == "key_task") |>
    left_join(cwf_titles, by = c("role_slug", "parent_index" = "parent")) |>
    transmute(
      owner_id       = role_slug,
      element_id     = paste0(role_slug, "-task-", element_index),
      subtype        = "KeyTask",
      element_text   = element_text,
      source_section = cwf_text,
      source_category = NA_character_
    )

  level_rows <- tsc_levels |>
    transmute(
      owner_id       = tsc_slug,
      element_id     = paste0(tsc_slug, "-L", proficiency_level, "-",
                              unname(otccf_level_subtypes[element_type]), "-",
                              element_index),
      subtype        = unname(otccf_level_subtypes[element_type]),
      element_text   = element_text,
      source_section = paste("Level", proficiency_level),
      source_category = tag_for(tsc_slug)
    )

  roa_rows <- tsc_roa |>
    transmute(
      owner_id       = tsc_slug,
      element_id     = paste0(tsc_slug, "-roa-", element_index),
      subtype        = "RangeOfApplication",
      element_text   = element_text,
      source_section = "Range of Application",
      source_category = tag_for(tsc_slug)
    )

  all_element_rows <- bind_rows(task_rows, level_rows, roa_rows)

  parent_element_nodes <- all_element_rows |>
    purrr::pmap(function(owner_id, element_id, subtype, element_text,
                         source_section, source_category, ...) {
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "otccf",
        framework_element_type = subtype,
        element_text           = element_text,
        source_section         = source_section,
        framework_id           = "otccf-v1.1",
        source_category        = source_category
      )
    })

  # Sub-point parser disabled for OTCCF, as for CyQUAL: CSA's permission is
  # conditional on not altering the intent of the published statements, and a
  # parser-split fragment of a key task or level statement would be a unit the
  # package invented rather than one CSA published. Shape matches what
  # expand_with_subpoints() returns so the rest of the adapter is unchanged.
  expanded <- list(
    nodes         = parent_element_nodes,
    subnode_index = tibble::tibble(
      parent_id  = character(0),
      subnode_id = character(0),
      ordinal    = integer(0),
      node_type  = character(0)
    )
  )

  # Track membership is many-to-many: a role's Track cell may name two tracks.
  # Each is carried as its own cybed:sourceSection literal, the way ECSF
  # carries multiple cross-references, rather than joined into one string.
  role_nodes <- roles |>
    purrr::pmap(function(role_slug, job_role, role_description, ...) {
      child_ids <- task_rows |> filter(owner_id == !!role_slug) |> pull(element_id)
      child_ids <- extend_role_element_ids(child_ids, expanded$subnode_index)

      sections <- role_track |> filter(role_slug == !!role_slug) |> pull(track_name)

      # Both skills maps point at organizing units, so their targets share one
      # cybed:relatedUnit vector. Emitting the key twice would leave the two
      # maps as separate properties on the same node.
      related_targets <- c(
        tsc_map     |> filter(role_slug == !!role_slug) |> pull(tsc_slug),
        core_skills |> filter(role_slug == !!role_slug) |> pull(skill_slug)
      )

      build_role_node(
        role_id              = role_slug,
        role_name            = job_role,
        framework_prefix     = "otccf",
        framework_role_type  = "JobRole",
        description          = role_description,
        element_ids          = child_ids,
        framework_id         = "otccf-v1.1",
        metadata             = c(
          list(`cybed:sourceSection` = sections),
          build_related_unit_metadata(related_targets, "otccf")
        )
      )
    })

  # The 30 Technical Skills and Competencies are OTCCF's second root: a
  # catalogue CSA publishes in its own right, not work roles, so
  # cybed:OrganizingUnit only. TSC Category is carried verbatim, including the
  # two variant labels the document prints; merging them would alter the
  # published categorisation.
  tsc_nodes <- tscs |>
    purrr::pmap(function(tsc_slug, title, category, description,
                         skillsfuture_derived, ...) {
      member_ids <- bind_rows(level_rows, roa_rows) |>
        filter(owner_id == !!tsc_slug) |>
        pull(element_id)
      member_ids <- extend_role_element_ids(member_ids, expanded$subnode_index)

      unit_metadata <- c(
        list(`cybed:sourceSection` = category),
        if (isTRUE(skillsfuture_derived)) {
          list(`cybed:sourceCategory` = skillsfuture_tag)
        } else {
          list()
        }
      )

      build_organizing_unit_node(
        unit_id           = tsc_slug,
        unit_name         = title,
        framework_prefix  = "otccf",
        framework_subtype = "TechnicalSkillCompetency",
        is_role           = FALSE,
        description       = description,
        element_ids       = member_ids,
        framework_id      = "otccf-v1.1",
        metadata          = unit_metadata
      )
    })

  # Critical Core Skills are defined outside the OTCCF: CSA prints the titles
  # in the skills maps and points to SkillsFuture for the definitions. They
  # are emitted as title-only organizing units so the relations below have a
  # target that exists in the graph, and carry no elements because CSA
  # publishes none for them.
  core_skill_nodes <- core_skills |>
    distinct(skill_slug, skill_name) |>
    arrange(skill_slug) |>
    purrr::pmap(function(skill_slug, skill_name, ...) {
      build_organizing_unit_node(
        unit_id           = skill_slug,
        unit_name         = skill_name,
        framework_prefix  = "otccf",
        framework_subtype = "CriticalCoreSkill",
        is_role           = FALSE,
        framework_id      = "otccf-v1.1",
        metadata          = list(
          `cybed:sourceCategory` = "SkillsFuture Critical Core Skills"
        )
      )
    })

  # One relation node per distinct published statement. A map cell naming two
  # levels was already split into one row per level at ingest, so each row
  # carries exactly one level and the level is kept as printed. Rows are
  # deduplicated on (role, target, level, label) because the source prints
  # some statements twice.
  tsc_relation_nodes <- tsc_map |>
    distinct(role_slug, tsc_slug, proficiency_level) |>
    purrr::pmap(function(role_slug, tsc_slug, proficiency_level, ...) {
      build_unit_relation_node(
        from_unit_id      = role_slug,
        to_unit_id        = tsc_slug,
        from_prefix       = "otccf",
        relation_label    = "requires",
        proficiency_level = as.character(proficiency_level),
        source_section    = "Skills Map: Technical Skills and Competencies",
        framework_id      = "otccf-v1.1"
      )
    })

  core_skill_relation_nodes <- core_skills |>
    distinct(role_slug, skill_slug, proficiency_level) |>
    purrr::pmap(function(role_slug, skill_slug, proficiency_level, ...) {
      build_unit_relation_node(
        from_unit_id      = role_slug,
        to_unit_id        = skill_slug,
        from_prefix       = "otccf",
        relation_label    = "requires",
        proficiency_level = as.character(proficiency_level),
        source_section    = "Skills Map: Critical Core Skills",
        framework_id      = "otccf-v1.1"
      )
    })

  # CSA's skills maps spell five TSC titles differently from the catalogue.
  # The variant stays in the staged table; the relation resolves on the slug.
  variant_titles <- tsc_map |>
    left_join(tscs |> select(tsc_slug, catalogue_title = title), by = "tsc_slug") |>
    filter(tsc_title_as_listed != catalogue_title) |>
    nrow()
  message(sprintf("  role-to-TSC rows with a variant printed title: %d",
                  variant_titles))

  list(framework = framework_node,
       roles     = c(role_nodes, tsc_nodes, core_skill_nodes),
       elements  = expanded$nodes,
       relations = c(tsc_relation_nodes, core_skill_relation_nodes),
       prefix    = "otccf")
}

framework_assemblers <- list(
  nice               = assemble_nice,
  sfia               = assemble_sfia,
  dcwf               = assemble_dcwf,
  ecsf               = assemble_ecsf,
  `cyberorg-k12`     = assemble_cyberorg,
  csta               = assemble_csta,
  `csta-2026`        = assemble_csta2026,
  csec2017           = assemble_csec2017,
  digcomp            = assemble_digcomp,
  cyqual             = assemble_cyqual,
  ccssf              = assemble_ccssf,
  otccf              = assemble_otccf
)

main <- function() {
  message("=== JSON-LD Assembly ===")

  dir.create(assembly_config$output_dir, showWarnings = FALSE, recursive = TRUE)

  all_documents <- list()
  # Each assembler declares its own prefix; the combined @context is built
  # from what they return, in loop order, so there is no second list to drift.
  framework_prefixes <- character()

  for (framework_slug in names(framework_assemblers)) {
    message("\n-- ", framework_slug, " --")
    assembler <- framework_assemblers[[framework_slug]]
    result <- assembler()

    # relations is optional: only frameworks that publish qualified
    # unit-to-unit statements return it. NULL for the rest, which keeps
    # their documents byte-identical to the pre-relation assembly.
    relation_nodes <- result$relations %||% list()

    doc <- assemble_framework_document(
      framework_node = result$framework,
      role_nodes     = result$roles,
      element_nodes  = result$elements,
      framework_prefix = result$prefix,
      relation_nodes = relation_nodes
    )

    out_path <- file.path(assembly_config$output_dir,
                          paste0(framework_slug, ".jsonld"))
    write_jsonld_document(doc, out_path)

    message(sprintf("  Assembled: 1 framework node, %d role nodes, %d element nodes%s",
                    length(result$roles), length(result$elements),
                    if (length(relation_nodes) > 0) {
                      sprintf(", %d relation nodes", length(relation_nodes))
                    } else {
                      ""
                    }))

    all_documents[[framework_slug]] <- doc
    framework_prefixes[[framework_slug]] <- result$prefix
  }

  # Combined multi-framework document
  message("\n-- Combined graph --")
  combined_context <- build_multi_framework_context(framework_prefixes)
  combined_graph <- all_documents |>
    map(\(doc) doc$`@graph`) |>
    unlist(recursive = FALSE) |>
    unname()   # force array-typed @graph on serialization

  combined_doc <- list(
    `@context` = combined_context,
    `@graph`   = combined_graph
  )
  combined_path <- file.path(assembly_config$output_dir, "_combined.jsonld")
  write_jsonld_document(combined_doc, combined_path)
  message(sprintf("  Combined graph: %d total nodes", length(combined_graph)))

  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
