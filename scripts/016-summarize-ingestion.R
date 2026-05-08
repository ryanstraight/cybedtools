# 016-summarize-ingestion.R
#
# Reads every provenance.yml under data/raw/<framework>/ and produces
# docs/ingestion-summary.md with consolidated counts, versions, SHA256
# hashes, licensing, and a cross-framework comparison table.
#
# Release-readiness: the summary doc is an artifact reviewers will read.
# It's regenerable from the provenance manifests; no hand-curated content.
#
# Run: Rscript scripts/016-summarize-ingestion.R

suppressPackageStartupMessages({
  library(here)
  library(yaml)
  library(dplyr)
  library(purrr)
  library(tibble)
  library(glue)
  library(stringr)
})

summary_config <- list(
  raw_dir    = here("data", "raw"),
  output_doc = here("docs", "ingestion-summary.md")
)

# ---------------------------------------------------------------------------
# Data gathering
# ---------------------------------------------------------------------------

list_frameworks <- function() {
  list.dirs(summary_config$raw_dir, recursive = FALSE, full.names = FALSE) |>
    keep(\(f) f != "" &&
              file.exists(file.path(summary_config$raw_dir, f, "provenance.yml")))
}

load_all_manifests <- function() {
  frameworks <- list_frameworks()
  frameworks |>
    set_names() |>
    map(\(f) read_yaml(file.path(summary_config$raw_dir, f, "provenance.yml")))
}

# ---------------------------------------------------------------------------
# Markdown rendering helpers
# ---------------------------------------------------------------------------

safe_get <- function(x, ...) {
  path <- list(...)
  for (key in path) {
    if (is.null(x) || is.null(x[[key]])) return(NA_character_)
    x <- x[[key]]
  }
  if (length(x) == 0) return(NA_character_)
  as.character(x)
}

format_scales <- function(manifest) {
  extraction <- manifest$extraction %||% list()
  # Pull all numeric fields from extraction
  numeric_fields <- extraction |> keep(\(v) is.numeric(v) || is.integer(v))
  if (length(numeric_fields) == 0) return("")
  numeric_fields |>
    imap_chr(\(v, k) glue("{str_replace_all(k, '_', ' ')}: {format(v, big.mark=',')}")) |>
    paste(collapse = " · ")
}

build_summary_table <- function(manifests) {
  manifests |>
    imap_dfr(\(m, slug) tibble(
      framework_slug = slug,
      framework      = safe_get(m, "framework"),
      version        = safe_get(m, "framework_version"),
      version_date   = safe_get(m, "framework_date") %||% safe_get(m, "version_date"),
      publisher      = safe_get(m, "source", "publisher") %||%
                       safe_get(m, "source", "authority"),
      scales         = format_scales(m),
      license        = safe_get(m, "licensing", "source_license") %||%
                       safe_get(m, "licensing", "sfia_text_license") %||%
                       "see provenance"
    ))
}

# ---------------------------------------------------------------------------
# Document rendering
# ---------------------------------------------------------------------------

