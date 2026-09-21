# cybed_fetch() / load_graph() against the mock release in
# inst/conformance/mock-release/1.0.0/. Every URL here is a file:// URL, so
# no test in this file ever touches the network (enforced by never setting
# cybedtools.release_url / CYBEDTOOLS_RELEASE_URL to anything else).

conformance_dir <- system.file("conformance", package = "cybedtools")
if (!nzchar(conformance_dir)) {
  conformance_dir <- testthat::test_path("..", "..", "inst", "conformance")
}
mock_release_dir <- file.path(conformance_dir, "mock-release")

skip_if_no_mock_release <- function() {
  skip_if_not_installed("rdflib")
  skip_if_not_installed("digest")
  skip_if_not(
    dir.exists(file.path(mock_release_dir, "1.0.0")),
    "mock release not found; run scripts/040-build-goldens.R"
  )
}

mock_release_url <- function() {
  # file:// URL to the mock release directory. normalizePath() with
  # winslash = "/" so the path works as a URL on Windows too.
  paste0("file:///", normalizePath(mock_release_dir, winslash = "/", mustWork = TRUE))
}

with_mock_release <- function(code) {
  old_opt <- getOption("cybedtools.release_url")
  old_env <- Sys.getenv("CYBEDTOOLS_RELEASE_URL", unset = NA_character_)
  options(cybedtools.release_url = mock_release_url())
  on.exit({
    options(cybedtools.release_url = old_opt)
    if (is.na(old_env)) Sys.unsetenv("CYBEDTOOLS_RELEASE_URL") else Sys.setenv(CYBEDTOOLS_RELEASE_URL = old_env)
  }, add = TRUE)
  force(code)
}

fresh_cache_dir <- function() {
  # Redirect the cache to a throwaway temp directory for the duration of the
  # test, via the same option every real caller uses to find R_user_dir():
  # we can't override R_user_dir() itself, so instead we point HOME/
  # R_USER_CACHE_DIR-derived resolution isn't practical here; instead we
  # simply let cybed_fetch() use the real user cache dir under a
  # version-namespaced subfolder ("1.0.0"), which does not collide with any
  # real release version, and clean it up afterward.
  dir <- file.path(tools::R_user_dir("cybedtools", which = "cache"), "1.0.0")
  withr::defer(unlink(dir, recursive = TRUE), envir = parent.frame())
  dir
}

test_that("cybed_fetch downloads and hash-verifies every framework by default", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  cache_dir <- fresh_cache_dir()

  with_mock_release({
    result <- cybed_fetch(version = "1.0.0")
  })

  expect_s3_class(result, "tbl_df")
  expect_setequal(result$framework_slug,
                   c("fixture-wf1", "fixture-wf2", "fixture-ped1"))
  expect_true(all(result$sha256_verified))
  expect_true(all(file.exists(result$path)))
  expect_true(all(normalizePath(dirname(result$path)) == normalizePath(cache_dir)))
})

test_that("cybed_fetch(frameworks =) fetches only the named subset", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  fresh_cache_dir()

  with_mock_release({
    result <- cybed_fetch(frameworks = "fixture-wf1", version = "1.0.0")
  })

  expect_equal(nrow(result), 1)
  expect_equal(result$framework_slug, "fixture-wf1")
})

test_that("cybed_fetch errors on an unknown framework slug", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  fresh_cache_dir()

  with_mock_release({
    expect_error(
      cybed_fetch(frameworks = "not-a-real-framework", version = "1.0.0"),
      class = "cybedtools_framework_not_found"
    )
  })
})

test_that("cybed_fetch aborts and deletes the file on a hash mismatch", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  cache_dir <- fresh_cache_dir()

  # Point at a manifest whose declared hash cannot match the real file: copy
  # the mock release to a temp dir and corrupt one entry's sha256.
  tmp_release <- withr::local_tempdir()
  tmp_version_dir <- file.path(tmp_release, "1.0.0")
  dir.create(tmp_version_dir, recursive = TRUE)
  file.copy(
    list.files(file.path(mock_release_dir, "1.0.0"), full.names = TRUE),
    tmp_version_dir
  )
  manifest_path <- file.path(tmp_version_dir, "manifest.json")
  manifest <- jsonlite::fromJSON(manifest_path, simplifyVector = FALSE)
  manifest$files[[1]]$sha256 <- "0000000000000000000000000000000000000000000000000000000000000"
  jsonlite::write_json(manifest, manifest_path, auto_unbox = TRUE, pretty = TRUE)

  tmp_url <- paste0("file:///", normalizePath(tmp_release, winslash = "/", mustWork = TRUE))
  old_opt <- getOption("cybedtools.release_url")
  options(cybedtools.release_url = tmp_url)
  on.exit(options(cybedtools.release_url = old_opt), add = TRUE)

  bad_slug <- manifest$files[[1]]$slug

  expect_error(
    cybed_fetch(frameworks = bad_slug, version = "1.0.0"),
    class = "cybedtools_hash_mismatch"
  )
  expect_false(file.exists(file.path(cache_dir, paste0(bad_slug, ".nt.gz"))))
})

