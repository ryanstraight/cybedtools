# Data release this package version was built and tested against.
cybed_data_release <- "2026.09.2"

# R/cybed-fetch.R
#
# User-facing data loader for the public per-framework data release
# (scripts/030-export-release.R's output). cybed_fetch() downloads and
# hash-verifies release files into the CRAN-mandated user cache directory
# and never writes anywhere else. load_graph() turns cached files into an
# rdf object.

#' Resolve the base URL a release is fetched from
#'
#' Resolution order: the `cybedtools.release_url` option, then the
#' `CYBEDTOOLS_RELEASE_URL` environment variable, then a built-in default
#' pointing at this repository's GitHub release assets. Set either the
#' option or the environment variable to a `file://` URL (a local mock
#' release directory) in tests, so no test call ever reaches the network.
#'
#' The default carries a literal `{version}` placeholder, because a GitHub
#' release's assets sit directly under its own tag
#' (`releases/download/data-v<version>/`, no further version segment) while
#' every other supported layout (a mirror, or a mock release directory used
#' in tests) nests each version in its own subdirectory below one fixed
#' base. `cybed_release_url()` is what tells the two apart.
#'
#' @return Character scalar, a URL with no trailing slash.
#' @noRd
cybed_release_base_url <- function() {
  opt <- getOption("cybedtools.release_url")
  if (!is.null(opt) && nzchar(opt)) {
    return(sub("/+$", "", opt))
  }
  env <- Sys.getenv("CYBEDTOOLS_RELEASE_URL", unset = NA_character_)
  if (!is.na(env) && nzchar(env)) {
    return(sub("/+$", "", env))
  }
  "https://github.com/ryanstraight/cybedtools/releases/download/data-v{version}"
}

#' Build the URL of one release file (the manifest or a framework's `.nt.gz`)
#'
#' A GitHub release's assets are tagged `data-v<version>` and sit directly
#' under that tag with no further version segment, so a base URL carrying
#' the `{version}` placeholder has the version substituted in place rather
#' than appended. Every other base URL (a mirror, or a mock release
#' directory such as `inst/conformance/mock-release/<version>/`) nests each
#' version below the fixed base, as before.
#'
#' @param base_url Character scalar, from `cybed_release_base_url()`.
#' @param version Character scalar release version (or `"latest"`).
#' @param filename Character scalar, e.g. `"manifest.json"` or `"<slug>.nt.gz"`.
#' @return Character scalar URL.
#' @noRd
cybed_release_url <- function(base_url, version, filename) {
  if (grepl("{version}", base_url, fixed = TRUE)) {
    base_url <- sub("{version}", version, base_url, fixed = TRUE)
    return(paste0(base_url, "/", filename))
  }
  paste0(base_url, "/", version, "/", filename)
}

#' The package's cache directory
#'
#' @return Character scalar path, created if it does not yet exist.
#' @noRd
cybed_cache_dir <- function() {
  dir <- tools::R_user_dir("cybedtools", which = "cache")
  if (!dir.exists(dir)) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  }
  dir
}

#' Read a manifest.json, local or remote, without ever writing outside the cache
#'
#' @param base_url Character scalar.
#' @param version Character scalar, a release version segment (or `"latest"`).
#' @return A list, the parsed manifest.
#' @noRd
cybed_read_manifest <- function(base_url, version) {
  url <- cybed_release_url(base_url, version, "manifest.json")
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  cybed_download(url, tmp)
  jsonlite::fromJSON(tmp, simplifyVector = FALSE)
}

#' Download one URL to one destination path, uniformly for http(s):// and file://
#'
#' @noRd
cybed_download <- function(url, destfile) {
  result <- tryCatch(
    utils::download.file(url, destfile, mode = "wb", quiet = TRUE),
    error = function(cnd) cnd
  )
  if (inherits(result, "condition") || !file.exists(destfile) ||
        file.size(destfile) == 0) {
    rlang::abort(
      c(
        "Could not download a release file.",
        "x" = paste0("URL: ", url, "."),
        "i" = paste0(
          "Set `options(cybedtools.release_url = ...)` or the ",
          "CYBEDTOOLS_RELEASE_URL environment variable to point at a ",
          "reachable release (a `file://` URL works for local testing)."
        )
      ),
      class = "cybedtools_download_failed",
      url = url
    )
  }
  invisible(destfile)
}

