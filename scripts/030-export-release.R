#!/usr/bin/env Rscript
# 030-export-release.R
#
# Build the public per-framework data release from the N-Triples written by
# scripts/025-export-ntriples.R.
#
# One file per framework, never a combined public file. The frameworks carry
# different licences and several of those licences cannot be merged: a
# share-alike term on one framework would propagate across a combined file,
# and some frameworks may not be licensed onward at all. A reader who wants a
# combined graph merges the files locally, where each file's own terms still
# apply to its own triples.
#
# Two independent gates govern every file, and both fail closed:
#
#   Policy. public_redistribution in docs/framework-invariants.yml, read
#   through the table concordance/_publication-guard.R already declares. An
#   unrecognised value, an unmapped framework, or local_only stops the export.
#
#   Allowlist. docs/data-release.yml names the frameworks this release ships.
#   A framework the policy would permit still gets no file until its slug is
#   listed there.
#
# Output:
#   data/processed/release/<version>/<slug>.nt.gz   per-framework N-Triples
#   data/processed/release/<version>/manifest.json  hashes, counts, terms
#   data/processed/release/<version>/README.md      the same facts for a reader
#
# data/processed/ is gitignored. Nothing this stage writes is committed.
#
# Prerequisites:
#   data/processed/ntriples/*.nt  written by scripts/025-export-ntriples.R
#
# Run: Rscript scripts/030-export-release.R
#      Rscript scripts/030-export-release.R --out-dir=<directory>
#
# The --out-dir switch writes the release somewhere other than the default, so
# two runs can be compared byte for byte. It changes nothing else.

suppressPackageStartupMessages({
  library(here)
  library(rlang)
  library(digest)
  library(jsonlite)
  library(yaml)
})

if (requireNamespace("pkgload", quietly = TRUE) && file.exists(here("DESCRIPTION"))) {
  pkgload::load_all(here(), quiet = TRUE)
} else {
  library(cybedtools)
}

source(here("scripts", "_release-common.R"), local = TRUE)
source(here("concordance", "_publication-guard.R"), local = TRUE)

release_config <- list(
  config_path = here("docs", "data-release.yml"),
  nt_dir      = here("data", "processed", "ntriples"),
  release_dir = here("data", "processed", "release"),
  frameworks  = c("nice", "sfia", "dcwf", "ecsf",
                  "cyberorg-k12", "csta", "csec2017", "digcomp",
                  "cyqual", "ccssf", "otccf")
)

rdf_type_iri <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
framework_class_iri <- "https://w3id.org/cybed/ontology#Framework"
schema_version_iri <- "http://schema.org/version"

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------

resolve_out_dir <- function(config, args = commandArgs(trailingOnly = TRUE)) {
  override <- args[startsWith(args, "--out-dir=")]
  if (length(override)) {
    return(file.path(sub("^--out-dir=", "", override[[length(override)]]),
                     config$release_version))
  }
  file.path(release_config$release_dir, config$release_version)
}

read_framework_lines <- function(slug) {
  path <- file.path(release_config$nt_dir, paste0(slug, ".nt"))
  if (!file.exists(path)) {
    abort(
      c(
        "A framework's N-Triples file is missing.",
        "x" = paste0("Expected: ", path, "."),
        "i" = "Run scripts/025-export-ntriples.R first."
      ),
      class = "cybedtools_release_input",
      framework_slug = slug
    )
  }
  readLines(path, warn = FALSE)
}

# ---------------------------------------------------------------------------
# Reconciliation
# ---------------------------------------------------------------------------

