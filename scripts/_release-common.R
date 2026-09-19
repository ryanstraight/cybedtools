# Pure helpers for scripts/030-export-release.R.
#
# Source this from the export stage after its library() block:
#   source(here("scripts", "_release-common.R"), local = TRUE)
#
# Nothing here reads a file from data/ or writes to it. Every function takes
# its inputs as arguments and returns a value, so tests/testthat can exercise
# the whole policy surface on synthetic lines. scripts/ is .Rbuildignore'd, so
# nothing here ships in the package.
#
# ---------------------------------------------------------------------------
# Why the sort is what it is
# ---------------------------------------------------------------------------
#
# A published hash is only worth publishing if the same input gives the same
# bytes on someone else's machine. Two things in an ordinary R export are not
# machine-independent, and both are handled here rather than left to chance.
#
# Collation. sort() on a character vector follows LC_COLLATE, which differs
# between a Windows session, a macOS session and a C-locale container, and
# would reorder the file for no substantive reason. order(method = "radix")
# ignores LC_COLLATE and sorts in the C locale, which is a bytewise order over
# the ASCII range. The serialiser escapes every non-ASCII character as \uXXXX,
# so every line is ASCII and the C-locale order is the byte order.
#
# gzip framing. A gzip member carries a modification time and an operating
# system byte in its header, so the same bytes compressed twice produce two
# different files. gzip_bytes() writes the header itself with the time zeroed,
# no original filename, and the OS byte set to unknown, over a deflate stream
# taken from zlib at its default settings.

# ---------------------------------------------------------------------------
# N-Triples line anatomy
# ---------------------------------------------------------------------------

nt_predicate_pattern <- "^(?:<[^>]*>|_:[^[:space:]]+)[[:space:]]+<([^>]*)>[[:space:]]"

#' Predicate IRI of each N-Triples line, NA for a line that does not parse.
nt_predicates <- function(lines) {
  matched <- regmatches(lines, regexec(nt_predicate_pattern, lines))
  vapply(
    matched,
    function(parts) if (length(parts) >= 2L) parts[[2L]] else NA_character_,
    character(1)
  )
}

#' Object term of each N-Triples line, with the closing " ." removed.
nt_objects <- function(lines) {
  stripped <- sub(nt_predicate_pattern, "", lines)
  sub("[[:space:]]*\\.[[:space:]]*$", "", stripped)
}

#' Character length of each line's literal object, NA where the object is an
#' IRI or a blank node. Escapes are counted as written, which overstates the
#' length of an escaped literal and so can only make the backstop stricter.
nt_literal_lengths <- function(lines) {
  objects <- nt_objects(lines)
  matched <- regmatches(
    objects,
    regexec("^\"((?:[^\"\\\\]|\\\\.)*)\"", objects, perl = TRUE)
  )
  vapply(
    matched,
    function(parts) if (length(parts) >= 2L) nchar(parts[[2L]]) else NA_integer_,
    integer(1)
  )
}

#' Subjects of the lines asserting a given rdf:type.
nt_subjects_of_type <- function(lines, class_iri) {
  pattern <- paste0(
    "^<([^>]*)>[[:space:]]+<http://www\\.w3\\.org/1999/02/22-rdf-syntax-ns#type>",
    "[[:space:]]+<", class_iri, ">[[:space:]]*\\.[[:space:]]*$"
  )
  matched <- regmatches(lines, regexec(pattern, lines))
  hits <- vapply(
    matched,
    function(parts) if (length(parts) >= 2L) parts[[2L]] else NA_character_,
    character(1)
  )
  hits[!is.na(hits)]
}

#' The single literal asserted on `subject` under `predicate`, or NA.
nt_literal_of <- function(lines, subject, predicate) {
  keep <- startsWith(lines, paste0("<", subject, "> <", predicate, "> "))
  if (!any(keep)) {
    return(NA_character_)
  }
  values <- nt_literal_text(lines[keep])
  values[[1L]]
}

#' Unescaped text of each literal object, NA where the object is not a literal.
nt_literal_text <- function(lines) {
  objects <- nt_objects(lines)
  matched <- regmatches(
    objects,
    regexec("^\"((?:[^\"\\\\]|\\\\.)*)\"", objects, perl = TRUE)
  )
  vapply(
    matched,
    function(parts) {
      if (length(parts) < 2L) {
        return(NA_character_)
      }
      value <- parts[[2L]]
      value <- gsub("\\\\\"", "\"", value)
      value <- gsub("\\\\n", "\n", value)
      value <- gsub("\\\\t", "\t", value)
      gsub("\\\\\\\\", "\\\\", value)
    },
    character(1)
  )
}

# ---------------------------------------------------------------------------
# Canonical form
# ---------------------------------------------------------------------------

