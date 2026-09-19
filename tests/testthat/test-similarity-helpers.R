# Tests for the canonical text-similarity layer (R/similarity-helpers.R),
# promoted 2026-08-20 from script-local triplicates in
# concordance/_data-prep-{k12,nice-ecsf,nice-csec2017}-alignment.R.
#
# The functions are internal (unexported); testthat runs in the package
# namespace, so they are called directly. The drift-tripwire tests at the
# bottom pin the still-live script-local copies against each other and
# against the package profiles; they skip under R CMD check on the built
# tarball (concordance/ is .Rbuildignore'd) and run under devtools::test()
# in the source tree.

# ---------------------------------------------------------------------------
# tokenize: core contract
# ---------------------------------------------------------------------------

test_that("tokenize lowercases, drops stopwords, and preserves order", {
  expect_identical(
    tokenize("The Firewall protects the network"),
    c("firewall", "protects", "network")
  )
})

test_that("tokenize splits on hyphens and applies the stopword profile", {
  # This input pins the stopword-list divergence between the two script
  # families as an explicit decision, not silent drift:
  # - "based" is in the shared base list (dropped by both profiles).
  # - "two" is ONLY in the workforce profile's extra words, so it is
  #   dropped by workforce and RETAINED by k12.
  expect_identical(
    tokenize("token-based two-factor authentication",
             stopwords = similarity_stopwords("workforce")),
    c("token", "factor", "authentication")
  )
  expect_identical(
    tokenize("token-based two-factor authentication",
             stopwords = similarity_stopwords("k12")),
    c("token", "two", "factor", "authentication")
  )
})

test_that("tokenize de-duplicates repeated tokens (set semantics)", {
  expect_identical(tokenize("firewall firewall firewall"), "firewall")
  expect_identical(
    tokenize("NICE Framework FRAMEWORK framework"),
    c("nice", "framework")
  )
})

test_that("tokenize destroys 2-character domain terms (documented lossy behavior)", {
  # "Wi-Fi" splits to wi/fi, and AI/OS/5G are all < 3 chars: every token
  # vanishes under the nchar >= 3 rule. This is a decision on record, not
  # an accident -- flip this test if the length floor is ever revisited.
  expect_identical(tokenize("Wi-Fi AI OS 5G"), character(0))
})

test_that("tokenize handles NA, empty, and whitespace-only input", {
  expect_identical(tokenize(NA_character_), character(0))
  expect_identical(tokenize(""), character(0))
  # Whitespace-only passes the nzchar() guard but must not leak a ""
  # token from the split.
  expect_identical(tokenize("   "), character(0))
})

test_that("tokenize keeps digit-bearing tokens of length >= 3", {
  # Pins the [a-z0-9] alphabet and the length rule together: a1b, c2d3,
  # and 800 survive; 53 is dropped.
  expect_identical(tokenize("a1b c2d3 800 53"), c("a1b", "c2d3", "800"))
})

test_that("tokenize degrades non-ASCII letters (documented lossy behavior)", {
  # Non-ASCII letters are split boundaries under [^a-z0-9]+, so accented
  # text produces garbage-adjacent tokens: "café résumé" -> caf + r|sum,
  # with the short fragments length-filtered. Known lossy for EU-origin
  # framework text (ECSF). If the regex is ever widened to Unicode
  # classes, update this expectation deliberately.
  expect_identical(tokenize("café résumé"), c("caf", "sum"))
})

test_that("tokenize enforces the scalar contract", {
  # The script-local copies crashed on both of these (zero-length: "argument
  # is of length zero"; length > 1: condition-length error). The canonical
  # version defines them: character(0) in, character(0) out; vectors are a
  # classed error.
  expect_identical(tokenize(character(0)), character(0))
  expect_error(tokenize(c("a", "b")), class = "cybedtools_scalar_input")
})

# ---------------------------------------------------------------------------
# similarity_stopwords: profiles
# ---------------------------------------------------------------------------

test_that("stopword profiles preserve the documented k12/workforce divergence", {
  k12 <- similarity_stopwords("k12")
  wf  <- similarity_stopwords("workforce")

  # Workforce is a strict superset: base list plus exactly the ten extra
  # words the NICE-facing scripts carry.
  expect_true(all(k12 %in% wf))
  expect_setequal(
    setdiff(wf, k12),
    c("any", "all", "new", "one", "two", "three",
      "work", "perform", "performs", "ensure")
  )
  # A few load-bearing members of the shared base list.
  expect_true(all(c("the", "such", "including", "based") %in% k12))
  # The default profile is workforce.
  expect_identical(similarity_stopwords(), wf)
})

