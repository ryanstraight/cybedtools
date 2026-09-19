#!/usr/bin/env Rscript
# 026-verify-graph.R
#
# Graph-level verification. Runs after assembly (020) and the N-Triples
# export (025), and before the public data release (030).
#
# scripts/015-verify-ingestion.R checks the staged CSVs, which is everything
# that can be checked before an IRI exists. Two classes of defect only become
# visible once the graph is assembled, and this stage is where they are
# caught:
#
#   Identity. An IRI that is both an organizing unit and a statement, or a
#   cybed:hasElement triple pointing at its own subject. Both mean a
#   framework numbered its units and its statements out of one id space and
#   two different things fused into one node.
#
#   Declared counts. The graph_invariants block of
#   docs/framework-invariants.yml states what the assembled graph should
#   hold, per framework and in total. Those are outputs of the pipeline, so
#   no earlier stage can enforce them.
#
# Both are HARD failures. There is no soft flag here and no per-framework
# exemption list: a framework that would need one needs a unit_iri_prefix
# instead.
#
# Prerequisites:
#   data/processed/ntriples/_combined.nt  written by scripts/025-export-ntriples.R
#
# Run: Rscript scripts/026-verify-graph.R

suppressPackageStartupMessages({
  library(here)
})

if (requireNamespace("pkgload", quietly = TRUE) && file.exists(here("DESCRIPTION"))) {
  pkgload::load_all(here(), quiet = TRUE)
} else {
  library(cybedtools)
}

main <- function() {
  message("=== Graph verification ===")

  graph_path <- here("data", "processed", "ntriples", "_combined.nt")
  message("Graph: ", graph_path)
  rdf <- load_combined_ntriples_graph(graph_path)

  message("\n-- Identity --")
  assert_graph_identity(rdf)
  message("  no unit is its own statement, no cybed:hasElement self-loops")

  message("\n-- Declared counts --")
  measured <- assert_graph_invariants(
    rdf,
    invariants_path = here("docs", "framework-invariants.yml")
  )

  combined <- measured[measured$scope == "combined", , drop = FALSE]
  for (i in seq_len(nrow(combined))) {
    message(sprintf("  %-32s %8s", combined$measure[[i]],
                    format(combined$value[[i]])))
  }

  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