#' Canonical N-Triples line order: blanks dropped, exact duplicates dropped,
#' remaining lines sorted bytewise in the C locale regardless of the session's
#' collation.
canonical_lines <- function(lines) {
  lines <- lines[nzchar(lines)]
  lines <- unique(lines)
  lines[order(lines, method = "radix")]
}

#' Canonical uncompressed payload: LF line endings, one trailing newline, and
#' an empty input yielding zero bytes rather than a lone newline.
canonical_payload <- function(lines) {
  if (!length(lines)) {
    return(raw(0))
  }
  charToRaw(paste0(paste(lines, collapse = "\n"), "\n"))
}

#' A gzip member whose bytes depend only on the payload.
#'
#' The header is written here rather than taken from a connection: byte 5
#' through byte 8 are the modification time, which zlib fills with the clock,
#' and byte 10 is the operating system, which zlib fills from the platform it
#' was built on. Both are pinned. The deflate stream is lifted out of the zlib
#' container memCompress() returns, which is a two-byte header, the deflate
#' data, and a four-byte checksum.
gzip_bytes <- function(payload) {
  if (!is.raw(payload)) {
    rlang::abort(
      "`payload` must be a raw vector.",
      class = "cybedtools_release_input"
    )
  }
  zlib <- memCompress(payload, type = "gzip")
  deflate <- zlib[3:(length(zlib) - 4L)]

  crc <- digest::digest(payload, algo = "crc32", serialize = FALSE)
  crc_bytes <- rev(as.raw(strtoi(
    substring(crc, c(1L, 3L, 5L, 7L), c(2L, 4L, 6L, 8L)),
    base = 16L
  )))

  header <- as.raw(c(
    0x1f, 0x8b, # magic
    0x08,       # deflate
    0x00,       # no flags, so no original filename and no comment
    0x00, 0x00, 0x00, 0x00, # modification time, zeroed
    0x00,       # no extra flags
    0xff        # operating system unknown
  ))
  c(header, deflate, crc_bytes, uint32_le(length(payload)))
}

uint32_le <- function(n) {
  n <- as.numeric(n) %% 4294967296
  as.raw(c(
    n %% 256,
    (n %/% 256) %% 256,
    (n %/% 65536) %% 256,
    (n %/% 16777216) %% 256
  ))
}

# ---------------------------------------------------------------------------
# Policy filters
# ---------------------------------------------------------------------------

#' Drop every triple whose predicate carries framework statement text.
strip_text_predicates <- function(lines, omit_predicates) {
  predicates <- nt_predicates(lines)
  lines[is.na(predicates) | !predicates %in% omit_predicates]
}

#' Backstop on a structure-only file. Stops on any surviving literal longer
#' than `threshold` outside the allow-listed predicates.
assert_no_long_literals <- function(lines,
                                    threshold,
                                    allow_predicates = character(0),
                                    slug = "unknown") {
  predicates <- nt_predicates(lines)
  lengths <- nt_literal_lengths(lines)
  offending <- which(
    !is.na(lengths) &
      lengths > threshold &
      !(predicates %in% allow_predicates)
  )

  if (length(offending)) {
    worst <- offending[order(lengths[offending], decreasing = TRUE)]
    worst <- utils::head(worst, 5L)
    rlang::abort(
      c(
        "Structure-only export retained a literal longer than the release bound.",
        "x" = paste0("Framework: ", slug, "."),
        "x" = paste0(
          "Longest offenders: ",
          paste(
            sprintf("%s (%d characters)", predicates[worst], lengths[worst]),
            collapse = "; "
          ),
          "."
        ),
        "i" = paste0(
          "The bound is ", threshold,
          " characters. Either the predicate carries statement text and belongs ",
          "in structure_only_omit_predicates, or it is structural and belongs ",
          "in long_literal_allow_predicates. Refusing to write."
        )
      ),
      class = "cybedtools_release_long_literal",
      framework_slug = slug
    )
  }
  invisible(lines)
}

# ---------------------------------------------------------------------------
# Allowlist and policy reconciliation
# ---------------------------------------------------------------------------

