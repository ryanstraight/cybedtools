# Tests for the pure helpers in scripts/_release-common.R, the policy and
# determinism surface of the public data release.
#
# scripts/ is .Rbuildignore'd, so these tests skip under R CMD check on the
# built tarball and run under devtools::test() in the source tree. Fixtures are
# synthetic N-Triples lines; no staged framework data is read, except by the
# last block, which checks a release folder if one has been built and skips if
# not.

source_release_common <- function() {
  for (pkg in c("digest", "jsonlite", "yaml")) {
    testthat::skip_if_not_installed(pkg)
  }
  path <- testthat::test_path("..", "..", "scripts", "_release-common.R")
  if (!file.exists(path)) {
    testthat::skip("_release-common.R not available (built-tarball check)")
  }
  env <- new.env(parent = globalenv())
  suppressPackageStartupMessages(source(path, local = env))
  env
}

cybed <- function(term) paste0("https://w3id.org/cybed/ontology#", term)
schema <- function(term) paste0("http://schema.org/", term)

triple <- function(subject, predicate, object) {
  paste0("<", subject, "> <", predicate, "> ", object, " .")
}

literal <- function(text) paste0("\"", text, "\"")

fixture_lines <- function() {
  c(
    triple("urn:fw", "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
           paste0("<", cybed("Framework"), ">")),
    triple("urn:fw", schema("version"), literal("version 1.1")),
    triple("urn:fw", schema("creditText"), literal(strrep("credit ", 60))),
    triple("urn:role", schema("name"), literal("OT Cybersecurity Manager")),
    triple("urn:task", cybed("sourceSection"),
           literal("Lead people and organisation")),
    triple("urn:task", cybed("elementText"),
           literal("Review and approve the cybersecurity incident response plan")),
    triple("urn:role", schema("description"),
           literal("A long prose description of the role.")),
    triple("urn:task", cybed("partOf"), "<urn:fw>")
  )
}

omit_predicates <- c(cybed("elementText"), schema("description"))

# ---------------------------------------------------------------------------
# Canonical order
# ---------------------------------------------------------------------------

test_that("canonical order is the same under any collation locale", {
  env <- source_release_common()
  lines <- c("<urn:b> <urn:p> \"x\" .",
             "<urn:A> <urn:p> \"x\" .",
             "<urn:a> <urn:p> \"x\" .",
             "<urn:B> <urn:p> \"x\" .",
             "<urn:_> <urn:p> \"x\" .",
             "<urn:~> <urn:p> \"x\" .")

  original <- Sys.getlocale("LC_COLLATE")
  on.exit(suppressWarnings(Sys.setlocale("LC_COLLATE", original)), add = TRUE)

  suppressWarnings(Sys.setlocale("LC_COLLATE", "C"))
  in_c <- env$canonical_lines(lines)

  other <- suppressWarnings(Sys.setlocale("LC_COLLATE", "en_US.UTF-8"))
  if (!nzchar(other)) {
    other <- suppressWarnings(Sys.setlocale("LC_COLLATE",
                                            "English_United States.utf8"))
  }
  skip_if(!nzchar(other), "No second collation locale available to compare.")

  expect_identical(env$canonical_lines(lines), in_c)
  # A locale-aware sort would differ here, so the fixture proves the point.
  expect_false(identical(sort(lines), in_c))
})

test_that("canonical order drops blanks and exact duplicates", {
  env <- source_release_common()
  lines <- c("<urn:a> <urn:p> \"x\" .", "", "<urn:a> <urn:p> \"x\" .")
  expect_identical(env$canonical_lines(lines), "<urn:a> <urn:p> \"x\" .")
})

test_that("the payload ends in exactly one newline and uses LF", {
  env <- source_release_common()
  payload <- env$canonical_payload(c("a", "b"))
  expect_identical(rawToChar(payload), "a\nb\n")
  expect_length(env$canonical_payload(character(0)), 0L)
})

# ---------------------------------------------------------------------------
# Determinism of the gzip member
# ---------------------------------------------------------------------------

test_that("gzip bytes are identical across runs and carry no timestamp", {
  env <- source_release_common()
  payload <- env$canonical_payload(fixture_lines())

  first <- env$gzip_bytes(payload)
  Sys.sleep(1.1)
  second <- env$gzip_bytes(payload)

  expect_identical(first, second)
  # Bytes 5 through 8 are the modification time and byte 4 holds the flags,
  # one of which would announce an embedded original filename.
  expect_identical(first[5:8], as.raw(c(0, 0, 0, 0)))
  expect_identical(first[[4]], as.raw(0))
  expect_identical(first[1:3], as.raw(c(0x1f, 0x8b, 0x08)))
})

