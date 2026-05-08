# 040-run-sparql.R
#
# Runs the package's named analytical queries (q10 through q16) against
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

# Load helpers from the in-tree package source when running from a working
# tree, otherwise fall back to the installed cybedtools.
if (requireNamespace("pkgload", quietly = TRUE) && file.exists(here("DESCRIPTION"))) {
  pkgload::load_all(here(), quiet = TRUE)
} else {
  library(cybedtools)
}

runner_config <- list(
  results_dir = here("data", "processed", "query-results"),
  combined_nt = here("data", "processed", "ntriples", "_combined.nt")
)

`%||%` <- function(a, b) if (is.null(a)) b else a

# Each entry is a named analytical query. The fn produces a tibble that
# is written to data/processed/query-results/<query_id>.csv. Adding a new
# named analysis is a matter of writing a helper in R/sparql-helpers.R
# and adding an entry below.
#
# Under v0.2.0 the cross-framework cuts (q10, q11, q15) target
# cybed:OrganizingUnit so all eight frameworks contribute. The
# workforce-restricted variants (q10b) target cybed:Role and return only
# NICE / DCWF / ECSF. The strict element count (q11) excludes
# cybed:Example instances; the inclusive variant (q11b) includes them.
analyses <- list(
  list(
    query_id    = "q10-organizing-units-per-framework",
    description = "Per-framework count of cybed:OrganizingUnit nodes (cross-framework parent count).",
    fn = function(rdf) {
      organizing_unit_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "organizing_unit_count")
    }
  ),
  list(
    query_id    = "q10b-roles-per-framework",
    description = "Per-framework count of cybed:Role nodes (workforce-restricted: NICE / DCWF / ECSF).",
    fn = function(rdf) {
      role_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "role_count")
    }
  ),
  list(
    query_id    = "q11-elements-per-framework-strict",
    description = "Per-framework strict element count (parents + cybed:Subpoint, excludes cybed:Example).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        anti_join(
          example_framework_bindings(rdf) |>
            transmute(element = example),
          by = "element"
        ) |>
        count(framework_name, sort = TRUE, name = "element_count_strict")
    }
  ),
  list(
    query_id    = "q11b-elements-per-framework-with-examples",
    description = "Per-framework inclusive element count (parents + Subpoints + Examples).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "element_count_with_examples")
    }
  ),
  list(
    query_id    = "q12-framework-metadata",
    description = "Framework name, jurisdiction, sector, and specificity per framework.",
    fn = function(rdf) {
      framework_metadata(rdf) |>
        select(framework_name = name, jurisdiction, sector, specificity) |>
        arrange(jurisdiction, framework_name)
    }
  ),
  list(
    query_id    = "q13-elements-by-jurisdiction-strict",
    description = "Strict element count per jurisdiction (joined via per-framework metadata; Examples excluded).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        anti_join(
          example_framework_bindings(rdf) |>
            transmute(element = example),
          by = "element"
        ) |>
        left_join(
          framework_metadata(rdf) |> transmute(framework, jurisdiction),
          by = "framework"
        ) |>
        count(jurisdiction, name = "element_count_strict") |>
        arrange(desc(element_count_strict))
    }
  ),
  list(
    query_id    = "q14-elements-by-sector-strict",
    description = "Strict element count per sector (joined via per-framework metadata; Examples excluded).",
    fn = function(rdf) {
      element_framework_bindings(rdf) |>
        anti_join(
          example_framework_bindings(rdf) |>
            transmute(element = example),
          by = "element"
        ) |>
        left_join(
          framework_metadata(rdf) |> transmute(framework, sector),
          by = "framework"
        ) |>
        count(sector, name = "element_count_strict") |>
        arrange(desc(element_count_strict))
    }
  ),
  list(
    query_id    = "q15-largest-organizing-units",
    description = "Top 20 organizing units by element count across all eight frameworks (cross-framework).",
    fn = function(rdf) {
      reb <- role_element_bindings(rdf)
      ofb <- organizing_unit_framework_bindings(rdf)
      reb |>
        count(role, name = "element_count") |>
        left_join(
          ofb |> select(unit, unit_name, framework_name),
          by = c("role" = "unit")
        ) |>
        arrange(desc(element_count)) |>
        slice_head(n = 20) |>
        select(framework_name, unit_name, element_count, unit = role)
    }
  ),
  list(
    query_id    = "q16-examples-per-framework",
    description = "Per-framework count of cybed:Example nodes (Cyber.org K-12 + CSTA pedagogical scaffolding).",
    fn = function(rdf) {
      example_framework_bindings(rdf) |>
        count(framework_name, sort = TRUE, name = "example_count")
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
                  args = c(here("scripts", "025-export-ntriples.R")),
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
