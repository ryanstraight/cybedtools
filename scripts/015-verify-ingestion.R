# 015-verify-ingestion.R
#
# Data integrity verification for all staged frameworks.
# See the data-integrity pkgdown article for the protocol this implements.
#
# Exits with non-zero status if any HARD failure is detected.
# SOFT flags warn but permit continuation (with written justification
# expected in the audit log).
#
# Run: Rscript scripts/015-verify-ingestion.R

suppressPackageStartupMessages({
  library(here)
  library(yaml)
  library(readr)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(stringr)
  library(digest)
  library(jsonlite)
  library(glue)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

verify_config <- list(
  raw_dir          = here("data", "raw"),
  audit_dir        = here("data", "audit"),
  audit_log        = here("data", "audit", "audit-log.ndjson"),
  invariants_file  = here("docs", "framework-invariants.yml"),
  utf8_replacement = intToUtf8(0xFFFD),
  length_min       = 10L,
  length_max       = 5000L
)

# ---------------------------------------------------------------------------
# Result accumulators
# ---------------------------------------------------------------------------

new_verification_result <- function() {
  list(
    framework        = character(),
    check            = character(),
    severity         = character(),    # "pass" | "soft" | "hard"
    message          = character(),
    details          = list()
  )
}

record_check <- function(results, framework, check, severity, message, details = NULL) {
  results$framework <- c(results$framework, framework)
  results$check     <- c(results$check, check)
  results$severity  <- c(results$severity, severity)
  results$message   <- c(results$message, message)
  results$details[[length(results$details) + 1]] <- details %||% list()
  results
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Coalesce NA/NULL to zero for table() results
coalesce_zero <- function(x) {
  if (is.null(x)) return(0L)
  if (length(x) == 0) return(0L)
  if (is.na(x)) return(0L)
  as.integer(x)
}

# ---------------------------------------------------------------------------
# Invariant 1: Source provenance
# ---------------------------------------------------------------------------

verify_provenance <- function(framework, results) {
  fw_dir <- file.path(verify_config$raw_dir, framework)
  manifest_path <- file.path(fw_dir, "provenance.yml")

  if (!file.exists(manifest_path)) {
    return(record_check(results, framework, "provenance.exists", "hard",
                        "provenance.yml missing"))
  }

  manifest <- tryCatch(read_yaml(manifest_path), error = function(e) NULL)
  if (is.null(manifest)) {
    return(record_check(results, framework, "provenance.parses", "hard",
                        "provenance.yml exists but failed to parse"))
  }

  required_keys <- c("framework", "framework_version", "source", "retrieval", "licensing")
  missing_keys <- setdiff(required_keys, names(manifest))
  if (length(missing_keys) > 0) {
    results <- record_check(results, framework, "provenance.keys", "hard",
                            glue("provenance.yml missing keys: {paste(missing_keys, collapse=', ')}"))
  } else {
    results <- record_check(results, framework, "provenance.keys", "pass",
                            "required keys present")
  }

  # SHA256 verification if retrieval recorded a hash + file
  retrieval <- manifest$retrieval %||% list()
  declared_sha <- retrieval$file_sha256 %||% retrieval$db_sha256
  source_file_candidates <- c(
    retrieval$db_file,
    manifest$source$filename %||% NULL,
    manifest$source$source_filename %||% NULL
  ) |> unlist() |> unique()

  if (!is.null(declared_sha) && length(source_file_candidates) > 0) {
    source_path <- file.path(fw_dir, source_file_candidates[1])
    if (file.exists(source_path)) {
      actual_sha <- digest(file = source_path, algo = "sha256")
      if (identical(actual_sha, declared_sha)) {
        results <- record_check(results, framework, "provenance.sha256", "pass",
                                "SHA256 matches declared")
      } else {
        results <- record_check(results, framework, "provenance.sha256", "hard",
                                "SHA256 mismatch",
                                list(declared = declared_sha, actual = actual_sha))
      }
    } else {
      results <- record_check(results, framework, "provenance.sha256", "hard",
                              glue("source file declared but not found: {source_path}"))
    }
  }

  # A manifest may instead list several staged files under source$files, each
  # with its own filename and file_sha256 (csta-2026 stages its JSON, the PDF
  # and CSTA's crosswalk that way). Every listed file must be present and
  # match.
  for (f in manifest$source$files %||% list()) {
    if (is.null(f$filename) || is.null(f$file_sha256)) next
    source_path <- file.path(fw_dir, f$filename)
    check_name <- glue("provenance.sha256.{f$filename}")
    if (!file.exists(source_path)) {
      results <- record_check(results, framework, check_name, "hard",
                              glue("source file declared but not found: {source_path}"))
      next
    }
    actual_sha <- digest(file = source_path, algo = "sha256")
    if (identical(actual_sha, f$file_sha256)) {
      results <- record_check(results, framework, check_name, "pass",
                              "SHA256 matches declared")
    } else {
      results <- record_check(results, framework, check_name, "hard",
                              "SHA256 mismatch",
                              list(declared = f$file_sha256, actual = actual_sha))
    }
  }

  results
}

# ---------------------------------------------------------------------------
# Invariant 2: Extraction invariants
# ---------------------------------------------------------------------------

verify_counts <- function(framework, invariants, results) {
  fw_invariants <- invariants$frameworks[[framework]]
  if (is.null(fw_invariants)) {
    return(record_check(results, framework, "counts.declared", "hard",
                        "no invariants declared in framework-invariants.yml"))
  }

  expected <- fw_invariants$expected %||% list()
  if (length(expected) == 0) {
    return(record_check(results, framework, "counts.declared", "hard",
                        "expected counts not declared"))
  }

  tables_dir <- file.path(verify_config$raw_dir, framework, "tables")
  if (!dir.exists(tables_dir)) {
    return(record_check(results, framework, "counts.tables", "hard",
                        "tables/ directory missing"))
  }

  actual_counts <- framework_actual_counts(framework, tables_dir)

  for (metric in names(expected)) {
    bounds <- expected[[metric]]
    actual <- actual_counts[[metric]]

    if (is.null(actual)) {
      results <- record_check(results, framework, glue("counts.{metric}"), "soft",
                              glue("metric '{metric}' not measurable from current extraction"),
                              list(expected = bounds))
      next
    }

    within_bounds <- length(bounds) == 2 && actual >= bounds[1] && actual <= bounds[2]
    if (within_bounds) {
      results <- record_check(results, framework, glue("counts.{metric}"), "pass",
                              glue("{metric} = {actual} in [{bounds[1]}, {bounds[2]}]"))
    } else {
      results <- record_check(results, framework, glue("counts.{metric}"), "soft",
                              glue("{metric} = {actual} outside [{bounds[1]}, {bounds[2]}]"),
                              list(expected = bounds, actual = actual))
    }
  }

  results
}

#' Measure actual counts from extracted tables, per framework
framework_actual_counts <- function(framework, tables_dir) {
  safe_read <- function(file_path) {
    if (file.exists(file_path)) read_csv(file_path, show_col_types = FALSE) else NULL
  }

  switch(framework,
    sfia = {
      list(
        skills           = safe_read(file.path(tables_dir, "skill.csv"))           |> nrow_or_null(),
        skill_levels     = safe_read(file.path(tables_dir, "skill-level.csv"))     |> nrow_or_null(),
        skills_profiles  = safe_read(file.path(tables_dir, "skills-profile.csv"))  |> nrow_or_null(),
        levels           = safe_read(file.path(tables_dir, "level.csv"))           |> nrow_or_null()
      )
    },
    dcwf = {
      list(
        work_roles        = safe_read(file.path(tables_dir, "dcwf-roles.csv"))     |> nrow_or_null(),
        master_task_ksa   = safe_read(file.path(tables_dir, "master-task-ksa.csv")) |> nrow_or_null()
      )
    },
    ecsf = {
      list(
        role_profiles        = safe_read(file.path(tables_dir, "profiles.csv")) |> nrow_or_null(),
        profile_elements     = safe_read(file.path(tables_dir, "profile-elements-long.csv")) |> nrow_or_null(),
        ecf_cross_references = safe_read(file.path(tables_dir, "ecf-cross-references.csv")) |> nrow_or_null()
      )
    },
    nice = {
      list(
        work_roles            = safe_read(file.path(tables_dir, "work-roles.csv"))            |> nrow_or_null(),
        tasks                 = safe_read(file.path(tables_dir, "tasks.csv"))                 |> nrow_or_null(),
        knowledge             = safe_read(file.path(tables_dir, "knowledge.csv"))             |> nrow_or_null(),
        skills                = safe_read(file.path(tables_dir, "skills.csv"))                |> nrow_or_null(),
        categories            = safe_read(file.path(tables_dir, "categories.csv"))            |> nrow_or_null(),
        competency_areas      = safe_read(file.path(tables_dir, "competency-areas.csv"))      |> nrow_or_null(),
        role_tks_associations = safe_read(file.path(tables_dir, "role-tks-associations.csv")) |> nrow_or_null(),
        unique_tks            = {
          t_count <- safe_read(file.path(tables_dir, "tasks.csv"))     |> nrow_or_null()
          k_count <- safe_read(file.path(tables_dir, "knowledge.csv")) |> nrow_or_null()
          s_count <- safe_read(file.path(tables_dir, "skills.csv"))    |> nrow_or_null()
          if (is.null(t_count) || is.null(k_count) || is.null(s_count)) NULL
          else t_count + k_count + s_count
        }
      )
    },
    `cyberorg-k12` = {
      standards <- safe_read(file.path(tables_dir, "standards.csv"))
      subconcepts <- safe_read(file.path(tables_dir, "sub-concepts.csv"))
      list(
        grade_bands     = if (!is.null(standards)) length(unique(standards$grade_band)) else NULL,
        themes          = if (!is.null(standards)) length(unique(standards$theme))      else NULL,
        sub_concepts    = nrow_or_null(subconcepts),
        standards_total = nrow_or_null(standards)
      )
    },
    csta = {
      standards <- safe_read(file.path(tables_dir, "standards.csv"))
      levels    <- safe_read(file.path(tables_dir, "levels.csv"))
      clusters  <- safe_read(file.path(tables_dir, "clusters.csv"))
      list(
        standards_count = nrow_or_null(standards),
        levels_count    = nrow_or_null(levels),
        clusters_count  = nrow_or_null(clusters),
        concepts        = if (!is.null(standards)) length(unique(standards$concept)) else NULL
      )
    },
    `csta-2026` = {
      standards  <- safe_read(file.path(tables_dir, "standards.csv"))
      units      <- safe_read(file.path(tables_dir, "units.csv"))
      boundaries <- safe_read(file.path(tables_dir, "boundaries.csv"))
      examples   <- safe_read(file.path(tables_dir, "examples.csv"))
      found      <- if (is.null(standards)) NULL else standards[standards$tier == "foundational", ]
      list(
        standards_count         = nrow_or_null(standards),
        foundational_standards  = nrow_or_null(found),
        specialty_standards     = if (is.null(standards)) NULL else sum(standards$tier == "specialty"),
        levels_count            = if (is.null(standards)) NULL else dplyr::n_distinct(standards$level),
        foundational_concepts   = if (is.null(found)) NULL else dplyr::n_distinct(found$concept),
        specialty_areas         = if (is.null(standards)) NULL
                                  else dplyr::n_distinct(standards$specialty_area_code, na.rm = TRUE),
        cybersecurity_standards = if (is.null(standards)) NULL
                                  else sum(standards$specialty_area_code %in% "CYB"),
        # Units are the observed (level, concept) pairs, so an area published
        # at one tier only (X+CS) contributes one unit, not two.
        organizing_units        = nrow_or_null(units),
        foundational_units      = if (is.null(units)) NULL else sum(units$tier == "foundational"),
        specialty_units         = if (is.null(units)) NULL else sum(units$tier == "specialty"),
        boundary_statements     = nrow_or_null(boundaries),
        implementation_examples = nrow_or_null(examples),
        standards_with_examples = if (is.null(examples)) NULL else dplyr::n_distinct(examples$code),
        ai_standards            = if (is.null(standards)) NULL else sum(standards$ai_standard)
      )
    },
    csec2017 = {
      kas <- safe_read(file.path(tables_dir, "knowledge-areas.csv"))
      essentials <- safe_read(file.path(tables_dir, "essentials.csv"))
      list(
        knowledge_areas  = nrow_or_null(kas),
        essentials_total = nrow_or_null(essentials)
      )
    },
    cyqual = {
      tasks        <- safe_read(file.path(tables_dir, "tasks.csv"))
      requirements <- safe_read(file.path(tables_dir, "requirements.csv"))
      list(
        roles_count                 = safe_read(file.path(tables_dir, "work-roles.csv"))               |> nrow_or_null(),
        tasks                       = nrow_or_null(tasks),
        requirements                = nrow_or_null(requirements),
        # Tasks and requirements are the element population; roles reference
        # shared elements rather than owning private copies.
        elements_count              = {
          if (is.null(tasks) || is.null(requirements)) NULL
          else nrow(tasks) + nrow(requirements)
        },
        competencies                = safe_read(file.path(tables_dir, "competencies.csv"))             |> nrow_or_null(),
        competency_groups           = safe_read(file.path(tables_dir, "competency-groups.csv"))        |> nrow_or_null(),
        specialization_areas        = safe_read(file.path(tables_dir, "specialization-areas.csv"))     |> nrow_or_null(),
        categories                  = safe_read(file.path(tables_dir, "categories.csv"))               |> nrow_or_null(),
        work_role_task_edges        = safe_read(file.path(tables_dir, "work-role-tasks.csv"))          |> nrow_or_null(),
        work_role_requirement_edges = safe_read(file.path(tables_dir, "work-role-requirements.csv"))   |> nrow_or_null()
      )
    },
    ccssf = {
      roles     <- safe_read(file.path(tables_dir, "roles.csv"))
      adjacent  <- safe_read(file.path(tables_dir, "adjacent-roles.csv"))
      elements  <- safe_read(file.path(tables_dir, "role-elements-long.csv"))
      adj_comps <- safe_read(file.path(tables_dir, "adjacent-role-competencies-long.csv"))
      crosswalk <- safe_read(file.path(tables_dir, "nice-crosswalk.csv"))
      list(
        activity_areas             = safe_read(file.path(tables_dir, "activity-areas.csv")) |> nrow_or_null(),
        core_roles                 = nrow_or_null(roles),
        adjacent_roles             = nrow_or_null(adjacent),
        # Both populations are Roles in the graph: 22 Annex A-D core roles
        # plus 37 Annex E cyber adjacent roles.
        roles_count                = {
          if (is.null(roles) || is.null(adjacent)) NULL else nrow(roles) + nrow(adjacent)
        },
        core_role_elements         = nrow_or_null(elements),
        adjacent_role_competencies = nrow_or_null(adj_comps),
        # Only three of the thirteen staged element types become element
        # nodes; the rest are role-level attributes that stay in the tables.
        element_node_rows          = {
          if (is.null(elements) || is.null(adj_comps)) NULL
          else sum(elements$element_type %in%
                     c("tasks", "competencies", "tools_and_technology")) + nrow(adj_comps)
        },
        # Source-printed sub-bullets: rows the source nests under a
        # colon-terminated parent bullet. Modelled as cybed:Subpoint of that
        # parent in the graph, not as sibling top-level elements.
        source_printed_subpoints   = if (is.null(elements) ||
                                         !"parent_index" %in% names(elements)) NULL
                                     else sum(!is.na(elements$parent_index)),
        nice_crosswalk_rows        = crosswalk |> nrow_or_null(),
        # Cited ids carried into the graph as cybed:niceCrossReference
        # literals, and the subset whose printed form is malformed in the
        # source (kept visible inside the literal).
        nice_crosswalk_ids         = if (is.null(crosswalk)) NULL
                                     else sum(!is.na(crosswalk$nice_work_role_id_normalized)),
        nice_crosswalk_malformed_ids = if (is.null(crosswalk)) NULL
                                     else sum(crosswalk$id_malformed_in_source %in% TRUE)
      )
    },
    otccf = {
      roles      <- safe_read(file.path(tables_dir, "job-roles.csv"))
      role_els   <- safe_read(file.path(tables_dir, "role-elements-long.csv"))
      tscs       <- safe_read(file.path(tables_dir, "tscs.csv"))
      tsc_levels <- safe_read(file.path(tables_dir, "tsc-levels-long.csv"))
      roa        <- safe_read(file.path(tables_dir, "tsc-range-of-application.csv"))
      tsc_map    <- safe_read(file.path(tables_dir, "role-tsc-map.csv"))
      ccs        <- safe_read(file.path(tables_dir, "role-critical-core-skills.csv"))
      list(
        tracks                   = safe_read(file.path(tables_dir, "tracks.csv")) |> nrow_or_null(),
        job_roles                = nrow_or_null(roles),
        role_tracks              = safe_read(file.path(tables_dir, "role-tracks.csv")) |> nrow_or_null(),
        critical_work_functions  = if (is.null(role_els)) NULL
                                   else sum(role_els$element_type == "critical_work_function"),
        key_tasks                = if (is.null(role_els)) NULL
                                   else sum(role_els$element_type == "key_task"),
        tscs                     = nrow_or_null(tscs),
        skillsfuture_derived_tscs = if (is.null(tscs)) NULL else sum(tscs$skillsfuture_derived),
        tsc_level_statements     = nrow_or_null(tsc_levels),
        range_of_application     = nrow_or_null(roa),
        # Key tasks, level statements, and range-of-application rows are the
        # whole element population; CWFs are headings carried as
        # cybed:sourceSection, not element nodes.
        element_node_rows        = {
          if (is.null(role_els) || is.null(tsc_levels) || is.null(roa)) NULL
          else sum(role_els$element_type == "key_task") + nrow(tsc_levels) + nrow(roa)
        },
        # Both skills maps are in the graph: one cybed:UnitRelation per row,
        # and one cybed:relatedUnit edge per distinct role-to-target pair.
        role_tsc_map_rows        = nrow_or_null(tsc_map),
        # Five TSC titles are spelled differently in the skills maps than in
        # the catalogue. The variant stays in the staged table; the relation
        # resolves on the slug. Counted so a change in the source is caught.
        role_tsc_map_variant_titles = {
          if (is.null(tsc_map) || is.null(tscs)) NULL
          else sum(tsc_map$tsc_title_as_listed !=
                     tscs$title[match(tsc_map$tsc_slug, tscs$tsc_slug)], na.rm = TRUE)
        },
        role_tsc_related_pairs   = {
          if (is.null(tsc_map)) NULL
          else nrow(dplyr::distinct(tsc_map, role_slug, tsc_slug))
        },
        role_tsc_map_unresolved  = {
          if (is.null(tsc_map) || is.null(tscs) || is.null(roles)) NULL
          else sum(is.na(tsc_map$tsc_slug) | !tsc_map$tsc_slug %in% tscs$tsc_slug |
                     !tsc_map$role_slug %in% roles$role_slug)
        },
        role_critical_core_skills_rows = nrow_or_null(ccs),
        role_critical_core_skills_unresolved = {
          if (is.null(ccs) || is.null(roles)) NULL
          else sum(!ccs$role_slug %in% roles$role_slug)
        },
        # Distinct Critical Core Skill titles. Each becomes one non-role
        # organizing unit; the skills themselves are SkillsFuture's, not the
        # OTCCF's, and the document prints titles only.
        critical_core_skills     = if (is.null(ccs)) NULL
                                   else dplyr::n_distinct(ccs$skill_name),
        role_critical_core_skill_pairs = {
          if (is.null(ccs)) NULL
          else nrow(dplyr::distinct(ccs, role_slug, skill_name))
        },
        # Distinct published statements across both skills maps, which is the
        # number of cybed:UnitRelation nodes the assembler emits. The source
        # prints some core-skill statements twice, so this sits below the
        # staged row totals tracked above.
        unit_relations           = {
          if (is.null(tsc_map) || is.null(ccs)) NULL
          else nrow(dplyr::distinct(tsc_map, role_slug, tsc_slug, proficiency_level)) +
               nrow(dplyr::distinct(ccs, role_slug, skill_name, proficiency_level))
        },
        # Staged core-skill rows the source prints twice, kept visible so a
        # change in the source is caught rather than absorbed by the dedupe.
        role_critical_core_skills_duplicate_rows = {
          if (is.null(ccs)) NULL
          else nrow(ccs) -
               nrow(dplyr::distinct(ccs, role_slug, skill_name, proficiency_level))
        }
      )
    },
    scywf = {
      stmts    <- safe_read(file.path(tables_dir, "statements.csv"))
      links    <- safe_read(file.path(tables_dir, "role-statements.csv"))
      unres    <- safe_read(file.path(tables_dir, "unresolved-codes.csv"))
      verbatim <- safe_read(file.path(tables_dir, "verbatim-check.csv"))
      list(
        categories                 = safe_read(file.path(tables_dir, "categories.csv")) |> nrow_or_null(),
        specialty_areas            = safe_read(file.path(tables_dir, "specialty-areas.csv")) |> nrow_or_null(),
        job_roles                  = safe_read(file.path(tables_dir, "roles.csv")) |> nrow_or_null(),
        tasks                      = if (is.null(stmts)) NULL else sum(stmts$statement_type == "task"),
        knowledge                  = if (is.null(stmts)) NULL else sum(stmts$statement_type == "knowledge"),
        skills                     = if (is.null(stmts)) NULL else sum(stmts$statement_type == "skill"),
        statements                 = nrow_or_null(stmts),
        role_statement_links       = nrow_or_null(links),
        unresolved_card_codes      = nrow_or_null(unres),
        # Appendix B statements printed on no role card.
        orphan_statements          = if (is.null(stmts) || is.null(links)) NULL
                                     else sum(!stmts$statement_id %in% links$statement_id),
        competency_areas           = safe_read(file.path(tables_dir, "competency-areas.csv")) |> nrow_or_null(),
        role_competency_area_links = safe_read(file.path(tables_dir, "role-competency-areas.csv")) |> nrow_or_null(),
        verbatim_failures          = if (is.null(verbatim)) NULL else sum(!verbatim$found)
      )
    },
    cybok = {
      topics   <- safe_read(file.path(tables_dir, "topics.csv"))
      im       <- safe_read(file.path(tables_dir, "indicative-material.csv"))
      atoz     <- safe_read(file.path(tables_dir, "a-to-z-resolution.csv"))
      verbatim <- safe_read(file.path(tables_dir, "verbatim-check.csv"))
      xw       <- safe_read(file.path(tables_dir, "crosswalk-ka-resolution.csv"))
      list(
        categories           = safe_read(file.path(tables_dir, "categories.csv")) |> nrow_or_null(),
        knowledge_areas      = safe_read(file.path(tables_dir, "knowledge-areas.csv")) |> nrow_or_null(),
        topics               = nrow_or_null(topics),
        indicative_material  = nrow_or_null(im),
        topics_without_indicative_material =
          if (is.null(topics) || is.null(im)) NULL else sum(!topics$topic_id %in% im$topic_id),
        a_to_z_rows          = nrow_or_null(atoz),
        a_to_z_rows_resolved = if (is.null(atoz)) NULL else sum(atoz$status == "resolved" & atoz$ka_acronym != "CI"),
        verbatim_failures    = if (is.null(verbatim)) NULL else sum(!verbatim$found),
        crosswalk_ka_names_unresolved = if (is.null(xw)) NULL else sum(xw$resolution == "unresolved")
      )
    },
    digcomp = {
      areas <- safe_read(file.path(tables_dir, "competence-areas.csv"))
      competences <- safe_read(file.path(tables_dir, "competences.csv"))
      descs <- safe_read(file.path(tables_dir, "competence-descriptions.csv"))
      statements <- safe_read(file.path(tables_dir, "competence-statements.csv"))
      outcomes <- safe_read(file.path(tables_dir, "learning-outcomes.csv"))
      list(
        competence_areas      = nrow_or_null(areas),
        competences           = nrow_or_null(competences),
        descriptions_found    = if (!is.null(descs)) sum(!is.na(descs$description)) else NULL,
        competence_statements = nrow_or_null(statements),
        learning_outcomes     = nrow_or_null(outcomes)
      )
    },
    list()
  )
}

nrow_or_null <- function(x) if (is.null(x)) NULL else nrow(x)

# ---------------------------------------------------------------------------
# Invariant 4: Text integrity
# ---------------------------------------------------------------------------

verify_text_integrity <- function(framework, results) {
  tables_dir <- file.path(verify_config$raw_dir, framework, "tables")
  if (!dir.exists(tables_dir)) return(results)

  text_fields <- text_fields_by_framework(framework)

  for (tf in text_fields) {
    file_path <- file.path(tables_dir, tf$file)
    if (!file.exists(file_path)) next

    tbl <- read_csv(file_path, show_col_types = FALSE)
    column <- tf$column
    if (!column %in% names(tbl)) next

    text_values <- tbl[[column]]

    # UTF-8 replacement characters
    utf_bad <- sum(str_detect(text_values %||% "", fixed(verify_config$utf8_replacement)),
                   na.rm = TRUE)

    # Empty (after trimming)
    empty_count <- sum(is.na(text_values) | str_trim(text_values %||% "") == "",
                       na.rm = TRUE)

    # Length sanity
    text_lengths <- nchar(text_values %||% "")
    short_count <- sum(text_lengths > 0 & text_lengths < verify_config$length_min, na.rm = TRUE)
    long_count  <- sum(text_lengths > verify_config$length_max, na.rm = TRUE)

    # Suspicious round-number clustering (truncation tell)
    length_mode <- if (length(text_lengths) > 0) {
      most_common <- table(text_lengths) |> sort(decreasing = TRUE) |> head(1)
      as.integer(names(most_common))
    } else {
      NA_integer_
    }
    suspicious_truncation <- !is.na(length_mode) &&
                              length_mode %in% c(255L, 256L, 1000L, 1024L, 4000L, 4096L) &&
                              sum(text_lengths == length_mode, na.rm = TRUE) > 5

    if (utf_bad > 0) {
      results <- record_check(results, framework, glue("text.utf8.{tf$label}"), "hard",
                              glue("{utf_bad} row(s) contain UTF-8 replacement character"))
    } else {
      results <- record_check(results, framework, glue("text.utf8.{tf$label}"), "pass",
                              "no UTF-8 replacement characters")
    }

    if (empty_count > 0) {
      results <- record_check(results, framework, glue("text.nonempty.{tf$label}"), "hard",
                              glue("{empty_count} row(s) have empty or NA text"))
    } else {
      results <- record_check(results, framework, glue("text.nonempty.{tf$label}"), "pass",
                              "all rows have non-empty text")
    }

    if (short_count > 0 || long_count > 0) {
      results <- record_check(results, framework, glue("text.length.{tf$label}"), "soft",
                              glue("{short_count} short (<{verify_config$length_min}ch), ",
                                   "{long_count} long (>{verify_config$length_max}ch)"))
    } else {
      results <- record_check(results, framework, glue("text.length.{tf$label}"), "pass",
                              "lengths within sanity band")
    }

    if (suspicious_truncation) {
      results <- record_check(results, framework, glue("text.truncation.{tf$label}"), "hard",
                              glue("length mode = {length_mode} suggests silent truncation"))
    }
  }

  results
}

#' Identify the text fields each framework exposes for checking
text_fields_by_framework <- function(framework) {
  switch(framework,
    sfia = list(
      list(label = "skill-desc",     file = "skill.csv",       column = "description"),
      list(label = "skill-level",    file = "skill-level.csv", column = "description")
    ),
    dcwf = list(
      list(label = "roles-def",      file = "dcwf-roles.csv",  column = "work_role_definition")
    ),
    ecsf = list(
      list(label = "element-text",   file = "profile-elements-long.csv", column = "element_text"),
      list(label = "profile-mission", file = "profiles.csv",   column = "mission")
    ),
    nice = list(
      list(label = "task-text",      file = "tasks.csv",     column = "text"),
      list(label = "knowledge-text", file = "knowledge.csv", column = "text"),
      list(label = "skill-text",     file = "skills.csv",    column = "text"),
      list(label = "role-desc",      file = "work-roles.csv", column = "text")
    ),
    `cyberorg-k12` = list(
      list(label = "standard-text", file = "standards.csv", column = "statement_text")
    ),
    csta = list(
      # clarification is optional per CSTA doc structure; not checked for non-empty
      list(label = "standard-text",       file = "standards.csv", column = "standard")
    ),
    `csta-2026` = list(
      list(label = "standard-text",      file = "standards.csv",  column = "title"),
      list(label = "boundary-statement", file = "boundaries.csv", column = "text"),
      list(label = "example-text",       file = "examples.csv",   column = "text")
    ),
    csec2017 = list(
      list(label = "essential-text", file = "essentials.csv", column = "element_text")
    ),
    digcomp = list(
      list(label = "competence-name",      file = "competences.csv",           column = "competence_name"),
      list(label = "area-description",     file = "competence-area-descriptions.csv", column = "description"),
      list(label = "statement-text",       file = "competence-statements.csv", column = "description"),
      list(label = "outcome-text",         file = "learning-outcomes.csv",     column = "description")
    ),
    cyqual = list(
      list(label = "task-text",        file = "tasks.csv",        column = "description"),
      list(label = "requirement-text", file = "requirements.csv", column = "description"),
      list(label = "role-desc",        file = "work-roles.csv",   column = "description"),
      list(label = "competency-desc",  file = "competencies.csv", column = "description")
    ),
    ccssf = list(
      list(label = "role-desc",        file = "roles.csv",                            column = "description"),
      list(label = "element-text",     file = "role-elements-long.csv",               column = "element_text"),
      list(label = "adjacent-resp",    file = "adjacent-roles.csv",                   column = "responsibility"),
      list(label = "adjacent-comp",    file = "adjacent-role-competencies-long.csv",  column = "competency")
    ),
    scywf = list(
      list(label = "role-desc",        file = "roles.csv",            column = "description"),
      list(label = "statement-text",   file = "statements.csv",       column = "text"),
      list(label = "ca-desc",          file = "competency-areas.csv", column = "description")
    ),
    cybok = list(
      list(label = "ka-name",             file = "knowledge-areas.csv",     column = "ka_name"),
      list(label = "topic-title",         file = "topics.csv",              column = "title"),
      list(label = "indicative-material", file = "indicative-material.csv", column = "term")
    ),
    otccf = list(
      list(label = "role-desc",        file = "job-roles.csv",                column = "role_description"),
      list(label = "role-element",     file = "role-elements-long.csv",       column = "element_text"),
      list(label = "tsc-desc",         file = "tscs.csv",                     column = "description"),
      list(label = "level-statement",  file = "tsc-levels-long.csv",          column = "element_text"),
      list(label = "range-of-application", file = "tsc-range-of-application.csv", column = "element_text")
    ),
    list()
  )
}

# ---------------------------------------------------------------------------
# Invariant 5: ID uniqueness (framework-scope only here; namespace check
# happens in JSON-LD assembly)
# ---------------------------------------------------------------------------

verify_id_uniqueness <- function(framework, results) {
  tables_dir <- file.path(verify_config$raw_dir, framework, "tables")
  if (!dir.exists(tables_dir)) return(results)

  id_specs <- switch(framework,
    sfia = list(
      list(file = "skill.csv",        id_col = "code",    label = "skill-code")
    ),
    dcwf = list(
      list(file = "dcwf-roles.csv",   id_col = "dcwf_code", label = "dcwf-code")
    ),
    ecsf = list(
      list(file = "profiles.csv",     id_col = "profile_id", label = "profile-id")
    ),
    `cyberorg-k12` = list(
      list(file = "standards.csv",    id_col = "standard_id", label = "standard-id")
    ),
    csta = list(
      list(file = "standards.csv",    id_col = "identifier",  label = "csta-identifier")
    ),
    `csta-2026` = list(
      list(file = "standards.csv", id_col = "code",    label = "csta2026-code"),
      list(file = "units.csv",     id_col = "unit_id", label = "csta2026-unit-id")
    ),
    csec2017 = list(
      list(file = "knowledge-areas.csv", id_col = "ka_id",       label = "ka-id"),
      list(file = "essentials.csv",      id_col = "element_id",  label = "essential-id")
    ),
    digcomp = list(
      list(file = "competence-areas.csv",      id_col = "area_id",        label = "area-id"),
      list(file = "competences.csv",           id_col = "competence_id",  label = "competence-id"),
      list(file = "competence-statements.csv", id_col = "statement_id",   label = "statement-id"),
      list(file = "learning-outcomes.csv",     id_col = "outcome_id",     label = "outcome-id")
    ),
    cyqual = list(
      list(file = "work-roles.csv",           id_col = "code", label = "cyqual-work-role-code"),
      list(file = "tasks.csv",                id_col = "code", label = "cyqual-task-code"),
      list(file = "requirements.csv",         id_col = "code", label = "cyqual-requirement-code"),
      list(file = "competencies.csv",         id_col = "code", label = "cyqual-competency-code"),
      list(file = "specialization-areas.csv", id_col = "code", label = "cyqual-specialization-area-code"),
      list(file = "categories.csv",           id_col = "code", label = "cyqual-category-code"),
      list(file = "competency-groups.csv",    id_col = "code", label = "cyqual-competency-group-code")
    ),
    ccssf = list(
      list(file = "roles.csv",          id_col = "role_id",          label = "ccssf-role-id"),
      list(file = "adjacent-roles.csv", id_col = "adjacent_role_id", label = "ccssf-adjacent-role-id")
    ),
    scywf = list(
      list(file = "roles.csv",            id_col = "role_id",           label = "scywf-role-id"),
      list(file = "statements.csv",       id_col = "statement_id",      label = "scywf-statement-code"),
      list(file = "competency-areas.csv", id_col = "ca_id",             label = "scywf-ca-code"),
      list(file = "categories.csv",       id_col = "category_id",       label = "scywf-category-id"),
      list(file = "specialty-areas.csv",  id_col = "specialty_area_id", label = "scywf-specialty-area-id")
    ),
    cybok = list(
      list(file = "knowledge-areas.csv", id_col = "ka_acronym", label = "cybok-ka-acronym"),
      list(file = "knowledge-areas.csv", id_col = "ka_name",    label = "cybok-ka-name"),
      list(file = "topics.csv",          id_col = "topic_id",   label = "cybok-topic-id")
    ),
    otccf = list(
      list(file = "job-roles.csv", id_col = "role_slug",  label = "otccf-role-slug"),
      list(file = "tscs.csv",      id_col = "tsc_slug",   label = "otccf-tsc-slug"),
      list(file = "tracks.csv",    id_col = "track_slug", label = "otccf-track-slug")
    ),
    nice = list(
      list(file = "work-roles.csv",   id_col = "element_id",  label = "work-role-id"),
      list(file = "tasks.csv",        id_col = "element_id",  label = "task-id"),
      list(file = "knowledge.csv",    id_col = "element_id",  label = "knowledge-id"),
      list(file = "skills.csv",       id_col = "element_id",  label = "skill-id")
    ),
    list()
  )

  for (spec in id_specs) {
    file_path <- file.path(tables_dir, spec$file)
    if (!file.exists(file_path)) next

    tbl <- read_csv(file_path, show_col_types = FALSE)
    if (!spec$id_col %in% names(tbl)) {
      results <- record_check(results, framework, glue("ids.{spec$label}"), "hard",
                              glue("id column '{spec$id_col}' missing from {spec$file}"))
      next
    }

    id_values <- tbl[[spec$id_col]]
    duplicate_count <- sum(duplicated(id_values))
    if (duplicate_count > 0) {
      dup_examples <- id_values[duplicated(id_values)] |> unique() |> head(5)
      results <- record_check(results, framework, glue("ids.{spec$label}"), "hard",
                              glue("{duplicate_count} duplicate id(s)"),
                              list(examples = dup_examples))
    } else {
      results <- record_check(results, framework, glue("ids.{spec$label}"), "pass",
                              glue("all {length(id_values)} ids unique"))
    }
  }

  results
}

# ---------------------------------------------------------------------------
# Invariant 6: verbatim carriage (frameworks licensed on that condition)
# ---------------------------------------------------------------------------

#' SCyWF is carried under a permission that requires verbatim text, and
#' CyBOK is read from PDFs with no structured release. Both ingests look every
#' carried string up in an independent extraction of the PDF and write the
#' result to verbatim-check.csv. A missing string, a missing check file, or
#' (SCyWF only) a role-card code with no Appendix B statement is a HARD
#' failure here, not a soft count drift.
verify_verbatim_carriage <- function(framework_slug, results) {
  if (!framework_slug %in% c("scywf", "cybok")) return(results)
  tables_dir <- file.path(verify_config$raw_dir, framework_slug, "tables")

  check_path <- file.path(tables_dir, "verbatim-check.csv")
  if (!file.exists(check_path)) {
    return(record_check(results, framework_slug, "verbatim.check", "hard",
                        "verbatim-check.csv missing: the ingest did not run its check"))
  }
  check <- read_csv(check_path, show_col_types = FALSE,
                    col_types = cols(.default = col_character(), found = col_logical()))
  failed <- check[!check$found, , drop = FALSE]
  if (nrow(check) == 0 || nrow(failed) > 0) {
    results <- record_check(results, framework_slug, "verbatim.check", "hard",
                            glue("{nrow(failed)} of {nrow(check)} carried strings not found"),
                            list(examples = head(paste(failed$field, failed$id), 5)))
  } else {
    results <- record_check(results, framework_slug, "verbatim.check", "pass",
                            glue("all {nrow(check)} carried strings found verbatim"))
  }
  if (!identical(framework_slug, "scywf")) return(results)

  unresolved_path <- file.path(tables_dir, "unresolved-codes.csv")
  unresolved <- if (file.exists(unresolved_path)) read_csv(unresolved_path, show_col_types = FALSE) else NULL
  if (is.null(unresolved) || nrow(unresolved) > 0) {
    results <- record_check(results, framework_slug, "verbatim.card-codes", "hard",
                            "role-card codes without an Appendix B statement, or no record of the check")
  } else {
    results <- record_check(results, framework_slug, "verbatim.card-codes", "pass",
                            "every role-card code resolves to an Appendix B statement")
  }
  results
}

# ---------------------------------------------------------------------------
# Audit trail
# ---------------------------------------------------------------------------

write_audit_entry <- function(results, frameworks_checked) {
  if (!dir.exists(verify_config$audit_dir)) {
    dir.create(verify_config$audit_dir, recursive = TRUE)
  }

  severity_counts <- table(results$severity)

  entry <- list(
    timestamp        = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    script           = "scripts/015-verify-ingestion.R",
    frameworks       = frameworks_checked,
    check_count      = length(results$check),
    pass_count       = coalesce_zero(severity_counts["pass"]),
    soft_flag_count  = coalesce_zero(severity_counts["soft"]),
    hard_fail_count  = coalesce_zero(severity_counts["hard"]),
    overall_status   = if ((coalesce_zero(severity_counts["hard"])) > 0) "FAIL" else "PASS"
  )

  entry_json <- toJSON(entry, auto_unbox = TRUE, null = "null")
  cat(entry_json, "\n", file = verify_config$audit_log, append = TRUE)
  entry
}

# ---------------------------------------------------------------------------
# Reporting
# ---------------------------------------------------------------------------

print_results <- function(results) {
  cat("\n==================== Verification Report ====================\n")
  results_tbl <- tibble(
    framework = results$framework,
    check     = results$check,
    severity  = results$severity,
    message   = results$message
  )

  severities <- c("hard", "soft", "pass")
  for (sev in severities) {
    subset <- results_tbl |> filter(severity == sev)
    if (nrow(subset) == 0) next

    cat(sprintf("\n--- %s (%d) ---\n",
                toupper(switch(sev, hard = "HARD FAILURES", soft = "SOFT FLAGS", pass = "PASSES")),
                nrow(subset)))
    for (i in seq_len(nrow(subset))) {
      cat(sprintf("  [%s | %-30s] %s\n",
                  subset$framework[i], subset$check[i], subset$message[i]))
    }
  }
  cat("\n=============================================================\n")
  invisible(results_tbl)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== Ingestion Verification ===")

  if (!file.exists(verify_config$invariants_file)) {
    stop("Invariants file missing: ", verify_config$invariants_file)
  }
  invariants <- read_yaml(verify_config$invariants_file)

  # The invariants file is the declaration of what counts as a pipeline
  # framework, so derive the check list from it rather than scanning
  # data/raw/ for directories. data/raw/ also accumulates STAGING dirs --
  # crosswalk sources with no assemble_*() adapter, candidate
  # frameworks held pending a licensing answer (asd, ukcsc), and data
  # acquired ahead of an ingest step. Those legitimately
  # have no declared invariants; scanning the directory treated each one
  # as an undeclared framework and hard-failed the build, which blocked
  # the pipeline on data that was never part of it. Declaring a framework
  # here without staging its data still fails, correctly, via the
  # provenance check below.
  frameworks <- names(invariants$frameworks)
  if (length(frameworks) == 0) {
    stop("No frameworks declared under `frameworks:` in ", verify_config$invariants_file)
  }

  raw_dirs <- list.dirs(verify_config$raw_dir, recursive = FALSE, full.names = FALSE) |>
    keep(\(f) f != "" && dir.exists(file.path(verify_config$raw_dir, f)))
  staging_only <- setdiff(raw_dirs, frameworks)

  message("Checking frameworks: ", paste(frameworks, collapse = ", "))
  if (length(staging_only) > 0) {
    message("Staging dirs present but not declared as pipeline frameworks (not verified): ",
            paste(staging_only, collapse = ", "))
  }

  results <- new_verification_result()
  for (fw in frameworks) {
    message("\n-- ", fw, " --")
    results <- verify_provenance(fw, results)
    results <- verify_counts(fw, invariants, results)
    results <- verify_text_integrity(fw, results)
    results <- verify_id_uniqueness(fw, results)
    results <- verify_verbatim_carriage(fw, results)
  }

  results_tbl <- print_results(results)
  audit_entry <- write_audit_entry(results, frameworks)

  hard_fail_count <- sum(results$severity == "hard")
  soft_flag_count <- sum(results$severity == "soft")

  message(sprintf(
    "\nSummary: %d pass, %d soft flags, %d HARD FAILURES.",
    sum(results$severity == "pass"), soft_flag_count, hard_fail_count
  ))

  if (hard_fail_count > 0) {
    message("VERIFICATION FAILED. Downstream work is blocked until hard failures are resolved.")
    quit(status = 1)
  }

  message("VERIFICATION PASSED (with ", soft_flag_count, " soft flags for review).")
  invisible(results_tbl)
}

if (sys.nframe() == 0) {
  main()
}