test_that("a gzip member written to disk decompresses to the payload", {
  env <- source_release_common()
  payload <- env$canonical_payload(fixture_lines())
  path <- withr::local_tempfile(fileext = ".nt.gz")
  writeBin(env$gzip_bytes(payload), path)

  connection <- gzfile(path, "rb")
  on.exit(close(connection), add = TRUE)
  expect_identical(readBin(connection, "raw", length(payload) + 1L), payload)
})

# ---------------------------------------------------------------------------
# Structure-only filtering
# ---------------------------------------------------------------------------

test_that("structure-only stripping removes text predicates and keeps structure", {
  env <- source_release_common()
  kept <- env$strip_text_predicates(fixture_lines(), omit_predicates)
  predicates <- env$nt_predicates(kept)

  expect_false(cybed("elementText") %in% predicates)
  expect_false(schema("description") %in% predicates)
  expect_true(schema("name") %in% predicates)
  expect_true(cybed("sourceSection") %in% predicates)
  expect_true(cybed("partOf") %in% predicates)
  expect_true(schema("creditText") %in% predicates)
})

test_that("the long-literal backstop passes a clean structure-only file", {
  env <- source_release_common()
  kept <- env$strip_text_predicates(fixture_lines(), omit_predicates)
  expect_silent(
    env$assert_no_long_literals(
      kept,
      threshold = 200L,
      allow_predicates = c(schema("license"), schema("creditText")),
      slug = "fixture"
    )
  )
})

test_that("the long-literal backstop fires on a planted violation", {
  env <- source_release_common()
  planted <- c(
    env$strip_text_predicates(fixture_lines(), omit_predicates),
    triple("urn:task", cybed("sourceSection"), literal(strrep("a", 400)))
  )
  expect_error(
    env$assert_no_long_literals(
      planted,
      threshold = 200L,
      allow_predicates = c(schema("license"), schema("creditText")),
      slug = "fixture"
    ),
    class = "cybedtools_release_long_literal"
  )
})

test_that("the backstop exempts only the allow-listed predicates", {
  env <- source_release_common()
  long_credit <- triple("urn:fw", schema("creditText"), literal(strrep("b", 400)))
  expect_silent(
    env$assert_no_long_literals(long_credit, threshold = 200L,
                                allow_predicates = schema("creditText"),
                                slug = "fixture")
  )
  expect_error(
    env$assert_no_long_literals(long_credit, threshold = 200L,
                                allow_predicates = character(0),
                                slug = "fixture"),
    class = "cybedtools_release_long_literal"
  )
})

# ---------------------------------------------------------------------------
# Allowlist against policy
# ---------------------------------------------------------------------------

policy_fixture <- function() {
  data.frame(
    framework_slug = c("alpha", "beta", "gamma"),
    policy = c("unrestricted", "structure_only", "local_only"),
    stringsAsFactors = FALSE
  )
}

# Top-level replacement only. modifyList() would merge the inner named lists
# and leave a framework in two places at once.
config_fixture <- function(shipped = c("alpha", "beta"),
                           held = list(),
                           refused = list(gamma = "Not distributed.")) {
  list(shipped = shipped, held = held, refused = refused)
}

test_that("a compliant allowlist passes", {
  env <- source_release_common()
  expect_silent(
    env$assert_release_allowlist(config_fixture(), policy_fixture())
  )
})

test_that("a local_only slug on the allowlist aborts", {
  env <- source_release_common()
  config <- config_fixture(shipped = c("alpha", "beta", "gamma"),
                           refused = list())
  expect_error(
    env$assert_release_allowlist(config, policy_fixture()),
    class = "cybedtools_release_policy_refusal"
  )
})

test_that("a framework placed nowhere in the config aborts", {
  env <- source_release_common()
  config <- config_fixture(shipped = "alpha")
  expect_error(
    env$assert_release_allowlist(config, policy_fixture()),
    class = "cybedtools_release_config"
  )
})

test_that("a framework the invariants file does not declare aborts", {
  env <- source_release_common()
  config <- config_fixture(shipped = c("alpha", "beta", "delta"))
  expect_error(
    env$assert_release_allowlist(config, policy_fixture()),
    class = "cybedtools_release_config"
  )
})