# ---------------------------------------------------------------------------
# jaccard: core contract
# ---------------------------------------------------------------------------

test_that("jaccard returns exact known values", {
  expect_identical(jaccard(c("alpha", "beta", "gamma"),
                           c("beta", "gamma", "delta")), 0.5)
  expect_identical(jaccard(c("alpha", "beta"), c("alpha", "beta")), 1)
  expect_identical(jaccard("alpha", "beta"), 0)
  expect_identical(jaccard("alpha", c("alpha", "beta")), 0.5)
})

test_that("jaccard is symmetric", {
  a <- c("alpha", "beta", "gamma", "delta")
  b <- c("gamma", "epsilon")
  expect_identical(jaccard(a, b), jaccard(b, a))
})

test_that("jaccard returns exactly 0 for empty inputs (deliberate convention)", {
  expect_identical(jaccard(character(0), "alpha"), 0)
  expect_identical(jaccard("alpha", character(0)), 0)
  # Empty-empty is 0, not the mathematical-purist 1: an empty-document
  # unit must not "perfectly match" another empty-document unit.
  expect_identical(jaccard(character(0), character(0)), 0)
})

test_that("jaccard ignores duplicate tokens (set semantics)", {
  expect_identical(jaccard(c("alpha", "alpha", "beta"), c("alpha", "beta")), 1)
})

test_that("jaccard drops NA tokens instead of counting them as shared", {
  # The script-local copies counted NA as a shared token:
  # jaccard(c(NA,"alpha"), c(NA,"beta")) was 1/3. The canonical version
  # drops NA on both sides.
  expect_identical(jaccard(c(NA, "alpha"), c(NA, "beta")), 0)
  expect_identical(jaccard(c(NA, "alpha"), "alpha"), 1)
  # Both sides all-NA reduce to empty -> 0, not NaN.
  expect_identical(jaccard(NA_character_, NA_character_), 0)
})

test_that("jaccard stays in [0, 1] over randomized token sets", {
  withr::with_seed(42, {
    for (i in seq_len(20)) {
      a <- sample(letters, sample(0:10, 1))
      b <- sample(letters, sample(0:10, 1))
      s <- jaccard(a, b)
      expect_gte(s, 0)
      expect_lte(s, 1)
    }
  })
})

# ---------------------------------------------------------------------------
# top_n_matches: ranking semantics
# ---------------------------------------------------------------------------

make_grid <- function() {
  # 2 groups x 5 candidates, hand-set scores. Group r2 carries a tie at
  # ranks 2-3 (c2 and c4 both 0.4).
  tibble::tibble(
    group     = rep(c("r1", "r2"), each = 5),
    candidate = rep(c("c1", "c2", "c3", "c4", "c5"), times = 2),
    score     = c(0.10, 0.50, 0.30, 0.20, 0.40,
                  0.60, 0.40, 0.10, 0.40, 0.05)
  )
}

test_that("top_n_matches returns n rows per group, ranked 1..n, scores non-increasing", {
  out <- top_n_matches(make_grid(), n = 3)
  expect_equal(nrow(out), 6L)
  for (g in c("r1", "r2")) {
    rows <- out[out$group == g, ]
    expect_equal(rows$rank, 1:3)
    expect_true(all(diff(rows$score) <= 0))
  }
  # Rank-1 equals the independently-computed max per group.
  r1 <- out[out$rank == 1L, ]
  expect_equal(r1$score[r1$group == "r1"], 0.50)
  expect_equal(r1$score[r1$group == "r2"], 0.60)
  expect_equal(r1$candidate[r1$group == "r1"], "c2")
  expect_equal(r1$candidate[r1$group == "r2"], "c1")
})

test_that("top_n_matches breaks ties deterministically regardless of input row order", {
  # The scripts' idiom breaks ties by input row order, which inherits
  # SPARQL result order -- not contractually stable, so a published best
  # match could flip between graph rebuilds. The canonical helper breaks
  # ties by ascending candidate id; shuffling the input must not change
  # the output.
  grid <- make_grid()
  out_fwd <- top_n_matches(grid, n = 3)
  out_rev <- top_n_matches(grid[rev(seq_len(nrow(grid))), ], n = 3)
  expect_equal(out_fwd, out_rev)

  # In group r2, c2 and c4 tie at 0.4: c2 (lexicographically first) must
  # take rank 2.
  r2 <- out_fwd[out_fwd$group == "r2", ]
  expect_equal(r2$candidate, c("c1", "c2", "c4"))
})

