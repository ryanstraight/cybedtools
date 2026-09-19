# Self-test for concordance/_publication-guard.R. Not part of the package test
# suite: the guard is site-build machinery, not exported package code.
#
# Run from the repo root:
#   Rscript concordance/_publication-guard-test.R

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(here)
})

source(here("concordance", "_publication-guard.R"))

ok <- function(label) cat("PASS  ", label, "\n", sep = "")
bad <- function(label) {
  cat("FAIL  ", label, "\n", sep = "")
  quit(status = 1L)
}
errmsg <- function(expr) {
  tryCatch({
    force(expr)
    NULL
  }, error = function(e) conditionMessage(e))
}
reset_guard <- function() {
  rm(list = ls(envir = .pub_guard, all.names = TRUE), envir = .pub_guard)
}

# ---------------------------------------------------------------------------
# Policy values: the allowlist and its load-time validation
# ---------------------------------------------------------------------------

cat("=== recognised policy values ===\n")
print(PUBLICATION_POLICIES)

if (!identical(sort(names(PUBLICATION_POLICIES)),
               sort(c("unrestricted", "full_with_attribution",
                      "structure_only", "local_only")))) {
  bad("every recognised policy value is declared in one place")
}
ok("every recognised policy value is declared in one place")

write_invariants <- function(entries) {
  path <- tempfile(fileext = ".yml")
  writeLines(c("frameworks:", entries), path)
  path
}

# A typo'd or otherwise unrecognised value must stop at load time, naming the
# framework and the value. This is the failure the old `policy !=
# "structure_only"` test read as publishable.
reset_guard()
typo_path <- write_invariants(c(
  "  nice:",
  "    version: \"v2.2.0\"",
  "  otccf:",
  "    public_redistribution: structre_only"
))
err <- errmsg(publication_policy(path = typo_path))
if (is.null(err)) bad("typo'd policy value stops at load time")
cat(err, "\n")
if (!grepl("otccf", err, fixed = TRUE) ||
    !grepl("structre_only", err, fixed = TRUE)) {
  bad("load-time stop names the framework and the value")
}
ok("typo'd policy value stops at load time, naming framework and value")

# A stricter-sounding unknown value is still unknown. It must not slip past.
reset_guard()
strict_path <- write_invariants(c(
  "  nice:",
  "    version: \"v2.2.0\"",
  "  sfia:",
  "    public_redistribution: no_publication_at_all"
))
err <- errmsg(publication_policy(path = strict_path))
if (is.null(err)) bad("unknown stricter-sounding value stops at load time")
ok("unknown stricter-sounding value stops at load time")

# Every declared value behaves as the allowlist says, and an absent field
# reads as unrestricted.
reset_guard()
all_values_path <- write_invariants(c(
  "  nice:",
  "    version: \"v2.2.0\"",                       # field absent
  "  cyqual:",
  "    public_redistribution: full_with_attribution",
  "  otccf:",
  "    public_redistribution: structure_only",
  "  sfia:",
  "    public_redistribution: local_only"
))
invisible(publication_policy(path = all_values_path))
cat("\n=== policy table (synthetic, all four values) ===\n")
print(as.data.frame(publication_policy()[, c("framework_slug", "policy")]),
      right = FALSE)

if (!identical(framework_policy_of("nice"), "unrestricted")) {
  bad("absent public_redistribution reads as unrestricted")
}
ok("absent public_redistribution reads as unrestricted")
if (!isTRUE(is_text_publishable("nice"))) bad("unrestricted is publishable")
ok("unrestricted is publishable")
if (!isTRUE(is_text_publishable("cyqual"))) {
  bad("full_with_attribution is publishable")
}
ok("full_with_attribution is publishable")
if (!isFALSE(is_text_publishable("otccf"))) {
  bad("structure_only is not publishable")
}
ok("structure_only is not publishable")
if (!isFALSE(is_text_publishable("sfia"))) {
  bad("local_only is not publishable")
}
ok("local_only is not publishable")
if (!identical(sort(text_publishable_frameworks()), c("cyqual", "nice"))) {
  bad("text_publishable_frameworks lists only the allowlisted policies")
}
ok("text_publishable_frameworks lists only the allowlisted policies")

# ---------------------------------------------------------------------------
# Back to the real invariants file for the write-side tests
# ---------------------------------------------------------------------------

reset_guard()
invisible(publication_policy())

cat("\n=== policy table (docs/framework-invariants.yml) ===\n")
print(as.data.frame(publication_policy()[, c("framework_slug", "policy")]),
      right = FALSE)

cat("\n=== text-publishable frameworks ===\n")
print(text_publishable_frameworks())

df <- tibble(
  framework = c("otccf", "ccssf", "cyqual", "nice"),
  statement = c("otccf key task text", "ccssf task text",
                "cyqual task text", "nice task text")
)

cat("\n=== drop_unpublishable_text ===\n")
dropped <- drop_unpublishable_text(df, "framework", "statement")
print(as.data.frame(dropped), right = FALSE)

if (!all(is.na(dropped$statement[dropped$framework %in% c("otccf", "ccssf")]))) {
  bad("otccf and ccssf text blanked")
}
ok("otccf and ccssf text blanked")
if (!identical(dropped$statement[dropped$framework %in% c("cyqual", "nice")],
               df$statement[df$framework %in% c("cyqual", "nice")])) {
  bad("cyqual and nice text untouched")
}
ok("cyqual and nice text untouched")

cat("\n=== assert_no_unpublishable_text on the undropped frame ===\n")
err <- errmsg(assert_no_unpublishable_text(df, framework_col = "framework"))
if (is.null(err)) bad("assert stops on unpublishable text")
cat(err, "\n")
if (!grepl("otccf", err) || !grepl("ccssf", err)) {
  bad("assert names both offending frameworks")
}
ok("assert stops on unpublishable text and names otccf and ccssf")