test_that("cybed_fetch does not re-download an already-verified cache entry", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  cache_dir <- fresh_cache_dir()

  with_mock_release({
    first  <- cybed_fetch(frameworks = "fixture-wf1", version = "1.0.0")
    stamp1 <- file.info(first$path)$mtime
    Sys.sleep(1.1)
    second <- cybed_fetch(frameworks = "fixture-wf1", version = "1.0.0")
    stamp2 <- file.info(second$path)$mtime
  })

  expect_equal(stamp1, stamp2)
})

test_that("cybed_fetch writes only under the user cache directory", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  cache_dir <- fresh_cache_dir()
  cache_root <- tools::R_user_dir("cybedtools", which = "cache")

  with_mock_release({
    result <- cybed_fetch(version = "1.0.0")
  })

  expect_true(all(startsWith(normalizePath(result$path), normalizePath(cache_root))))
})

test_that("load_graph fetches and parses the requested frameworks into one graph", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  fresh_cache_dir()

  with_mock_release({
    rdf <- load_graph(frameworks = c("fixture-wf1", "fixture-wf2"), version = "1.0.0")
  })

  meta <- framework_metadata(rdf)
  expect_setequal(meta$framework_slug, c("fixture-wf1", "fixture-wf2"))
})

test_that("cybed_fetch's result carries both framework_slug and release_slug", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  fresh_cache_dir()

  with_mock_release({
    result <- cybed_fetch(frameworks = "fixture-wf1", version = "1.0.0")
  })

  expect_true(all(c("framework_slug", "release_slug") %in% names(result)))
  # The mock manifest carries no license_slug, so both columns fall back to
  # the same (release) slug -- still two explicit columns, never a silent
  # substitution.
  expect_equal(result$framework_slug, "fixture-wf1")
  expect_equal(result$release_slug, "fixture-wf1")
})

test_that("cybed_fetch accepts a data-v-prefixed version", {
  skip_if_no_mock_release()
  skip_if_not_installed("withr")
  fresh_cache_dir()

  with_mock_release({
    plain  <- cybed_fetch(frameworks = "fixture-wf1", version = "1.0.0")
    prefixed <- cybed_fetch(frameworks = "fixture-wf1", version = "data-v1.0.0")
  })

  expect_equal(plain$path, prefixed$path)
})

test_that("cybed_release_base_url honors the option over the environment variable and default", {
  old_opt <- getOption("cybedtools.release_url")
  old_env <- Sys.getenv("CYBEDTOOLS_RELEASE_URL", unset = NA_character_)
  on.exit({
    options(cybedtools.release_url = old_opt)
    if (is.na(old_env)) Sys.unsetenv("CYBEDTOOLS_RELEASE_URL") else Sys.setenv(CYBEDTOOLS_RELEASE_URL = old_env)
  }, add = TRUE)

  Sys.setenv(CYBEDTOOLS_RELEASE_URL = "file:///env-only")
  options(cybedtools.release_url = NULL)
  expect_equal(cybedtools:::cybed_release_base_url(), "file:///env-only")

  options(cybedtools.release_url = "file:///option-wins")
  expect_equal(cybedtools:::cybed_release_base_url(), "file:///option-wins")
})

test_that("the default base URL points at this repo's GitHub release assets", {
  old_opt <- getOption("cybedtools.release_url")
  old_env <- Sys.getenv("CYBEDTOOLS_RELEASE_URL", unset = NA_character_)
  on.exit({
    options(cybedtools.release_url = old_opt)
    if (is.na(old_env)) Sys.unsetenv("CYBEDTOOLS_RELEASE_URL") else Sys.setenv(CYBEDTOOLS_RELEASE_URL = old_env)
  }, add = TRUE)
  options(cybedtools.release_url = NULL)
  Sys.unsetenv("CYBEDTOOLS_RELEASE_URL")

  expect_equal(
    cybedtools:::cybed_release_base_url(),
    "https://github.com/ryanstraight/cybedtools/releases/download/data-v{version}"
  )
})

test_that("cybed_release_url substitutes {version} in place for a GitHub release base, and appends a version segment for every other base", {
  expect_equal(
    cybedtools:::cybed_release_url(
      "https://github.com/ryanstraight/cybedtools/releases/download/data-v{version}",
      "2026.09.1", "manifest.json"
    ),
    "https://github.com/ryanstraight/cybedtools/releases/download/data-v2026.09.1/manifest.json"
  )
  expect_equal(
    cybedtools:::cybed_release_url("file:///mock-release", "1.0.0", "fixture-wf1.nt.gz"),
    "file:///mock-release/1.0.0/fixture-wf1.nt.gz"
  )
})