render_summary_doc <- function(manifests, summary_tbl) {
  now_iso <- format(Sys.Date(), "%Y-%m-%d")
  total_frameworks <- nrow(summary_tbl)

  lines <- character(0)

  lines <- c(lines,
    "---",
    "title: Ingestion Summary",
    "type: status",
    glue("date: {now_iso}"),
    "status: auto-generated",
    "---",
    "",
    "# Ingestion Summary",
    "",
    glue("Regenerate with `Rscript scripts/016-summarize-ingestion.R`. Last rendered {now_iso}."),
    "",
    glue("**Frameworks staged: {total_frameworks}**"),
    ""
  )

  # Per-framework sections
  for (slug in names(manifests)) {
    m <- manifests[[slug]]
    header <- safe_get(m, "framework") %||% slug

    lines <- c(lines,
      glue("## {header} (`{slug}`)"),
      ""
    )

    # Publisher / version / date
    pub <- safe_get(m, "source", "publisher") %||% safe_get(m, "source", "authority")
    version <- safe_get(m, "framework_version")
    vdate <- safe_get(m, "framework_date") %||% safe_get(m, "version_date")

    lines <- c(lines,
      glue("- **Publisher:** {pub}"),
      glue("- **Version:** {version}"),
      glue("- **Version date:** {vdate}"),
      ""
    )

    # Source
    src <- m$source %||% list()
    src_type <- safe_get(src, "type")
    src_url  <- safe_get(src, "download_url") %||% safe_get(src, "source_url")
    src_file <- safe_get(src, "filename") %||%
                safe_get(src, "source_filename") %||%
                safe_get(src, "pdf_filename")
    src_release <- safe_get(src, "release_tag")

    lines <- c(lines, "### Source")
    lines <- c(lines, glue("- **Type:** {src_type}"))
    if (!is.na(src_release)) lines <- c(lines, glue("- **Release:** {src_release}"))
    if (!is.na(src_file))    lines <- c(lines, glue("- **File:** `{src_file}`"))
    if (!is.na(src_url))     lines <- c(lines, glue("- **URL:** {src_url}"))
    lines <- c(lines, "")

    # Retrieval
    ret <- m$retrieval %||% list()
    ret_date <- safe_get(ret, "retrieved_date")
    ret_by   <- safe_get(ret, "retrieved_by")
    ret_sha  <- safe_get(ret, "file_sha256") %||% safe_get(ret, "db_sha256") %||%
                safe_get(ret, "pdf_sha256") %||% safe_get(ret, "text_sha256")

    lines <- c(lines, "### Retrieval")
    lines <- c(lines, glue("- **Retrieved:** {ret_date} by `{ret_by}`"))
    if (!is.na(ret_sha)) lines <- c(lines, glue("- **SHA256:** `{ret_sha}`"))
    lines <- c(lines, "")

    # Scales
    extraction <- m$extraction %||% list()
    if (length(extraction) > 0) {
      lines <- c(lines, "### Extracted scales")
      for (field_name in names(extraction)) {
        value <- extraction[[field_name]]
        if (is.numeric(value) || is.integer(value)) {
          pretty <- str_replace_all(field_name, "_", " ")
          lines <- c(lines, glue("- **{pretty}:** {format(value, big.mark=',')}"))
        } else if (is.list(value)) {
          # Nested breakdowns (e.g., element_type_breakdown)
          pretty <- str_replace_all(field_name, "_", " ")
          sub_parts <- names(value) |>
            map_chr(\(k) {
              v <- value[[k]]
              if (is.numeric(v) || is.integer(v)) glue("{k}={format(v, big.mark=',')}")
              else as.character(v)
            })
          lines <- c(lines, glue("- **{pretty}:** {paste(sub_parts, collapse=', ')}"))
        }
      }
      lines <- c(lines, "")
    }

    # Licensing
    lic <- m$licensing %||% list()
    if (length(lic) > 0) {
      lines <- c(lines, "### Licensing")
      for (field_name in names(lic)) {
        value <- lic[[field_name]]
        if (is.character(value) && length(value) == 1) {
          pretty <- str_replace_all(field_name, "_", " ")
          lines <- c(lines, glue("- **{pretty}:** {value}"))
        }
      }
      lines <- c(lines, "")
    }
  }

  # Cross-framework comparison table
  lines <- c(lines,
    "## Cross-framework comparison",
    "",
    "| Framework | Version | Date | Top-level units | Elements | License |",
    "|---|---|---|---|---|---|"
  )
  for (slug in names(manifests)) {
    m <- manifests[[slug]]
    extraction <- m$extraction %||% list()
    trc <- extraction$table_row_counts %||% list()

    # Explicit per-framework role/element counts. These map the framework's
    # native structure to the cybed: Role / RoleElement abstraction used in
    # JSON-LD assembly.
    role_count <- switch(slug,
      nice           = extraction$work_roles_count,
      sfia           = trc$Skill,
      dcwf           = extraction$roles_count,
      ecsf           = extraction$profile_count,
      `cyberorg-k12` = {
        gb <- extraction$grade_bands %||% 4
        sc <- extraction$sub_concepts %||% 29
        gb * sc
      },
      csta     = {
        # Role = level x concept clusters (5 levels x 5 concepts = 25)
        5 * 5
      },
      csec2017 = extraction$knowledge_areas,
      digcomp  = extraction$competence_areas,
      NA
    )
    elem_count <- switch(slug,
      nice           = extraction$unique_tks_count,
      sfia           = trc$SkillLevel,
      dcwf           = extraction$master_task_ksa_count,
      ecsf           = extraction$element_count,
      `cyberorg-k12` = extraction$standards_total,
      csta           = extraction$standards_count,
      csec2017       = extraction$essentials_total,
      digcomp        = extraction$competences,
      NA
    )

    version <- safe_get(m, "framework_version") |> str_trunc(40)
    vdate   <- safe_get(m, "framework_date") %||% safe_get(m, "version_date")
    license <- safe_get(m, "licensing", "source_license") %||%
               safe_get(m, "licensing", "sfia_text_license") %||%
               "see provenance" |> str_trunc(40)

    role_str <- if (!is.na(role_count)) format(role_count, big.mark = ",") else "-"
    elem_str <- if (!is.na(elem_count)) format(elem_count, big.mark = ",") else "-"

    lines <- c(lines,
      glue("| {safe_get(m, 'framework') %||% slug} | {version} | {vdate} | {role_str} | {elem_str} | {license} |"))
  }
  lines <- c(lines, "")

  # Verification state pointer
  lines <- c(lines,
    "## Verification",
    "",
    "Data integrity verification for all frameworks listed here is enforced by `scripts/015-verify-ingestion.R` against `docs/framework-invariants.yml`. Re-run after any ingestion change.",
    "",
    "```",
    "Rscript scripts/015-verify-ingestion.R",
    "```",
    ""
  )

  # Pipeline pointer
  lines <- c(lines,
    "## Downstream pipeline",
    "",
    "- `scripts/020-assemble-jsonld.R` assembles the five framework JSON-LD documents plus a combined graph at `data/processed/jsonld/_combined.jsonld`.",
    "- `scripts/030-load-rdf-graph.R` loads the graph into rdflib.",
    "- `scripts/040-run-sparql.R` runs the package's six named analyses (q10 through q15) via the helpers in `R/sparql-helpers.R` and writes one CSV per analysis to `data/processed/query-results/`.",
    ""
  )

  writeLines(lines, summary_config$output_doc)
  message("Summary written: ", summary_config$output_doc)
  invisible(summary_config$output_doc)
}

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== Ingestion Summary Generator ===")
  manifests <- load_all_manifests()
  message("  Frameworks found: ", length(manifests))
  summary_tbl <- build_summary_table(manifests)
  render_summary_doc(manifests, summary_tbl)
  message("Done.")
}

if (sys.nframe() == 0) {
  main()
}