test_that("a refused slug that is not local_only aborts", {
  env <- source_release_common()
  config <- config_fixture(shipped = "alpha",
                           held = list(gamma = "Held."),
                           refused = list(beta = "Not distributed."))
  expect_error(
    env$assert_release_allowlist(config, policy_fixture()),
    class = "cybedtools_release_config"
  )
})

test_that("release scope follows the policy value", {
  env <- source_release_common()
  expect_identical(env$release_scope("unrestricted"), "full")
  expect_identical(env$release_scope("full_with_attribution"), "full")
  expect_identical(env$release_scope("structure_only"), "structure_only")
  expect_error(env$release_scope("local_only"),
               class = "cybedtools_release_policy_refusal")
})

test_that("the scope vocabulary carries every value a manifest may hold", {
  env <- source_release_common()
  expect_setequal(env$release_scope_values(),
                  c("full", "structure_only", "full_with_exclusions"))
  for (scope in env$release_scope_values()) {
    expect_silent(env$assert_release_scope(scope, slug = "fixture"))
  }
  expect_error(env$assert_release_scope("partial", slug = "fixture"),
               class = "cybedtools_release_config")
})

test_that("an excluded full file takes the full_with_exclusions scope", {
  env <- source_release_common()
  expect_identical(env$release_scope_with_exclusions("full", slug = "fixture"),
                   "full_with_exclusions")
  # Two cuts described by one word would leave a reader unable to say which of
  # them accounts for a missing triple.
  expect_error(
    env$release_scope_with_exclusions("structure_only", slug = "fixture"),
    class = "cybedtools_release_exclusion_config"
  )
})

# ---------------------------------------------------------------------------
# Exclusions inside a shipped file
# ---------------------------------------------------------------------------

# Two units, `keep` and `cut`, sharing element `shared`. `cut` alone holds
# `only`, which carries a sub-point of its own. `cut` is also the object of a
# link from `keep`, which is what a framework that reuses one source identifier
# for a unit and for a statement looks like: one IRI, a unit in one triple and
# an element in another.
fx <- function(term) paste0("https://example.org/terms#", term)
rdf_type <- "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
iri <- function(term) paste0("<", fx(term), ">")

exclusion_lines <- function() {
  c(
    triple(fx("keep"), rdf_type, paste0("<", cybed("OrganizingUnit"), ">")),
    triple(fx("cut"), rdf_type, paste0("<", cybed("OrganizingUnit"), ">")),
    triple(fx("cut"), rdf_type, paste0("<", cybed("RoleElement"), ">")),
    triple(fx("keep"), schema("name"), literal("Kept Role")),
    triple(fx("cut"), schema("name"), literal("Cut Role")),
    triple(fx("cut"), cybed("partOf"), iri("framework")),
    triple(fx("shared"), rdf_type, paste0("<", cybed("RoleElement"), ">")),
    triple(fx("shared"), cybed("elementText"), literal("A shared statement.")),
    triple(fx("shared"), cybed("partOf"), iri("framework")),
    triple(fx("only"), rdf_type, paste0("<", cybed("RoleElement"), ">")),
    triple(fx("only"), cybed("elementText"), literal("An exclusive statement.")),
    triple(fx("only.sub.1"), rdf_type, paste0("<", cybed("Subpoint"), ">")),
    triple(fx("only.sub.1"), rdf_type, paste0("<", cybed("RoleElement"), ">")),
    triple(fx("only.sub.1"), cybed("elementText"), literal("a detail")),
    triple(fx("only.sub.1"), cybed("elaborates"), iri("only")),
    triple(fx("keep"), cybed("hasElement"), iri("shared")),
    triple(fx("keep"), cybed("hasElement"), iri("cut")),
    triple(fx("cut"), cybed("hasElement"), iri("shared")),
    triple(fx("cut"), cybed("hasElement"), iri("only")),
    triple(fx("cut"), cybed("hasElement"), iri("only.sub.1"))
  )
}

test_that("a unit id resolves on the exact local part of its IRI", {
  env <- source_release_common()
  expect_identical(
    env$resolve_exclusion_units(exclusion_lines(), "cut", slug = "fixture"),
    fx("cut")
  )
})