# The eleven per-framework documents partition the combined graph. The
# assembler builds the combined document by concatenating the same node lists
# it wrote per framework, so the union of the eleven files should equal the
# combined file exactly. Checking it here is what makes the per-framework files
# a safe source for the release: a triple present only in the combined graph
# would be a triple no framework file carries, and it would ship nowhere.
reconcile_partition <- function(per_framework) {
  combined_path <- file.path(release_config$nt_dir, "_combined.nt")
  if (!file.exists(combined_path)) {
    abort(
      c(
        "The combined N-Triples file is missing.",
        "x" = paste0("Expected: ", combined_path, "."),
        "i" = "Run scripts/025-export-ntriples.R first."
      ),
      class = "cybedtools_release_input"
    )
  }

  combined <- canonical_lines(readLines(combined_path, warn = FALSE))
  union_lines <- canonical_lines(unlist(per_framework, use.names = FALSE))

  only_combined <- setdiff(combined, union_lines)
  only_union <- setdiff(union_lines, combined)

  message("\n-- Reconciliation --")
  message(sprintf("  combined graph:            %8d triples", length(combined)))
  message(sprintf("  union of %2d framework sets: %8d triples",
                  length(per_framework), length(union_lines)))
  message(sprintf("  in combined only:          %8d triples", length(only_combined)))
  message(sprintf("  in framework files only:   %8d triples", length(only_union)))

  if (length(only_union)) {
    abort(
      c(
        "A triple in a per-framework file is absent from the combined graph.",
        "x" = paste0(length(only_union), " triple(s) differ."),
        "i" = "The two exports disagree. Rebuild both before releasing."
      ),
      class = "cybedtools_release_reconciliation"
    )
  }

  only_combined
}

# Shared vocabulary triples are triples the combined graph carries that no
# framework file carries: the cybed: schema asserted as data rather than
# described in documentation. They are the package's own work, so they would
# ship under the package's own terms rather than any framework's.
write_vocabulary_file <- function(vocabulary_lines, out_dir) {
  if (!length(vocabulary_lines)) {
    message("  shared vocabulary triples: none in the graph, no file written")
    return(NULL)
  }
  write_release_file(vocabulary_lines, "cybed-vocabulary", out_dir)
}

# ---------------------------------------------------------------------------
# Writing
# ---------------------------------------------------------------------------

write_release_file <- function(lines, slug, out_dir) {
  lines <- canonical_lines(lines)
  payload <- canonical_payload(lines)
  compressed <- gzip_bytes(payload)

  file_name <- paste0(slug, ".nt.gz")
  writeBin(compressed, file.path(out_dir, file_name))

  list(
    slug = slug,
    file = file_name,
    triples = length(lines),
    bytes = length(compressed),
    bytes_uncompressed = length(payload),
    sha256 = digest(compressed, algo = "sha256", serialize = FALSE),
    sha256_uncompressed = digest(payload, algo = "sha256", serialize = FALSE)
  )
}

framework_entry <- function(slug, lines, config, policy, licenses, out_dir) {
  policy_value <- policy$policy[match(slug, policy$framework_slug)]
  scope <- release_scope(policy_value)
  license_row <- release_license_row(licenses, slug)

  framework_iri <- nt_subjects_of_type(lines, framework_class_iri)
  if (length(framework_iri) != 1L) {
    abort(
      c(
        "A framework file does not declare exactly one framework node.",
        "x" = paste0("Slug: ", slug, ", nodes found: ", length(framework_iri), ".")
      ),
      class = "cybedtools_release_input",
      framework_slug = slug
    )
  }
  source_version <- nt_literal_of(lines, framework_iri, schema_version_iri)

  omitted <- character(0)
  if (identical(scope, "structure_only")) {
    omitted <- as.character(config$structure_only_omit_predicates)
    lines <- strip_text_predicates(lines, omitted)
    assert_no_long_literals(
      lines,
      threshold = as.integer(config$long_literal_threshold),
      allow_predicates = as.character(config$long_literal_allow_predicates),
      slug = slug
    )
  }

  written <- write_release_file(lines, slug, out_dir)

  attribution <- license_row$attribution[[1L]]
  entry <- list(
    slug = slug,
    framework_id = framework_iri,
    framework_name = license_row$framework_name[[1L]],
    framework_version = source_version,
    license_slug = license_row$slug[[1L]],
    file = written$file,
    bytes = as.integer(written$bytes),
    bytes_uncompressed = as.integer(written$bytes_uncompressed),
    sha256 = written$sha256,
    sha256_uncompressed = written$sha256_uncompressed,
    triples = as.integer(written$triples),
    scope = scope,
    redistribution = policy_value,
    licence_short = license_row$license_short[[1L]],
    licence = license_row$license[[1L]],
    attribution = if (is.na(attribution)) NULL else attribution,
    terms_url = license_row$terms_url[[1L]]
  )
  if (length(omitted)) {
    entry$omitted_predicates <- omitted
  }
  entry
}

