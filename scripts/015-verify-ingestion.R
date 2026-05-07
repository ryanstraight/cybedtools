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
    csec2017 = {
      kas <- safe_read(file.path(tables_dir, "knowledge-areas.csv"))
      essentials <- safe_read(file.path(tables_dir, "essentials.csv"))
      list(
        knowledge_areas  = nrow_or_null(kas),
        essentials_total = nrow_or_null(essentials)
      )
    },
    digcomp = {
      areas <- safe_read(file.path(tables_dir, "competence-areas.csv"))
      competences <- safe_read(file.path(tables_dir, "competences.csv"))
      descs <- safe_read(file.path(tables_dir, "competence-descriptions.csv"))
      list(
        competence_areas   = nrow_or_null(areas),
        competences        = nrow_or_null(competences),
        descriptions_found = if (!is.null(descs)) sum(!is.na(descs$description)) else NULL
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
    csec2017 = list(
      list(label = "essential-text", file = "essentials.csv", column = "element_text")
    ),
    digcomp = list(
      list(label = "competence-name", file = "competences.csv", column = "competence_name")
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
    csec2017 = list(
      list(file = "knowledge-areas.csv", id_col = "ka_id",       label = "ka-id"),
      list(file = "essentials.csv",      id_col = "element_id",  label = "essential-id")
    ),
    digcomp = list(
      list(file = "competence-areas.csv", id_col = "area_id",        label = "area-id"),
      list(file = "competences.csv",      id_col = "competence_id",  label = "competence-id")
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

  frameworks <- list.dirs(verify_config$raw_dir, recursive = FALSE, full.names = FALSE) |>
    keep(\(f) f != "" && dir.exists(file.path(verify_config$raw_dir, f)))

  message("Checking frameworks: ", paste(frameworks, collapse = ", "))

  results <- new_verification_result()
  for (fw in frameworks) {
    message("\n-- ", fw, " --")
    results <- verify_provenance(fw, results)
    results <- verify_counts(fw, invariants, results)
    results <- verify_text_integrity(fw, results)
    results <- verify_id_uniqueness(fw, results)
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
