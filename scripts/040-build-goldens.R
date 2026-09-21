#!/usr/bin/env Rscript
# 040-build-goldens.R
#
# Builds the hand-authored conformance fixture (inst/conformance/fixture.nt),
# a mock release directory next to it (for cybed_fetch()/load_graph() tests),
# and one golden CSV per public API function, run against the fixture.
#
# The golden format (exact contract, restated in
# inst/conformance/README.md): UTF-8 encoding, LF line endings, one CSV per
# function, fixed column order, rows sorted by the documented sort key,
# numeric similarity scores rounded to 10 decimal places, NA written as an
# empty string (never the literal "NA").
#
# Run: Rscript scripts/040-build-goldens.R

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  library(readr)
  library(rdflib)
})

if (requireNamespace("pkgload", quietly = TRUE) && file.exists(here("DESCRIPTION"))) {
  pkgload::load_all(here(), quiet = TRUE)
} else {
  library(cybedtools)
}

conformance_dir <- here("inst", "conformance")
goldens_dir     <- file.path(conformance_dir, "goldens")
mock_release_dir <- file.path(conformance_dir, "mock-release", "1.0.0")
dir.create(goldens_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(mock_release_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. Build the fixture graph
# ---------------------------------------------------------------------------
#
# Two workforce frameworks (fixture-wf1, fixture-wf2) with roles, one
# pedagogy framework (fixture-ped1) with a Subpoint and an Example, a
# statement shared by two units (across wf1 and wf2), one unit relation, and
# non-ASCII text (accented French) on the pedagogy unit. Similarity-relevant
# text overlaps deliberately between wf1's and wf2's roles.

cybed  <- function(local) paste0("https://w3id.org/cybed/ontology#", local)
schema <- function(local) paste0("http://schema.org/", local)
RDF_TYPE <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

build_fixture_graph <- function() {
  rdf <- rdflib::rdf()
  add <- function(s, p, o) rdflib::rdf_add(rdf, s, p, o)

  fw1 <- cybed("framework/fixture-wf1")
  fw2 <- cybed("framework/fixture-wf2")
  fw3 <- cybed("framework/fixture-ped1")

  add(fw1, RDF_TYPE, cybed("Framework"))
  add(fw1, schema("name"), "Fixture Workforce Framework One")
  add(fw1, cybed("jurisdiction"), "US")
  add(fw1, cybed("sector"), "civilian")
  add(fw1, cybed("specificity"), "cybersecurity-specific")

  add(fw2, RDF_TYPE, cybed("Framework"))
  add(fw2, schema("name"), "Fixture Workforce Framework Two")
  add(fw2, cybed("jurisdiction"), "EU")
  add(fw2, cybed("sector"), "civilian")
  add(fw2, cybed("specificity"), "cybersecurity-specific")

  add(fw3, RDF_TYPE, cybed("Framework"))
  add(fw3, schema("name"), "Fixture Pedagogy Framework One")
  add(fw3, cybed("jurisdiction"), "global")
  add(fw3, cybed("sector"), "education")
  add(fw3, cybed("specificity"), "cybersecurity-specific")

  # --- wf1 roles ---
  role1 <- cybed("role/fixture-role-1")
  role2 <- cybed("role/fixture-role-2")
  for (r in c(role1, role2)) {
    add(r, RDF_TYPE, cybed("Role"))
    add(r, RDF_TYPE, cybed("OrganizingUnit"))
    add(r, cybed("partOf"), fw1)
  }
  add(role1, schema("name"), "Security Analyst")
  add(role2, schema("name"), "Network Defender")

  # --- wf2 roles ---
  role3 <- cybed("role/fixture-role-3")
  role4 <- cybed("role/fixture-role-4")
  for (r in c(role3, role4)) {
    add(r, RDF_TYPE, cybed("Role"))
    add(r, RDF_TYPE, cybed("OrganizingUnit"))
    add(r, cybed("partOf"), fw2)
  }
  add(role3, schema("name"), "Incident Handler")
  add(role4, schema("name"), "Threat Hunter")

  # --- ped1 unit (grade-band x sub-concept style cell) ---
  unit5 <- cybed("unit/fixture-unit-5")
  add(unit5, RDF_TYPE, cybed("OrganizingUnit"))
  add(unit5, cybed("partOf"), fw3)
  add(unit5, schema("name"), "Grade Band Data Protection Cell")

  # --- statement text, similarity-relevant overlap between role1 and role3 ---
  el_role1 <- cybed("element/fixture-el-role1")
  el_role2 <- cybed("element/fixture-el-role2")
  el_role3 <- cybed("element/fixture-el-role3")
  el_role4 <- cybed("element/fixture-el-role4")
  el_unit5 <- cybed("element/fixture-el-unit5")

  for (e in c(el_role1, el_role2, el_role3, el_role4, el_unit5)) {
    add(e, RDF_TYPE, cybed("RoleElement"))
  }
  add(el_role1, cybed("partOf"), fw1)
  add(el_role2, cybed("partOf"), fw1)
  add(el_role3, cybed("partOf"), fw2)
  add(el_role4, cybed("partOf"), fw2)
  add(el_unit5, cybed("partOf"), fw3)

  add(el_role1, cybed("elementText"),
      "Monitors network traffic for security incidents and analyzes alerts")
  add(el_role2, cybed("elementText"),
      "Configures firewalls and defends the network perimeter")
  add(el_role3, cybed("elementText"),
      "Monitors network traffic for incidents and coordinates incident response")
  add(el_role4, cybed("elementText"),
      "Hunts for adversaries hiding in network traffic and endpoint logs")
  add(el_unit5, cybed("elementText"),
      "Protéger les données personnelles et respecter la vie privée")

  add(role1, cybed("hasElement"), el_role1)
  add(role2, cybed("hasElement"), el_role2)
  add(role3, cybed("hasElement"), el_role3)
  add(role4, cybed("hasElement"), el_role4)
  add(unit5, cybed("hasElement"), el_unit5)

  # A statement shared by two units, across two frameworks: role2 and role4
  # both link to the same el_role1 in addition to their own text (models a
  # cross-framework alignment note without a native equivalence type).
  add(role2, cybed("hasElement"), el_role1)
  add(role4, cybed("hasElement"), el_role1)

  # --- ped1 Subpoint + Example, non-ASCII carried by the Subpoint ---
  sub1 <- cybed("element/fixture-el-unit5.sub.1")
  add(sub1, RDF_TYPE, cybed("RoleElement"))
  add(sub1, RDF_TYPE, cybed("Subpoint"))
  add(sub1, cybed("partOf"), fw3)
  add(sub1, cybed("elaborates"), el_unit5)
  add(sub1, cybed("elementText"), "chiffrement et contrôle d'accès")
  add(unit5, cybed("hasElement"), sub1)

  ex1 <- cybed("element/fixture-el-unit5.example.1")
  add(ex1, RDF_TYPE, cybed("RoleElement"))
  add(ex1, RDF_TYPE, cybed("Example"))
  add(ex1, cybed("partOf"), fw3)
  add(ex1, cybed("elementText"),
      "Clarification statement: includes GDPR-relevant scenarios")
  add(unit5, cybed("hasExample"), ex1)

  # --- one unit relation: role1 requires role3 ---
  rel1 <- cybed("relation/fixture-role-1--fixture-role-3--requires")
  add(rel1, RDF_TYPE, cybed("UnitRelation"))
  add(rel1, cybed("fromUnit"), role1)
  add(rel1, cybed("toUnit"), role3)
  add(rel1, cybed("relationLabel"), "requires")
  add(rel1, cybed("partOf"), fw1)

  rdf
}

fixture_rdf <- build_fixture_graph()
fixture_path <- file.path(conformance_dir, "fixture.nt")
rdflib::rdf_serialize(fixture_rdf, fixture_path, format = "ntriples")

# Normalize to sorted, LF, UTF-8 lines for a reproducible fixture file.
fixture_lines <- sort(unique(readLines(fixture_path, warn = FALSE, encoding = "UTF-8")))
con <- file(fixture_path, open = "wb")
writeLines(fixture_lines, con, sep = "\n", useBytes = TRUE)
close(con)

message("Fixture written: ", fixture_path, " (", length(fixture_lines), " triples)")

# ---------------------------------------------------------------------------
# 2. Build the mock release directory (manifest + gzipped per-framework files)
# ---------------------------------------------------------------------------

mock_frameworks <- c("fixture-wf1", "fixture-wf2", "fixture-ped1")
fixture_rdf_fresh <- rdflib::rdf_parse(fixture_path, format = "ntriples")

framework_lines_for <- function(slug) {
  fw_iri <- cybed(paste0("framework/", slug))
  q <- paste0(
    "PREFIX cybed: <https://w3id.org/cybed/ontology#>\n",
    sprintf("SELECT ?s ?p ?o WHERE { ?s ?p ?o . }")
  )
  # Single-BGP discipline: pull every triple, filter to this framework's
  # subjects in R (subjects sharing this framework's partOf, plus the
  # framework node itself).
  all_triples <- rdflib::rdf_query(fixture_rdf_fresh, q)
  partof <- all_triples[all_triples$p == cybed("partOf") & all_triples$o == fw_iri, "s"]
  subjects <- unique(c(fw_iri, partof))
  keep <- all_triples[all_triples$s %in% subjects, ]
  # Serialize the kept subset via a scratch in-memory graph.
  scratch <- rdflib::rdf()
  for (i in seq_len(nrow(keep))) {
    rdflib::rdf_add(scratch, keep$s[i], keep$p[i], keep$o[i])
  }
  tmp <- tempfile(fileext = ".nt")
  rdflib::rdf_serialize(scratch, tmp, format = "ntriples")
  lines <- sort(unique(readLines(tmp, warn = FALSE, encoding = "UTF-8")))
  unlink(tmp)
  lines
}

manifest_files <- lapply(mock_frameworks, function(slug) {
  lines <- framework_lines_for(slug)
  payload <- paste(lines, collapse = "\n")
  payload_bytes <- c(charToRaw(payload), as.raw(0x0a))
  gz_path <- file.path(mock_release_dir, paste0(slug, ".nt.gz"))
  con <- gzfile(gz_path, "wb")
  writeBin(payload_bytes, con)
  close(con)
  compressed_bytes <- readBin(gz_path, "raw", file.size(gz_path))
  list(
    slug = slug,
    file = paste0(slug, ".nt.gz"),
    triples = length(lines),
    bytes = length(compressed_bytes),
    bytes_uncompressed = length(payload_bytes),
    sha256 = digest::digest(compressed_bytes, algo = "sha256", serialize = FALSE),
    sha256_uncompressed = digest::digest(payload_bytes, algo = "sha256", serialize = FALSE)
  )
})

manifest <- list(
  manifest_version = "1",
  release_version = "1.0.0",
  release_date = "2026-09-21",
  files = manifest_files
)
jsonlite::write_json(
  manifest, file.path(mock_release_dir, "manifest.json"),
  auto_unbox = TRUE, pretty = TRUE
)
message("Mock release written: ", mock_release_dir)

# ---------------------------------------------------------------------------
# 3. Golden CSV writer, enforcing the exact contract
# ---------------------------------------------------------------------------

write_golden <- function(df, name, sort_cols) {
  df <- df |>
    dplyr::mutate(dplyr::across(
      dplyr::where(is.numeric) & !dplyr::any_of(c("rank")),
      ~ round(.x, 10)
    )) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(sort_cols)))

  path <- file.path(goldens_dir, paste0(name, ".csv"))
  con <- file(path, open = "wb", encoding = "native.enc")
  readr::write_csv(df, con, na = "", eol = "\n")
  close(con)
  message("Golden written: ", path, " (", nrow(df), " rows)")
}