# ---------------------------------------------------------------------------
# Manifest and README
# ---------------------------------------------------------------------------

named_reasons <- function(entries) {
  if (!length(entries)) {
    return(list())
  }
  lapply(names(entries), function(slug) {
    list(slug = slug, reason = as.character(entries[[slug]]))
  })
}

build_manifest <- function(config, files, vocabulary) {
  manifest <- list(
    manifest_version = "1",
    release_version = as.character(config$release_version),
    release_date = as.character(config$release_date),
    graph_schema_version = as.character(config$graph_schema_version),
    vocabulary_iri = as.character(config$vocabulary_iri),
    software_concept_doi = as.character(config$concept_doi),
    built_by = list(
      package = "cybedtools",
      version = as.character(utils::packageVersion("cybedtools"))
    ),
    files = files,
    held = named_reasons(config$held),
    refused = named_reasons(config$refused)
  )
  if (!is.null(vocabulary)) {
    manifest$vocabulary_file <- list(
      file = vocabulary$file,
      bytes = as.integer(vocabulary$bytes),
      bytes_uncompressed = as.integer(vocabulary$bytes_uncompressed),
      sha256 = vocabulary$sha256,
      sha256_uncompressed = vocabulary$sha256_uncompressed,
      triples = as.integer(vocabulary$triples),
      licence_short = "MIT"
    )
  }
  manifest
}

build_readme <- function(config, files) {
  scope_sentence <- function(entry) {
    if (identical(entry$scope, "structure_only")) {
      paste(
        "Structure only. Names, titles, categories, levels, section headings",
        "and mappings are present. The framework's own statement text and",
        "descriptions are not."
      )
    } else {
      "Full. Every triple the harmonised graph holds for this framework."
    }
  }

  sections <- vapply(files, function(entry) {
    attribution <- if (is.null(entry$attribution)) {
      "The steward prescribes no attribution wording."
    } else {
      paste0("Attribution, to be reproduced verbatim: ", entry$attribution)
    }
    paste(
      paste0("### ", entry$framework_name),
      "",
      paste0("File: `", entry$file, "`. ", entry$triples, " triples, ",
             entry$bytes, " bytes compressed, ",
             entry$bytes_uncompressed, " bytes uncompressed."),
      "",
      paste0("Scope: ", scope_sentence(entry)),
      "",
      paste0("Terms: ", entry$licence_short, ". ", entry$licence),
      "",
      attribution,
      "",
      paste0("Terms page: <", entry$terms_url, ">"),
      "",
      paste0("SHA-256 of the compressed file: `", entry$sha256, "`."),
      paste0("SHA-256 of the uncompressed N-Triples: `",
             entry$sha256_uncompressed, "`."),
      sep = "\n"
    )
  }, character(1))

  held <- config$held %||% list()
  refused <- config$refused %||% list()
  withheld_lines <- c(
    vapply(names(held), function(slug) {
      paste0("- ", slug, ": held from this release. ", as.character(held[[slug]]))
    }, character(1)),
    vapply(names(refused), function(slug) {
      paste0("- ", slug, ": not distributed. ", as.character(refused[[slug]]))
    }, character(1))
  )

  paste(
    paste0("# cybedtools data release ", config$release_version),
    "",
    paste0("Released ", config$release_date, ". Graph vocabulary version ",
           config$graph_schema_version, ", at <", config$vocabulary_iri, ">."),
    "",
    paste("This release publishes one harmonised RDF graph file per framework.",
          "Each file is gzip-compressed N-Triples, sorted bytewise, with",
          "duplicate lines removed, LF line endings and a zeroed gzip header,",
          "so the same input produces the same bytes on any machine. The",
          "hashes below identify the exact files."),
    "",
    "## Why there is no combined file",
    "",
    paste("The frameworks carry different licences and those licences cannot",
          "be merged. One framework in this release is share-alike, so a",
          "combined file would propagate that obligation across frameworks",
          "whose publishers never agreed to it. Other frameworks may not be",
          "redistributed at all, and a combined file would make their absence",
          "invisible. Merging the files locally keeps each set of triples",
          "under the terms its own publisher set, and that is the merge this",
          "release supports."),
    "",
    "## Loading the files",
    "",
    "In R, with rdflib:",
    "",
    "```r",
    "library(rdflib)",
    "graph <- rdf()",
    "for (path in list.files(\".\", pattern = \"[.]nt[.]gz$\", full.names = TRUE)) {",
    "  rdf_parse(path, rdf = graph, format = \"ntriples\")",
    "}",
    "```",
    "",
    "In Python, with rdflib:",
    "",
    "```python",
    "import glob, gzip",
    "import rdflib",
    "",
    "graph = rdflib.Graph()",
    "for path in sorted(glob.glob(\"*.nt.gz\")):",
    "    with gzip.open(path, \"rb\") as handle:",
    "        graph.parse(handle, format=\"nt\")",
    "```",
    "",
    "## Files",
    "",
    paste(sections, collapse = "\n\n"),
    "",
    "## Frameworks not in this release",
    "",
    paste(withheld_lines, collapse = "\n"),
    "",
    "## How to cite",
    "",
    paste0("Cite the software by its concept DOI, ", config$concept_doi,
           ", and cite this data release by its own record. Cite each",
           " framework's publisher as that framework's terms require. The",
           " attribution wording above is the steward's own where one is",
           " prescribed. Where none is, it names the title, publisher, source",
           " and licence, which is what the licence asks for."),
    "",
    sep = "\n"
  )
}

