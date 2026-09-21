# python/tools/export_r_data.R
#
# Regenerates the CSV data files the Python package ships under
# src/cybedtools/_resources/ from the R package's own framework_summary and
# framework_licenses tibbles (R/data.R). Run this from the repository root
# whenever either tibble changes, and commit the resulting CSVs alongside
# the R change so the two ports never drift apart silently.
#
# Usage (from the repository root, with the R package installed or
# loadable via devtools/pkgload):
#
#   Rscript python/tools/export_r_data.R
#
# What it writes:
#   python/src/cybedtools/_resources/framework_summary.csv
#   python/src/cybedtools/_resources/cybed_license.csv
#
# Both are written with readr::write_csv() defaults (UTF-8, no BOM, LF line
# endings, comma-quoted only where required), which is also what
# scripts/040-build-goldens.R uses for inst/conformance/goldens/ -- so the
# shipped Python data and the R conformance goldens for these two functions
# are byte-identical by construction, and the golden files can be spot
# copies of these outputs (see python/tests/fixtures/conformance/goldens/).

if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("This script requires the 'pkgload' package (install.packages(\"pkgload\")).")
}

pkgload::load_all(quiet = TRUE)

out_dir <- file.path("python", "src", "cybedtools", "_resources")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(
  cybedtools::framework_summary,
  file.path(out_dir, "framework_summary.csv")
)

readr::write_csv(
  cybed_license(),
  file.path(out_dir, "cybed_license.csv")
)

message("Wrote ", file.path(out_dir, "framework_summary.csv"))
message("Wrote ", file.path(out_dir, "cybed_license.csv"))
message(
  "Remember to also refresh python/tests/fixtures/conformance/goldens/ ",
  "(copy the same two files there) if this ran outside of ",
  "scripts/040-build-goldens.R."
)