test_that("an exclusion naming a unit the file does not carry aborts", {
  env <- source_release_common()
  expect_error(
    env$resolve_exclusion_units(exclusion_lines(), c("cut", "absent"),
                                slug = "fixture"),
    class = "cybedtools_release_exclusion_unit"
  )
  # A name is not an identifier, an element is not a unit, and a substring of
  # a local part is not a local part.
  expect_error(
    env$resolve_exclusion_units(exclusion_lines(), "Cut Role", slug = "fixture"),
    class = "cybedtools_release_exclusion_unit"
  )
  expect_error(
    env$resolve_exclusion_units(exclusion_lines(), "shared", slug = "fixture"),
    class = "cybedtools_release_exclusion_unit"
  )
  expect_error(
    env$resolve_exclusion_units(exclusion_lines(), "cu", slug = "fixture"),
    class = "cybedtools_release_exclusion_unit"
  )
})

test_that("an exclusion removes the excluded unit's links to its elements", {
  env <- source_release_common()
  result <- env$exclude_unit_element_links(exclusion_lines(), fx("cut"),
                                           slug = "fixture")
  kept <- result$lines

  # Every link whose unit side is the excluded unit is gone.
  expect_false(any(startsWith(kept, paste0("<", fx("cut"), "> <",
                                           cybed("hasElement"), "> "))))
  expect_identical(result$link_triples_dropped, 3L)

  # The declared side is what decides. `keep` links to the same IRI acting as
  # an element, and that link belongs to a unit nobody excluded.
  expect_true(triple(fx("keep"), cybed("hasElement"), iri("cut")) %in% kept)

  # The unit node itself stays, with its identity and its membership.
  expect_true(triple(fx("cut"), schema("name"), literal("Cut Role")) %in% kept)
  expect_true(triple(fx("cut"), cybed("partOf"), iri("framework")) %in% kept)
  expect_true(
    triple(fx("cut"), rdf_type, paste0("<", cybed("OrganizingUnit"), ">")) %in% kept
  )
})

test_that("a link predicate declared the other way round cuts the other way", {
  env <- source_release_common()
  specs <- list(list(predicate = cybed("hasElement"), unit_side = "object"))
  kept <- env$exclude_unit_element_links(exclusion_lines(), fx("cut"),
                                         specs = specs, slug = "fixture")$lines

  # Under this declaration `cut` is the element and `keep` is the unit, so the
  # one link into `cut` goes and the three out of it stay.
  expect_false(triple(fx("keep"), cybed("hasElement"), iri("cut")) %in% kept)
  expect_true(triple(fx("cut"), cybed("hasElement"), iri("only")) %in% kept)
})

test_that("an element shared with another unit survives with its other links", {
  env <- source_release_common()
  kept <- env$exclude_unit_element_links(exclusion_lines(), fx("cut"),
                                         slug = "fixture")$lines

  expect_true(triple(fx("keep"), cybed("hasElement"), iri("shared")) %in% kept)
  expect_true(
    triple(fx("shared"), cybed("elementText"),
           literal("A shared statement.")) %in% kept
  )
  expect_true(triple(fx("shared"), cybed("partOf"), iri("framework")) %in% kept)
})

test_that("an element left attached to no unit is removed with its sub-points", {
  env <- source_release_common()
  result <- env$exclude_unit_element_links(exclusion_lines(), fx("cut"),
                                           slug = "fixture")
  kept <- result$lines

  expect_false(any(grepl(fx("only"), kept, fixed = TRUE)))
  expect_identical(result$elements_dropped, 2L)
  expect_identical(result$subpoints_dropped, 1L)
  expect_identical(result$element_triples_dropped, 6L)

  # The whole file is accounted for: before, less both counts, is after.
  expect_identical(
    length(kept),
    length(exclusion_lines()) - result$link_triples_dropped -
      result$element_triples_dropped
  )
})

test_that("the backstop passes a clean cut and fires on a surviving link", {
  env <- source_release_common()
  kept <- env$exclude_unit_element_links(exclusion_lines(), fx("cut"),
                                         slug = "fixture")$lines
  expect_silent(
    env$assert_no_unit_element_links(kept, fx("cut"), slug = "fixture")
  )
  expect_error(
    env$assert_no_unit_element_links(exclusion_lines(), fx("cut"),
                                     slug = "fixture"),
    class = "cybedtools_release_exclusion_verification"
  )
})

exclusion_config <- function(framework = "alpha",
                             kind = "unit_element_links",
                             units = list("cut"),
                             reason = "A published sentence.") {
  config <- config_fixture()
  config$exclusions <- list(
    list(framework = framework, kind = kind, units = units,
         reason = reason, since = "2026.09.1")
  )
  config
}