cat("\n=== assert_no_unpublishable_text after the drop ===\n")
err <- errmsg(assert_no_unpublishable_text(dropped, framework_col = "framework"))
if (!is.null(err)) bad(paste("assert passes after drop:", err))
ok("assert passes after drop")

# ---------------------------------------------------------------------------
# Every character column is inspected, declared or not
# ---------------------------------------------------------------------------

cat("\n=== undeclared character column fails closed ===\n")
wide <- tibble(
  framework   = c("otccf", "nice"),
  unit_name   = c("OT Systems Engineer", "Systems Architect"),
  description = c("otccf role description text", "nice role description text")
)
# description is not named anywhere, so it is treated as statement text.
err <- errmsg(assert_no_unpublishable_text(
  wide, framework_col = "framework", structure_cols = "unit_name"))
if (is.null(err)) bad("undeclared text column is caught without being named")
cat(err, "\n")
if (!grepl("description", err)) bad("the offending column is named")
ok("undeclared text column is caught without being named")

cat("\n=== a character column with no attribution at all is refused ===\n")
err <- errmsg(assert_no_unpublishable_text(wide, structure_cols = "unit_name"))
if (is.null(err)) bad("unattributed character column is refused")
cat(err, "\n")
ok("unattributed character column is refused")

cat("\n=== structure columns pass ===\n")
err <- errmsg(assert_no_unpublishable_text(
  wide |> select(framework, unit_name), framework_col = "framework",
  structure_cols = "unit_name"))
if (!is.null(err)) bad(paste("names and identifiers pass:", err))
ok("names and identifiers pass")

cat("\n=== wide table, one framework per column ===\n")
per_col <- tibble(
  otccf_id    = "otccf-1",
  otccf_name  = "OT Systems Engineer",
  otccf_text  = "otccf key task text",
  nice_id     = "nice-1",
  nice_name   = "Systems Architect",
  nice_text   = "nice task text"
)
err <- errmsg(assert_no_unpublishable_text(
  per_col,
  framework_by_col = c(otccf_text = "otccf", nice_text = "nice"),
  structure_cols   = c("otccf_id", "otccf_name", "nice_id", "nice_name")))
if (is.null(err)) bad("per-column attribution catches the otccf column")
cat(err, "\n")
if (!grepl("otccf_text", err) || grepl("nice_text", err)) {
  bad("per-column attribution blames only the otccf column")
}
ok("per-column attribution catches the otccf column and spares the nice one")

err <- errmsg(assert_no_unpublishable_text(
  per_col |> select(-otccf_text),
  framework_by_col = c(nice_text = "nice"),
  structure_cols   = c("otccf_id", "otccf_name", "nice_id", "nice_name")))
if (!is.null(err)) bad(paste("per-column attribution passes when clean:", err))
ok("per-column attribution passes when clean")

err <- errmsg(assert_no_unpublishable_text(
  per_col,
  framework_by_col = c(nice_text = "nice"),
  structure_cols   = c("otccf_id", "otccf_name", "nice_id", "nice_name")))
if (is.null(err)) bad("a column missing from framework_by_col fails closed")
if (!grepl("otccf_text", err)) bad("the undeclared column is named")
ok("a column missing from framework_by_col fails closed")

# ---------------------------------------------------------------------------
# Unknown framework values
# ---------------------------------------------------------------------------

cat("\n=== unknown framework value ===\n")
unknown <- tibble(framework = "not-a-framework", statement = "text")
err <- errmsg(assert_no_unpublishable_text(unknown, framework_col = "framework"))
if (is.null(err)) bad("unknown framework stops")
cat(err, "\n")
ok("unknown framework stops rather than passing as safe")

cat("\n=== CSEC2017 description column is refused at write time ===\n")
csec_frame <- tibble(
  nice_id     = "https://w3id.org/cybed/ontology#nice/WRL-001",
  nice_name   = "Systems Architect",
  csec_id     = "https://cybered.acm.org/csec2017/terms#KA-COMP",
  csec_name   = "Component Security",
  csec_description = paste("Focuses on the security of components that are",
                           "integrated into larger systems."),
  similarity  = 0.065
)
err <- errmsg(assert_no_unpublishable_text(
  csec_frame,
  framework_by_col = c(csec_description = "csec2017"),
  structure_cols   = c("nice_id", "nice_name", "csec_id", "csec_name")))
if (is.null(err)) bad("a CSEC2017 description column is refused at write time")
cat(err, "\n")
if (!grepl("csec_description", err) || !grepl("csec2017", err)) {
  bad("the refusal names the column and the framework")
}
ok("a CSEC2017 description column is refused at write time")

# The same frame with the description gone writes fine: KA names are structure.
err <- errmsg(assert_no_unpublishable_text(
  csec_frame |> select(-csec_description),
  structure_cols = c("nice_id", "nice_name", "csec_id", "csec_name")))
if (!is.null(err)) bad(paste("CSEC2017 KA names still pass:", err))
ok("CSEC2017 KA names still pass")

cat("\n=== alias forms ===\n")
aliases <- c("csta-2017", "cyberorg-k12-v1.0",
             "https://w3id.org/cybed/ontology#framework/otccf-v1.1")
print(data.frame(value = aliases, slug = resolve_framework_slug(aliases)),
      right = FALSE)
if (!identical(resolve_framework_slug(aliases),
               c("csta", "cyberorg-k12", "otccf"))) {
  bad("IRI and versioned-tail aliases resolve")
}
ok("IRI and versioned-tail aliases resolve")

cat("\nAll publication guard self-tests passed.\n")
