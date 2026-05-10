## tools/build-hex.R
##
## Rasterizes tools/build-hex.svg to the package logo and a high-resolution
## copy for slides and posters. The SVG is the source of truth and is
## hand-crafted from the Concordance design pack; this script only scales
## it to the standard pkgdown-logo width and the higher-resolution width.
##
## Run from package root:
##   Rscript tools/build-hex.R
##
## Outputs:
##   man/figures/logo.png         (480px wide; pkgdown logo target)
##   tools/cybedtools-hex@2x.png  (1200px wide; gitignored)

if (!requireNamespace("rsvg", quietly = TRUE)) {
  stop(
    "Package 'rsvg' is required. Install with:\n",
    "  install.packages('rsvg')",
    call. = FALSE
  )
}

svg_path <- "tools/build-hex.svg"
if (!file.exists(svg_path)) {
  stop("Cannot find ", svg_path, " (run from package root).", call. = FALSE)
}

logo_path <- "man/figures/logo.png"
hires_path <- "tools/cybedtools-hex@2x.png"

dir.create(dirname(logo_path), recursive = TRUE, showWarnings = FALSE)

rsvg::rsvg_png(svg_path, logo_path, width = 480)
rsvg::rsvg_png(svg_path, hires_path, width = 1200)

message("Wrote: ", logo_path)
message("Wrote: ", hires_path)