test_that("a compliant exclusion list passes", {
  env <- source_release_common()
  expect_silent(env$assert_release_exclusions(exclusion_config()))
  expect_silent(env$assert_release_exclusions(config_fixture()))
})

test_that("an exclusion for a framework off the allowlist aborts", {
  env <- source_release_common()
  # Refused by policy, so never shipped, so nothing to exclude from.
  expect_error(
    env$assert_release_exclusions(exclusion_config(framework = "gamma")),
    class = "cybedtools_release_exclusion_config"
  )
  # Declared nowhere at all.
  expect_error(
    env$assert_release_exclusions(exclusion_config(framework = "delta")),
    class = "cybedtools_release_exclusion_config"
  )
})

test_that("an exclusion with no kind, no units or no reason aborts", {
  env <- source_release_common()
  for (broken in list(
    exclusion_config(kind = "unit_element_text"),
    exclusion_config(units = list()),
    exclusion_config(reason = "")
  )) {
    expect_error(env$assert_release_exclusions(broken),
                 class = "cybedtools_release_exclusion_config")
  }
})

test_that("the real exclusion list names only frameworks the release ships", {
  env <- source_release_common()
  config_path <- testthat::test_path("..", "..", "docs", "data-release.yml")
  skip_if(!file.exists(config_path), "Release config not available.")

  config <- yaml::read_yaml(config_path)
  expect_silent(env$assert_release_exclusions(config))
})

# ---------------------------------------------------------------------------
# Licence lookup
# ---------------------------------------------------------------------------

test_that("a licence row is found by exact slug and by version suffix", {
  env <- source_release_common()
  licenses <- data.frame(
    slug = c("cybedtools", "nice-v2", "otccf-v1.1"),
    stringsAsFactors = FALSE
  )
  expect_identical(env$release_license_row(licenses, "nice")$slug, "nice-v2")
  expect_identical(env$release_license_row(licenses, "cybedtools")$slug,
                   "cybedtools")
})

test_that("a slug missing from framework_licenses aborts", {
  env <- source_release_common()
  licenses <- data.frame(slug = c("nice-v2", "otccf-v1.1"),
                         stringsAsFactors = FALSE)
  expect_error(
    env$release_license_row(licenses, "dcwf"),
    class = "cybedtools_release_license_missing"
  )
})

test_that("every shipped slug resolves in the real licence table", {
  env <- source_release_common()
  config_path <- testthat::test_path("..", "..", "docs", "data-release.yml")
  skip_if(!file.exists(config_path), "Release config not available.")

  config <- yaml::read_yaml(config_path)
  for (slug in as.character(config$shipped)) {
    row <- env$release_license_row(cybedtools::framework_licenses, slug)
    expect_equal(nrow(row), 1L)
  }
})

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------

test_that("manifest keys are sorted and the text ends in one newline", {
  env <- source_release_common()
  text <- env$manifest_json(list(zebra = 1L, alpha = list(nested = 2L, about = 3L)))
  expect_lt(regexpr("\"alpha\"", text), regexpr("\"zebra\"", text))
  expect_lt(regexpr("\"about\"", text), regexpr("\"nested\"", text))
  expect_true(endsWith(text, "}\n"))
  expect_false(grepl("\r", text, fixed = TRUE))
})

test_that("a built release folder matches its own manifest hashes", {
  env <- source_release_common()
  release_root <- testthat::test_path("..", "..", "data", "processed", "release")
  skip_if(!dir.exists(release_root), "No release has been built.")

  versions <- list.dirs(release_root, recursive = FALSE)
  skip_if(!length(versions), "No release has been built.")

  out_dir <- versions[[length(versions)]]
  manifest_path <- file.path(out_dir, "manifest.json")
  skip_if(!file.exists(manifest_path), "No manifest in the release folder.")

  manifest <- jsonlite::fromJSON(manifest_path, simplifyDataFrame = FALSE)
  for (entry in manifest$files) {
    path <- file.path(out_dir, entry$file)
    expect_true(file.exists(path))

    compressed <- readBin(path, "raw", file.size(path))
    expect_identical(
      digest::digest(compressed, algo = "sha256", serialize = FALSE),
      entry$sha256
    )
    expect_equal(length(compressed), entry$bytes)

    connection <- gzfile(path, "rb")
    payload <- readBin(connection, "raw", entry$bytes_uncompressed + 1L)
    close(connection)
    expect_identical(
      digest::digest(payload, algo = "sha256", serialize = FALSE),
      entry$sha256_uncompressed
    )
  }
})