#' Check the release config against the redistribution policy table.
#'
#' Two independent gates, both fail closed. A slug on the allowlist whose
#' policy is local_only stops the export; it is never skipped, because a slug
#' listed for release and refused by policy is a contradiction a human has to
#' resolve. A framework declared in the invariants and named nowhere in the
#' config also stops the export.
#'
#' @param config The parsed docs/data-release.yml.
#' @param policy A data frame of framework_slug and policy, one row per
#'   framework declared in docs/framework-invariants.yml.
assert_release_allowlist <- function(config, policy) {
  shipped <- as.character(config$shipped %||% character(0))
  held <- names(config$held %||% list())
  refused <- names(config$refused %||% list())

  if (!length(shipped)) {
    rlang::abort(
      "The release config ships no frameworks.",
      class = "cybedtools_release_config"
    )
  }

  declared <- c(shipped, held, refused)
  repeated <- unique(declared[duplicated(declared)])
  if (length(repeated)) {
    rlang::abort(
      c(
        "A framework is declared more than once in the release config.",
        "x" = paste0("Repeated: ", paste(sort(repeated), collapse = ", "), ".")
      ),
      class = "cybedtools_release_config"
    )
  }

  unknown <- setdiff(declared, policy$framework_slug)
  if (length(unknown)) {
    rlang::abort(
      c(
        "The release config names frameworks the invariants file does not declare.",
        "x" = paste0("Unknown: ", paste(sort(unknown), collapse = ", "), "."),
        "i" = "An unmapped framework is unknown terms, not safe terms."
      ),
      class = "cybedtools_release_config"
    )
  }

  undeclared <- setdiff(policy$framework_slug, declared)
  if (length(undeclared)) {
    rlang::abort(
      c(
        "A declared framework is neither shipped, held nor refused.",
        "x" = paste0("Unplaced: ", paste(sort(undeclared), collapse = ", "), "."),
        "i" = "Place every framework explicitly so nothing is omitted by accident."
      ),
      class = "cybedtools_release_config"
    )
  }

  shipped_policy <- policy$policy[match(shipped, policy$framework_slug)]
  blocked <- shipped[shipped_policy == "local_only"]
  if (length(blocked)) {
    rlang::abort(
      c(
        "A framework on the release allowlist is refused by its redistribution policy.",
        "x" = paste0("Blocked: ", paste(sort(blocked), collapse = ", "), "."),
        "i" = paste0(
          "local_only reaches the structure as well as the text, so no file ",
          "may be written. Remove the slug from `shipped` or change the terms. ",
          "Refusing to write."
        )
      ),
      class = "cybedtools_release_policy_refusal",
      framework_slug = blocked
    )
  }

  refused_policy <- policy$policy[match(refused, policy$framework_slug)]
  mismatched <- refused[refused_policy != "local_only"]
  if (length(mismatched)) {
    rlang::abort(
      c(
        "A framework listed as refused is not local_only in the invariants file.",
        "x" = paste0("Mismatched: ", paste(sort(mismatched), collapse = ", "), "."),
        "i" = "The refusal list records a policy, it does not create one."
      ),
      class = "cybedtools_release_config"
    )
  }

  invisible(config)
}

#' Content scope for a framework under its policy.
release_scope <- function(policy_value) {
  switch(
    policy_value,
    unrestricted          = "full",
    full_with_attribution = "full",
    structure_only        = "structure_only",
    rlang::abort(
      c(
        "No release scope is defined for that redistribution policy.",
        "x" = paste0("Policy: ", policy_value, ".")
      ),
      class = "cybedtools_release_policy_refusal"
    )
  )
}

#' The framework_licenses row for a framework slug.
#'
#' The licence table keys on the versioned framework slug (nice-v2,
#' otccf-v1.1) and the invariants file keys on the bare slug (nice, otccf), so
#' the match is exact first and then on the version suffix. A slug with no row,
#' or with more than one candidate row, stops the export: a shipped file
#' without licence terms is the one thing this stage must never write.
release_license_row <- function(licenses, slug) {
  exact <- licenses[licenses$slug == slug, , drop = FALSE]
  if (nrow(exact) == 1L) {
    return(exact)
  }

  candidates <- licenses[startsWith(licenses$slug, paste0(slug, "-")), , drop = FALSE]
  if (nrow(candidates) == 1L) {
    return(candidates)
  }

  rlang::abort(
    c(
      if (nrow(candidates) == 0L) {
        "No licence row for a framework on the release allowlist."
      } else {
        "More than one licence row matches a framework on the release allowlist."
      },
      "x" = paste0("Slug: '", slug, "'."),
      "i" = paste0("Known slugs: ", paste(licenses$slug, collapse = ", "), "."),
      "i" = "Refusing to write a file whose terms cannot be stated."
    ),
    class = "cybedtools_release_license_missing",
    framework_slug = slug
  )
}

# ---------------------------------------------------------------------------
# Deterministic JSON
# ---------------------------------------------------------------------------

#' Recursively order every named list by name, so the manifest's key order is a
#' property of the data rather than of the order the builder happened to use.
sort_keys <- function(x) {
  if (is.list(x)) {
    x <- lapply(x, sort_keys)
    if (!is.null(names(x)) && all(nzchar(names(x)))) {
      x <- x[order(names(x), method = "radix")]
    }
  }
  x
}

#' Manifest JSON text: sorted keys, integers written without a decimal part,
#' LF line endings, one trailing newline.
manifest_json <- function(manifest) {
  text <- jsonlite::toJSON(
    sort_keys(manifest),
    auto_unbox = TRUE,
    pretty = 2,
    null = "null",
    na = "null",
    digits = NA
  )
  paste0(gsub("\r\n", "\n", as.character(text), fixed = TRUE), "\n")
}

`%||%` <- function(a, b) if (is.null(a)) b else a
