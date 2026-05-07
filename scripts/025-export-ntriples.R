#!/usr/bin/env Rscript
# 025-export-ntriples.R
#
# Convert the assembled JSON-LD documents to N-Triples (.nt) for alternative
# SPARQL backends (Apache Jena Fuseki, Blazegraph, Virtuoso) and for faster
# re-parsing via rdflib (N-Triples is line-oriented, much cheaper to parse
# than JSON-LD at the same triple count).
#
# Output:
#   data/processed/ntriples/<framework>.nt   per-framework N-Triples
#   data/processed/ntriples/_combined.nt     all frameworks concatenated
#
# Prerequisites:
#   data/processed/jsonld/*.jsonld  assembled via scripts/020-assemble-jsonld.R
#
# Run: Rscript scripts/025-export-ntriples.R

suppressPackageStartupMessages({
  library(here)
  library(rdflib)
  library(purrr)
  library(glue)
})

export_config <- list(
  jsonld_dir = here("data", "processed", "jsonld"),
  nt_dir     = here("data", "processed", "ntriples"),
  frameworks = c("nice", "sfia", "dcwf", "ecsf",
                 "cyberorg-k12", "csta", "csec2017", "digcomp")
)

convert_one <- function(framework_slug) {
  jsonld_path <- file.path(export_config$jsonld_dir,
                           paste0(framework_slug, ".jsonld"))
  nt_path <- file.path(export_config$nt_dir,
                       paste0(framework_slug, ".nt"))

  if (!file.exists(jsonld_path)) {
    warning("Skipping missing JSON-LD: ", jsonld_path)
    return(NULL)
  }

  message("  ", framework_slug, " -> ", basename(nt_path))
  rdf <- rdf_parse(jsonld_path, format = "jsonld")
  rdf_serialize(rdf, nt_path, format = "ntriples")
  file.info(nt_path)$size
}

main <- function() {
  message("=== JSON-LD to N-Triples Export ===")
  dir.create(export_config$nt_dir, showWarnings = FALSE, recursive = TRUE)

  size_bytes <- export_config$frameworks |>
    set_names() |>
    map_int(\(f) {
      size <- tryCatch(convert_one(f), error = function(e) NA_integer_)
      if (is.null(size)) NA_integer_ else as.integer(size)
    })

  # Concatenate per-framework .nt files into _combined.nt
  combined_path <- file.path(export_config$nt_dir, "_combined.nt")
  per_framework_paths <- file.path(
    export_config$nt_dir,
    paste0(export_config$frameworks, ".nt")
  )
  per_framework_paths <- per_framework_paths[file.exists(per_framework_paths)]

  combined_lines <- per_framework_paths |> map(readLines) |> unlist()
  writeLines(unique(combined_lines), combined_path)

  message("\n=== Summary ===")
  for (f in names(size_bytes)) {
    if (!is.na(size_bytes[[f]])) {
      message(sprintf("  %-20s %7.1f KB", f, size_bytes[[f]] / 1024))
    }
  }
  message(sprintf("  %-20s %7.1f KB (unique triples only)",
                  "_combined",
                  file.info(combined_path)$size / 1024))
  message("\nDone.")
}

`%||%` <- function(a, b) if (is.null(a)) b else a

if (sys.nframe() == 0) {
  main()
}