rdf <- rdflib::rdf_parse(fixture_path, format = "ntriples")

write_golden(framework_metadata(rdf), "framework_metadata",
             c("framework"))
write_golden(unit_element_bindings(rdf), "unit_element_bindings",
             c("role", "element"))
write_golden(unit_relation_bindings(rdf), "unit_relation_bindings",
             c("from_unit", "to_unit", "relation"))
write_golden(
  framework_similarity(rdf, from = "fixture-wf1", to = "fixture-wf2", n = 5),
  "framework_similarity",
  c("from_unit", "rank")
)
write_golden(cybed_license(), "cybed_license", c("slug"))
write_golden(cybedtools::framework_summary, "framework_summary",
             c("framework_slug"))
write_golden(role_framework_bindings(rdf), "role_framework_bindings",
             c("role", "framework"))
write_golden(organizing_unit_framework_bindings(rdf), "organizing_unit_framework_bindings",
             c("unit", "framework"))
write_golden(element_framework_bindings(rdf), "element_framework_bindings",
             c("element", "framework"))
write_golden(example_framework_bindings(rdf), "example_framework_bindings",
             c("example", "framework"))
write_golden(subpoint_framework_bindings(rdf), "subpoint_framework_bindings",
             c("subpoint", "framework"))
write_golden(element_text(rdf), "element_text", c("element"))

message("\nDone. ", length(list.files(goldens_dir)), " golden file(s) written.")