test_that("top_n_matches returns all candidates when a group has fewer than n", {
  grid <- tibble::tibble(
    group     = "r1",
    candidate = c("c1", "c2"),
    score     = c(0.2, 0.5)
  )
  out <- top_n_matches(grid, n = 3)
  expect_equal(nrow(out), 2L)
  expect_equal(out$rank, 1:2)
  expect_equal(out$candidate, c("c2", "c1"))
})

test_that("top_n_matches flags all-zero groups instead of presenting an arbitrary best match", {
  # An empty-document unit scores 0 against every candidate; without the
  # flag, an arbitrary candidate is presented as a rank-1 "best match"
  # indistinguishable from a real one -- a credibility bug in published
  # concordance tables.
  grid <- tibble::tibble(
    group     = c("r1", "r1", "r2", "r2"),
    candidate = c("c1", "c2", "c1", "c2"),
    score     = c(0, 0, 0.3, 0)
  )
  out <- top_n_matches(grid, n = 1)
  expect_true(out$zero_match[out$group == "r1"])
  expect_false(out$zero_match[out$group == "r2"])
})

test_that("top_n_matches on an empty grid returns zero rows with the full schema", {
  grid <- tibble::tibble(
    group     = character(0),
    candidate = character(0),
    score     = numeric(0)
  )
  out <- top_n_matches(grid, n = 3)
  expect_equal(nrow(out), 0L)
  expect_true(all(c("group", "candidate", "score", "rank", "zero_match")
                  %in% names(out)))
})

test_that("top_n_matches rejects a grid missing required columns", {
  expect_error(
    top_n_matches(tibble::tibble(group = "r1", similarity = 0.5)),
    class = "cybedtools_bad_grid"
  )
})

test_that("filtering top_n_matches to rank 1 yields exactly one row per group", {
  out <- top_n_matches(make_grid(), n = 3)
  best <- out[out$rank == 1L, ]
  expect_equal(nrow(best), 2L)
  expect_true(all(table(best$group) == 1))
})

# ---------------------------------------------------------------------------
# similarity_strength: tier boundaries
# ---------------------------------------------------------------------------

test_that("similarity_strength boundaries are inclusive at 0.30 / 0.20 / 0.10", {
  expect_identical(
    similarity_strength(c(0.30, 0.299, 0.20, 0.199, 0.10, 0.099, 0, 1)),
    c("strong", "moderate", "moderate", "weak", "weak", "none", "none",
      "strong")
  )
})

test_that("round-then-tier can promote a raw value across a boundary (documented interaction)", {
  # The k12 script rounds to 3 dp BEFORE tiering, so boundary membership
  # is a function of rounding: raw 0.29951 rounds to 0.300 -> "strong"
  # even though the raw value is below the threshold; raw 0.09951 rounds
  # to 0.100 -> "weak"; raw 0.09949 rounds to 0.099 -> "none". Pinned as
  # the decided production order (round, then tier).
  expect_identical(similarity_strength(round(0.29951, 3)), "strong")
  expect_identical(similarity_strength(round(0.09951, 3)), "weak")
  expect_identical(similarity_strength(round(0.09949, 3)), "none")
})

# ---------------------------------------------------------------------------
# filter_units_by_framework: data-masking collision guard
# ---------------------------------------------------------------------------

test_that("filter_units_by_framework is immune to same-named columns in the data", {
  # The confirmed footgun: a helper parameter named after a column
  # (framework, framework_name, ...) is silently shadowed inside dplyr
  # data-masking verbs and returns 0 rows with no warning. This fixture
  # deliberately carries columns named `framework` AND `fw_pattern` (the
  # helper's own parameter name); the filter must still work.
  units <- tibble::tibble(
    unit           = c("u1", "u2", "u3"),
    framework_name = c("NICE Framework v2", "ENISA ECSF 2022", "NICE Framework v2"),
    framework      = c("no-match", "no-match", "no-match"),
    fw_pattern     = c("no-match", "no-match", "no-match")
  )
  out <- filter_units_by_framework(units, "^NICE")
  expect_equal(out$unit, c("u1", "u3"))
  expect_equal(nrow(filter_units_by_framework(units, "ECSF")), 1L)
  expect_equal(nrow(filter_units_by_framework(units, "^ZZZ")), 0L)
})

# ---------------------------------------------------------------------------
# Drift tripwires against the still-live script-local copies.
# These parse (never execute) the concordance scripts. They skip on the
# built tarball, where concordance/ is excluded by .Rbuildignore.
# ---------------------------------------------------------------------------