# ---------------------------------------------------------------------------
# Self-verification
# ---------------------------------------------------------------------------

# Nothing published here is retractable, so the stage re-reads what it wrote
# and checks it against the manifest rather than trusting the write.
verify_written <- function(manifest, out_dir) {
  entries <- manifest$files
  if (!is.null(manifest$vocabulary_file)) {
    entries <- c(entries, list(manifest$vocabulary_file))
  }

  for (entry in entries) {
    path <- file.path(out_dir, entry$file)
    compressed <- readBin(path, "raw", file.size(path))
    if (!identical(digest(compressed, algo = "sha256", serialize = FALSE),
                   entry$sha256)) {
      abort(
        c(
          "A written file does not match its manifest hash.",
          "x" = paste0("File: ", entry$file, ".")
        ),
        class = "cybedtools_release_verification"
      )
    }
    connection <- gzfile(path, "rb")
    payload <- readBin(connection, "raw", entry$bytes_uncompressed + 1L)
    close(connection)
    if (!identical(digest(payload, algo = "sha256", serialize = FALSE),
                   entry$sha256_uncompressed)) {
      abort(
        c(
          "A written file decompresses to something other than the hashed payload.",
          "x" = paste0("File: ", entry$file, ".")
        ),
        class = "cybedtools_release_verification"
      )
    }
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== Public data release export ===")

  config <- read_yaml(release_config$config_path)
  out_dir <- resolve_out_dir(config)
  message("Release version: ", config$release_version)
  message("Output: ", out_dir)

  policy <- publication_policy()
  assert_release_allowlist(config, policy)
  licenses <- cybedtools::framework_licenses

  per_framework <- lapply(release_config$frameworks, function(slug) {
    canonical_lines(read_framework_lines(slug))
  })
  names(per_framework) <- release_config$frameworks

  vocabulary_lines <- reconcile_partition(per_framework)

  # Only create the directory once every gate has passed, so a refusal leaves
  # no partial release behind.
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  message("\n-- Files --")
  vocabulary <- write_vocabulary_file(vocabulary_lines, out_dir)

  shipped <- as.character(config$shipped)
  files <- lapply(shipped, function(slug) {
    entry <- framework_entry(slug, per_framework[[slug]], config, policy,
                             licenses, out_dir)
    message(sprintf("  %-14s %6d triples  %8d bytes  %s",
                    entry$slug, entry$triples, entry$bytes, entry$scope))
    entry
  })

  manifest <- build_manifest(config, files, vocabulary)
  writeBin(
    charToRaw(manifest_json(manifest)),
    file.path(out_dir, "manifest.json")
  )
  writeBin(
    charToRaw(build_readme(config, files)),
    file.path(out_dir, "README.md")
  )

  verify_written(manifest, out_dir)

  message("\n=== Summary ===")
  message(sprintf("  %d framework file(s) written", length(files)))
  message(sprintf("  %d held, %d refused",
                  length(config$held %||% list()),
                  length(config$refused %||% list())))
  message("  manifest.json and README.md written and verified against the files")
  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