#' Download and hash-verify per-framework release files into the user cache
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads the release manifest and the named frameworks' `.nt.gz` files
#' from the configured release location (see the release URL resolution rules documented below),
#' verifies each file's SHA-256 against the hash the manifest declares, and
#' writes only into `tools::R_user_dir("cybedtools", "cache")` -- never any
#' other location on disk, per CRAN policy. A file whose downloaded bytes
#' do not match its manifest hash is deleted and the call aborts with class
#' `cybedtools_hash_mismatch` rather than leaving a corrupt cache entry.
#'
#' Already-cached files whose hash still matches the manifest are not
#' re-downloaded.
#'
#' @param frameworks Character vector of framework slugs to fetch (as
#'   carried by [framework_summary]`$framework_slug`, e.g. `"nice-v2"`, or the release file slug, e.g. `"nice"`), or
#'   `NULL` (the default) for every framework the release manifest ships.
#' @param version Character scalar release version (e.g. `"1.0.0"`), or
#'   `NULL` (the default) for the data release this package version was built against, `cybed_data_release`.
#' @return Invisibly, a tibble with one row per fetched framework: columns
#'   `framework_slug`, `path` (the cached file's local path),
#'   `sha256_verified` (logical, always `TRUE` on return -- a mismatch
#'   aborts instead of returning `FALSE`).
#' @family data loading
#' @export
#' @examples
#' \donttest{
#' # Requires network access (or a `cybedtools.release_url` override
#' # pointing at a local mock release for testing).
#' tryCatch(
#'   cybed_fetch(frameworks = "nice"),
#'   cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
#' )
#' }
cybed_fetch <- function(frameworks = NULL, version = NULL) {
  base_url <- cybed_release_base_url()
  version  <- if (is.null(version)) cybed_data_release else version
  manifest <- cybed_read_manifest(base_url, version)

  files <- manifest$files
  manifest_slugs <- vapply(files, function(x) x$slug, character(1))

  # Release files use short slugs ("nice"); framework_summary uses versioned
  # ones ("nice-v2"), carried in the manifest as license_slug. Accept either.
  summary_slugs <- vapply(
    files,
    function(x) if (is.null(x$license_slug)) x$slug else x$license_slug,
    character(1)
  )

  if (is.null(frameworks)) {
    frameworks <- manifest_slugs
  }
  resolved <- ifelse(
    frameworks %in% manifest_slugs,
    frameworks,
    manifest_slugs[match(frameworks, summary_slugs)]
  )
  unknown <- frameworks[is.na(resolved)]
  frameworks <- resolved
  if (length(unknown)) {
    rlang::abort(
      c(
        "Unknown framework slug(s) for this release.",
        "x" = paste0("Unknown: ", paste(unknown, collapse = ", "), "."),
        "i" = paste0("Known slugs: ", paste(manifest_slugs, collapse = ", "), ".")
      ),
      class = "cybedtools_framework_not_found"
    )
  }

  cache_dir <- file.path(cybed_cache_dir(), version)
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  }

  rows <- lapply(frameworks, function(slug) {
    entry <- files[[which(manifest_slugs == slug)]]
    dest <- file.path(cache_dir, entry$file)

    needs_download <- !file.exists(dest) ||
      !identical(digest::digest(dest, algo = "sha256", file = TRUE), entry$sha256)

    if (needs_download) {
      url <- cybed_release_url(base_url, version, entry$file)
      cybed_download(url, dest)
      actual <- digest::digest(dest, algo = "sha256", file = TRUE)
      if (!identical(actual, entry$sha256)) {
        unlink(dest)
        rlang::abort(
          c(
            "Downloaded file does not match the release manifest's hash.",
            "x" = paste0("Framework: ", slug, "."),
            "x" = paste0("Expected sha256: ", entry$sha256, "."),
            "x" = paste0("Got sha256: ", actual, "."),
            "i" = "The file was deleted rather than cached in an unverified state."
          ),
          class = "cybedtools_hash_mismatch",
          framework_slug = slug
        )
      }
    }

    tibble::tibble(
      framework_slug  = slug,
      path            = dest,
      sha256_verified = TRUE
    )
  })

  invisible(dplyr::bind_rows(rows))
}

#' Load a graph from the cached release files, fetching first if needed
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Ensures the requested frameworks are cached (calling [cybed_fetch()]
#' internally, which is a no-op for files already cached with a verified
#' hash) and parses them into one shared rdf object.
#'
#' @inheritParams cybed_fetch
#' @return An rdf object ([rdflib::rdf()]) with every requested framework's
#'   triples loaded.
#' @family data loading
#' @export
#' @examples
#' \donttest{
#' tryCatch(
#'   {
#'     rdf <- load_graph(frameworks = "nice")
#'     framework_metadata(rdf)
#'   },
#'   cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
#' )
#' }
load_graph <- function(frameworks = NULL, version = NULL) {
  fetched <- cybed_fetch(frameworks = frameworks, version = version)

  rdf <- rdflib::rdf()
  for (path in fetched$path) {
    con <- gzfile(path, "rb")
    lines <- tryCatch(readLines(con, warn = FALSE), finally = close(con))
    tmp <- tempfile(fileext = ".nt")
    on.exit(unlink(tmp), add = TRUE)
    writeLines(lines, tmp)
    rdflib::rdf_parse(tmp, rdf = rdf, format = "ntriples")
  }
  rdf
}
