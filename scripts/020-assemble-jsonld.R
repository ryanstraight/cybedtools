# 020-assemble-jsonld.R
#
# Assemble framework-level JSON-LD documents from the tidy CSV staging
# produced by scripts/010-ingest-*.R scripts. Uses the cybed: two-tier
# namespace architecture defined in R/jsonld-helpers.R.
#
# Per-framework adapters translate each framework's native structure into
# the cybed:OrganizingUnit / cybed:RoleElement abstractions. Workforce
# frameworks where the unit is genuinely a work role or work profile
# (NICE work roles, DCWF work roles, ENISA ECSF profiles) additionally
# assert cybed:Role via build_role_node(). Non-workforce frameworks
# (SFIA enumerates skills; Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2
# enumerate other organizing units) call build_organizing_unit_node()
# directly with is_role = FALSE.
#
# Per-framework subtype mapping:
#   nice:WorkRole, dcwf:WorkRole, ecsf:RoleProfile     -> subClassOf cybed:Role
#   sfia:Skill, csec:KnowledgeArea, digcomp:CompetenceArea,
#   cyberorg:StandardGroup, csta:StandardGroup         -> subClassOf cybed:OrganizingUnit
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

assembly_config <- list(
  raw_dir       = here("data", "raw"),
  output_dir    = here("data", "processed", "jsonld"),
  frameworks    = c("nice", "sfia", "dcwf", "ecsf",
                    "cyberorg-k12", "csta", "csec2017", "digcomp")
)

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

      build_role_node(
        role_id              = element_id,
        role_name            = title,
        framework_prefix     = "nice",
        framework_role_type  = "WorkRole",
        description          = text,
        element_ids          = child_ids,
        framework_id         = "nice-v2"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "nice")
}

assemble_sfia <- function() {
  prov          <- load_framework_provenance("sfia")
  skills        <- read_framework_table("sfia", "skill")
  skill_levels  <- read_framework_table("sfia", "skill-level")

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
        framework_id      = "sfia-9"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "sfia")
}

assemble_dcwf <- function() {
  prov     <- load_framework_provenance("dcwf")
  roles    <- read_framework_table("dcwf", "dcwf-roles")
  elements <- read_framework_table("dcwf", "master-task-ksa")

  # Identify the statement-id column (varies by extraction)
  id_col <- intersect(c("dcwf_number", "dcwf_num"), names(elements))[1]
  if (is.na(id_col)) {
    stop("Could not identify DCWF element id column in master-task-ksa.csv")
  }
  elements <- elements |>
    rename(statement_id = !!sym(id_col))

  # Identify text and type columns
  text_col <- intersect(c("task_ksa", "task_or_ksa", "text", "statement"), names(elements))[1]
  if (is.na(text_col)) {
    # Fallback: use the first character column that isn't id
    text_col <- elements |> select(where(is.character)) |> names() |>
      setdiff("statement_id") |> first()
  }

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

  parent_element_nodes <- elements |>
    filter(!is.na(statement_id)) |>
    distinct(statement_id, .keep_all = TRUE) |>
    purrr::pmap(function(statement_id, ...) {
      args <- list(...)
      text_val <- args[[text_col]] %||% NA_character_
      if (is.na(text_val) || text_val == "") return(NULL)
      build_role_element_node(
        element_id             = statement_id,
        framework_prefix       = "dcwf",
        framework_element_type = "TaskOrKSA",
        element_text           = text_val,
        framework_id           = "dcwf-v5.1"
      )
    }) |>
    compact()

  expanded <- expand_with_subpoints(
    element_nodes    = parent_element_nodes,
    framework_prefix = "dcwf",
    framework_id     = "dcwf-v5.1",
    framework_slug   = "dcwf"
  )

  role_nodes <- roles |>
    purrr::pmap(function(dcwf_code, work_role, work_role_definition, ...) {
      build_role_node(
        role_id              = dcwf_code,
        role_name            = work_role,
        framework_prefix     = "dcwf",
        framework_role_type  = "WorkRole",
        description          = work_role_definition,
        element_ids          = character(0),  # per-role associations live in per-role-content-long.csv; not wired yet
        framework_id         = "dcwf-v5.1"
      )
    })

  list(framework = framework_node, roles = role_nodes, elements = expanded$nodes,
       prefix = "dcwf")
}

assemble_ecsf <- function() {
  prov      <- load_framework_provenance("ecsf")
  profiles  <- read_framework_table("ecsf", "profiles")
  elements  <- read_framework_table("ecsf", "profile-elements-long")

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

      build_role_node(
        role_id              = profile_id,
        role_name            = title,
        framework_prefix     = "ecsf",
        framework_role_type  = "RoleProfile",
        description          = mission,
        element_ids          = child_ids,
        framework_id         = "ecsf-v1"
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
        framework_id      = "cyberorg-k12-v1.0"
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

framework_assemblers <- list(
  nice               = assemble_nice,
  sfia               = assemble_sfia,
  dcwf               = assemble_dcwf,
  ecsf               = assemble_ecsf,
  `cyberorg-k12`     = assemble_cyberorg,
  csta               = assemble_csta,
  csec2017           = assemble_csec2017,
  digcomp            = assemble_digcomp
)

# Framework-prefix override for output file naming where slug differs from prefix
framework_to_prefix <- list(
  nice             = "nice",
  sfia             = "sfia",
  dcwf             = "dcwf",
  ecsf             = "ecsf",
  `cyberorg-k12`   = "cyberorg",
  csta             = "csta",
  csec2017         = "csec",
  digcomp          = "digcomp"
)

main <- function() {
  message("=== JSON-LD Assembly ===")

  dir.create(assembly_config$output_dir, showWarnings = FALSE, recursive = TRUE)

  all_documents <- list()

  for (framework_slug in names(framework_assemblers)) {
    message("\n-- ", framework_slug, " --")
    assembler <- framework_assemblers[[framework_slug]]
    result <- assembler()

    doc <- assemble_framework_document(
      framework_node = result$framework,
      role_nodes     = result$roles,
      element_nodes  = result$elements,
      framework_prefix = result$prefix
    )

    out_path <- file.path(assembly_config$output_dir,
                          paste0(framework_slug, ".jsonld"))
    write_jsonld_document(doc, out_path)

    message(sprintf("  Assembled: 1 framework node, %d role nodes, %d element nodes",
                    length(result$roles), length(result$elements)))

    all_documents[[framework_slug]] <- doc
  }

  # Combined multi-framework document
  message("\n-- Combined graph --")
  combined_context <- build_multi_framework_context(unlist(framework_to_prefix))
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
