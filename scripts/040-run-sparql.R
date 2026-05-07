# 040-run-sparql.R
#
# Runs the package's named analytical queries (q10 through q15) against
# the assembled multi-framework RDF graph and writes one CSV per query to
# data/processed/query-results/.
#
# Design discipline. The librdf backend that rdflib wraps exhibits both
# performance hangs and silent zero-row results on conjunctive triple
# patterns at this graph's scale. The package's queries therefore use
# single basic graph patterns (one triple match per SPARQL call) and do
# joins, filtering, and aggregation in R via dplyr. The single-BGP
# primitives and the domain-level helpers that compose them live in
# R/sparql-helpers.R.
#
# Run: Rscript scripts/040-run-sparql.R

suppressPackageStartupMessages({
  library(here)
  library(rdflib)
  library(dplyr)
  library(readr)
  library(tibble)
  library(purrr)
})

source(here("R", "sparql-helpers.R"))

runner_config <- list(
  results_dir = here("data", "processed", "query-results"),
  combined_nt = here("data", "processed", "ntriples", "_combined.nt")
)

`%||%` <- function(a, b) if (is.null(a)) b else a

# Each entry is a named analytical query. The fn produces a tibble that is
# written to data/processed/query-results/<query_id>.csv. Adding a new
# named analysis is a matter of writing a helper in R/sparql-helpers.R and
# adding an entry below.
analyses <- list(
  list(
    query_id = "q10-roles-per-framework",
    description = "Per-framework count of cybed:Role nodes whose partOf target is a Framework.",
    fn = function(rdf) {
      role_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "role_count")
    }
  ),
  list(
    query_id = "q11-elements-per-framework",
    description = "Per-framework count of cybed:RoleElement nodes whose partOf target is a Framework.",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "element_count")
    }
  ),
  list(
    query_id = "q12-framework-metadata",
    description = "Framework name, jurisdiction, sector, and specificity per framework.",
    fn = function(rdf) {
      framework_metadata(rdf) |>
        select(framework_name = name, jurisdiction, sector, specificity) |>
        arrange(jurisdiction, framework_name)
    }
  ),
  list(
    query_id = "q13-elements-by-jurisdiction",
    description = "Element count per jurisdiction (joined via per-framework metadata).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        left_join(
          framework_metadata(rdf) |> transmute(framework, jurisdiction),
          by = "framework"
        ) |>
        count(jurisdiction, name = "element_count") |>
        arrange(desc(element_count))
    }
  ),
  list(
    query_id = "q14-elements-by-sector",
    description = "Element count per sector (joined via per-framework metadata).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        left_join(
          framework_metadata(rdf) |> transmute(framework, sector),
          by = "framework"
        ) |>
        count(sector, name = "element_count") |>
        arrange(desc(element_count))
    }
  ),
  list(
    query_id = "q15-largest-roles",
    description = "Top 20 roles by element count, with framework attribution.",
    fn = function(rdf) {
      reb <- role_element_bindings(rdf)
      rfb <- role_framework_bindings(rdf)
      reb |>
        count(role, name = "element_count") |>
        left_join(
          rfb |> select(role, role_name, framework_name),
          by = "role"
        ) |>
        arrange(desc(element_count)) |>
        slice_head(n = 20) |>
        select(framework_name, role_name, element_count, role)
    }
  )
)

run_one <- function(entry, rdf) {
  message(sprintf("  Running %s...", entry$query_id))
  t0 <- Sys.time()
  result <- tryCatch(
    entry$fn(rdf),
    error = function(e) {
      message(sprintf("    Error: %s", conditionMessage(e)))
      NULL
    }
  )
  dt <- as.numeric(Sys.time() - t0, units = "secs")
  if (is.null(result)) {
    return(list(query_id = entry$query_id, rows = NA_integer_, status = "error",
                seconds = dt))
  }
  out_path <- file.path(runner_config$results_dir, paste0(entry$query_id, ".csv"))
  write_csv(result, out_path)
  message(sprintf("    %d rows written to %s (%.2fs)",
                  nrow(result), out_path, dt))
  list(query_id = entry$query_id, rows = nrow(result), status = "ok",
       seconds = dt)
}

main <- function() {
  message("=== Analytical query runner ===")
  dir.create(runner_config$results_dir, showWarnings = FALSE, recursive = TRUE)

  if (!file.exists(runner_config$combined_nt)) {
    message("  Combined N-Triples missing. Running scripts/025-export-ntriples.R...")
    rc <- system2("Rscript",
                  args = c(here("src", "025-export-ntriples.R")),
                  stdout = "", stderr = "")
    if (rc != 0 || !file.exists(runner_config$combined_nt)) {
      stop("Failed to produce combined N-Triples at ", runner_config$combined_nt)
    }
  }

  message("Loading combined N-Triples graph...")
  rdf <- rdflib::rdf_parse(runner_config$combined_nt, format = "ntriples")
  message("  graph loaded.")

  message(sprintf("\nRunning %d analyses...\n", length(analyses)))
  results <- map(analyses, ~run_one(.x, rdf))

  summary_tbl <- tibble(
    query_id = map_chr(results, "query_id"),
    rows     = map_dbl(results, \(r) r$rows %||% NA_real_),
    status   = map_chr(results, "status"),
    seconds  = map_dbl(results, \(r) r$seconds %||% NA_real_)
  )

  message("\n=== Summary ===")
  print(summary_tbl)
  write_csv(summary_tbl, file.path(runner_config$results_dir, "_run-summary.csv"))

  message("\nDone.")
  invisible(summary_tbl)
}

if (sys.nframe() == 0) {
  main()
}