concordance_script_paths <- function() {
  dir <- testthat::test_path("..", "..", "concordance")
  paths <- file.path(dir, c(
    "_data-prep-k12-alignment.R",
    "_data-prep-nice-ecsf-alignment.R",
    "_data-prep-nice-csec2017-alignment.R"
  ))
  if (!all(file.exists(paths))) {
    testthat::skip("concordance scripts not available (built-tarball check)")
  }
  paths
}

# Extract the RHS expression of a top-level `name <- ...` assignment from a
# script WITHOUT executing the script.
extract_assignment <- function(path, name) {
  exprs <- parse(path, keep.source = FALSE)
  for (e in exprs) {
    if (is.call(e) &&
        (identical(e[[1]], as.name("<-")) || identical(e[[1]], as.name("="))) &&
        identical(e[[2]], as.name(name))) {
      return(e[[3]])
    }
  }
  NULL
}

test_that("script-local jaccard and tokenize definitions have not drifted apart", {
  # Tripwire only: delete once the scripts call the package versions.
  paths <- concordance_script_paths()

  jac <- lapply(paths, extract_assignment, name = "jaccard")
  tok <- lapply(paths, extract_assignment, name = "tokenize")
  expect_false(any(vapply(jac, is.null, logical(1))))
  expect_false(any(vapply(tok, is.null, logical(1))))

  jac_txt <- vapply(jac, \(e) paste(deparse(e), collapse = "\n"), character(1))
  tok_txt <- vapply(tok, \(e) paste(deparse(e), collapse = "\n"), character(1))
  expect_true(all(jac_txt == jac_txt[[1]]))
  expect_true(all(tok_txt == tok_txt[[1]]))
})

test_that("script-local stopword lists match the package profiles exactly", {
  paths <- concordance_script_paths()
  names(paths) <- c("k12", "ecsf", "csec")

  sw <- lapply(paths, \(p) eval(extract_assignment(p, "stopwords"),
                                envir = baseenv()))
  expect_identical(sw$k12,  similarity_stopwords("k12"))
  expect_identical(sw$ecsf, similarity_stopwords("workforce"))
  expect_identical(sw$csec, similarity_stopwords("workforce"))
})

test_that("package tokenize agrees with the script-local tokenize on real-shaped input", {
  testthat::skip_if_not_installed("stringr")
  paths <- concordance_script_paths()

  # Evaluate the k12 script's tokenize + stopwords in an isolated env with
  # just the stringr verbs it uses.
  script_env <- new.env(parent = baseenv())
  script_env$str_split    <- stringr::str_split
  script_env$str_to_lower <- stringr::str_to_lower
  script_env$stopwords    <- eval(extract_assignment(paths[[1]], "stopwords"),
                                  envir = baseenv())
  script_tokenize <- eval(extract_assignment(paths[[1]], "tokenize"),
                          envir = script_env)

  samples <- c(
    "The Firewall protects the network",
    "token-based two-factor authentication",
    "Authentication methods such as certificate, token-based, and biometric.",
    "Wi-Fi AI OS 5G",
    "a1b c2d3 800 53",
    "   ",
    ""
  )
  for (s in samples) {
    expect_identical(
      tokenize(s, stopwords = similarity_stopwords("k12")),
      script_tokenize(s),
      info = paste0("input: '", s, "'")
    )
  }
})

test_that("footgun tripwire: no cur_data() and no framework-named parameters in package or concordance code", {
  # rowwise()+cur_data() produced silently wrong per-row lookups in this
  # project's ad-hoc scripts (deprecated in dplyr >= 1.1.0); a function
  # parameter named `framework` is silently shadowed by the same-named
  # column inside data-masking verbs. Both are banned; this grep fails
  # loudly on reintroduction.
  r_files <- list.files(testthat::test_path("..", "..", "R"),
                        pattern = "\\.R$", full.names = TRUE)
  conc_dir <- testthat::test_path("..", "..", "concordance")
  conc_files <- if (dir.exists(conc_dir)) {
    list.files(conc_dir, pattern = "^_data-prep-.*\\.R$", full.names = TRUE)
  } else {
    character(0)
  }

  for (f in c(r_files, conc_files)) {
    src <- readLines(f, warn = FALSE)
    # Strip comment lines (including roxygen): prose ABOUT the footguns --
    # e.g. the sparql-helpers roxygen note warning against
    # `function(framework, ...)` -- must not trip the wire; only code does.
    src <- src[!grepl("^\\s*#", src)]
    expect_false(any(grepl("cur_data\\(", src)),
                 info = paste0("cur_data() found in ", basename(f)))
    expect_false(any(grepl("function\\s*\\(\\s*framework\\s*[,)=]", src)),
                 info = paste0("`framework`-named first parameter in ",
                               basename(f)))
  }
})