test_that("a built release is byte-reproducible from the file it shipped", {
  env <- source_release_common()
  release_root <- testthat::test_path("..", "..", "data", "processed", "release")
  skip_if(!dir.exists(release_root), "No release has been built.")

  versions <- list.dirs(release_root, recursive = FALSE)
  skip_if(!length(versions), "No release has been built.")

  out_dir <- versions[[length(versions)]]
  manifest_path <- file.path(out_dir, "manifest.json")
  skip_if(!file.exists(manifest_path), "No manifest in the release folder.")

  manifest <- jsonlite::fromJSON(manifest_path, simplifyDataFrame = FALSE)
  for (entry in manifest$files) {
    connection <- gzfile(file.path(out_dir, entry$file), "rt")
    lines <- readLines(connection, warn = FALSE)
    close(connection)

    # Re-canonicalising and re-compressing the shipped lines reproduces the
    # shipped bytes, which is what makes a second run byte-identical.
    rebuilt <- env$gzip_bytes(env$canonical_payload(env$canonical_lines(lines)))
    expect_identical(
      digest::digest(rebuilt, algo = "sha256", serialize = FALSE),
      entry$sha256
    )
  }
})

test_that("a shipped file with exclusions records and honours them", {
  env <- source_release_common()
  release_root <- testthat::test_path("..", "..", "data", "processed", "release")
  skip_if(!dir.exists(release_root), "No release has been built.")

  versions <- list.dirs(release_root, recursive = FALSE)
  skip_if(!length(versions), "No release has been built.")

  out_dir <- versions[[length(versions)]]
  manifest_path <- file.path(out_dir, "manifest.json")
  skip_if(!file.exists(manifest_path), "No manifest in the release folder.")

  manifest <- jsonlite::fromJSON(manifest_path, simplifyDataFrame = FALSE)
  for (entry in manifest$files) {
    expect_true(entry$scope %in% env$release_scope_values())
  }

  excluded <- Filter(function(e) length(e$exclusions), manifest$files)
  skip_if(!length(excluded), "No exclusions in this release.")

  for (entry in excluded) {
    expect_identical(entry$scope, "full_with_exclusions")

    connection <- gzfile(file.path(out_dir, entry$file), "rt")
    lines <- readLines(connection, warn = FALSE)
    close(connection)

    for (record in entry$exclusions) {
      expect_true(record$kind %in% env$release_exclusion_kinds())
      expect_true(nzchar(record$reason))
      expect_gt(record$link_triples_dropped, 0)
      expect_gte(record$elements_dropped, 0)

      units <- unique(env$nt_subjects_of_type(lines,
                                              env$cybed_organizing_unit_iri))
      locals <- env$iri_local_part(units)
      for (unit in record$units) {
        expect_true(nzchar(unit$name))
        # The unit node stays, and nothing links it to an element any more.
        expect_true(unit$id %in% locals)
        iri <- units[locals == unit$id]
        expect_identical(
          env$nt_literal_of(lines, iri, "http://schema.org/name"),
          unit$name
        )
        expect_silent(
          env$assert_no_unit_element_links(lines, iri, slug = entry$slug)
        )
      }
    }
  }
})

test_that("a shipped structure-only file carries no text predicate", {
  env <- source_release_common()
  release_root <- testthat::test_path("..", "..", "data", "processed", "release")
  skip_if(!dir.exists(release_root), "No release has been built.")

  versions <- list.dirs(release_root, recursive = FALSE)
  skip_if(!length(versions), "No release has been built.")

  out_dir <- versions[[length(versions)]]
  manifest_path <- file.path(out_dir, "manifest.json")
  skip_if(!file.exists(manifest_path), "No manifest in the release folder.")

  manifest <- jsonlite::fromJSON(manifest_path, simplifyDataFrame = FALSE)
  structure_only <- Filter(function(e) identical(e$scope, "structure_only"),
                           manifest$files)
  skip_if(!length(structure_only), "No structure-only file in this release.")

  for (entry in structure_only) {
    connection <- gzfile(file.path(out_dir, entry$file), "rt")
    lines <- readLines(connection, warn = FALSE)
    close(connection)

    predicates <- env$nt_predicates(lines)
    expect_false(any(predicates %in% unlist(entry$omitted_predicates)))
    expect_true(schema("name") %in% predicates)
    expect_true(cybed("sourceSection") %in% predicates)
  }
})
