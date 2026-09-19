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

#' Subject IRI of each N-Triples line, NA for a blank node or a line that does
#' not parse.
nt_subjects <- function(lines) {
  matched <- regmatches(lines, regexec("^<([^>]*)>[[:space:]]", lines))
  vapply(
    matched,
    function(parts) if (length(parts) >= 2L) parts[[2L]] else NA_character_,
    character(1)
  )
}

#' Object IRI of each N-Triples line, NA where the object is a literal or a
#' blank node.
nt_object_iris <- function(lines) {
  objects <- nt_objects(lines)
  matched <- regmatches(objects, regexec("^<([^>]*)>$", objects))
  vapply(
    matched,
    function(parts) if (length(parts) >= 2L) parts[[2L]] else NA_character_,
    character(1)
  )
}

#' The local part of an IRI: the text after the last `#` or `/`.
#'
#' This is what identifies a node stably within its framework. A name is not:
#' names are prose, they repeat across frameworks, and matching one on a
#' substring would silently catch neighbours.
iri_local_part <- function(iri) {
  sub("^.*[#/]", "", iri)
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
# Exclusions inside a shipped file
# ---------------------------------------------------------------------------
#
# An exclusion removes a named part of a framework from a file the release
# otherwise ships whole. The mechanism is general: it is driven by the
# `exclusions` list in docs/data-release.yml and knows nothing about any
# particular framework.
#
# The one kind implemented is `unit_element_links`: drop the mappings from
# named organizing units to the framework's statements, then drop the
# statements that those mappings were the only route to.

cybed_organizing_unit_iri <- "https://w3id.org/cybed/ontology#OrganizingUnit"
cybed_role_element_iri <- "https://w3id.org/cybed/ontology#RoleElement"
cybed_subpoint_iri <- "https://w3id.org/cybed/ontology#Subpoint"
cybed_elaborates_iri <- "https://w3id.org/cybed/ontology#elaborates"

release_exclusion_kinds <- function() {
  "unit_element_links"
}

#' The predicates that link an organizing unit to one of its elements, and
#' which end of the triple carries the unit.
#'
#' Taken from a predicate census of all eleven per-framework N-Triples files,
#' not assumed. cybed:hasElement is the only unit-to-element link predicate in
#' the graph, and the unit is always its subject. The graph has no inverse:
#' cybed:partOf points at the framework node and never at a unit, and
#' cybed:elaborates runs from a sub-point to its parent element, which is a
#' link between two elements rather than between a unit and an element.
#'
#' The side is declared rather than inferred because a node's IRI does not
#' always say which end it is. Some frameworks mint one IRI per source
#' identifier and reuse an identifier for a unit and for a statement, so the
#' same IRI can be a unit in one triple and an element in another. Matching an
#' excluded unit on whichever end it happens to appear would then drop another
#' unit's mappings, which is a cut nobody asked for. The declared side makes
#' the direction explicit: an inverse predicate added here is honoured, and an
#' IRI appearing on the element side of a link is treated as an element.
unit_element_link_predicates <- function() {
  list(
    list(
      predicate = "https://w3id.org/cybed/ontology#hasElement",
      unit_side = "subject"
    )
  )
}

#' Index of the unit-to-element links in `lines`.
#'
#' Returns, per line, whether it is a link on one of `specs`, and the IRIs on
#' its unit side and its element side.
unit_element_link_index <- function(lines, specs = unit_element_link_predicates()) {
  subjects <- nt_subjects(lines)
  predicates <- nt_predicates(lines)
  objects <- nt_object_iris(lines)

  is_link <- rep(FALSE, length(lines))
  unit_end <- rep(NA_character_, length(lines))
  element_end <- rep(NA_character_, length(lines))

  for (spec in specs) {
    on_predicate <- !is.na(predicates) & predicates == spec$predicate &
      !is.na(subjects) & !is.na(objects)
    is_link <- is_link | on_predicate
    if (identical(spec$unit_side, "subject")) {
      unit_end[on_predicate] <- subjects[on_predicate]
      element_end[on_predicate] <- objects[on_predicate]
    } else {
      unit_end[on_predicate] <- objects[on_predicate]
      element_end[on_predicate] <- subjects[on_predicate]
    }
  }

  list(is_link = is_link, unit_end = unit_end, element_end = element_end)
}

#' Resolve the unit ids named by an exclusion to the IRIs they identify.
#'
#' Typo protection, and the reason this fails closed. An id that matches no
#' organizing unit in this framework's file stops the export rather than
#' excluding nothing, because an exclusion that silently does nothing is worse
#' than one that never ran: it would ship the very triples it was written to
#' withhold, under a manifest claiming they were withheld.
resolve_exclusion_units <- function(lines, unit_ids, slug = "unknown") {
  unit_ids <- as.character(unit_ids)
  units <- unique(nt_subjects_of_type(lines, cybed_organizing_unit_iri))
  locals <- iri_local_part(units)

  resolved <- vapply(unit_ids, function(id) {
    hit <- units[locals == id]
    if (length(hit) == 1L) hit else NA_character_
  }, character(1))

  unresolved <- unit_ids[is.na(resolved)]
  if (length(unresolved)) {
    rlang::abort(
      c(
        "An exclusion names a unit that framework's file does not carry.",
        "x" = paste0("Framework: ", slug, "."),
        "x" = paste0("Unresolved: ", paste(unresolved, collapse = ", "), "."),
        "i" = paste0(
          "Units are matched on the exact local part of their IRI. An ",
          "exclusion that matches nothing would ship the triples it claims ",
          "to withhold. Refusing to write."
        )
      ),
      class = "cybedtools_release_exclusion_unit",
      framework_slug = slug
    )
  }

  unname(resolved)
}

#' Apply a `unit_element_links` exclusion.
#'
#' Two steps, in this order.
#'
#' First, drop every unit-to-element link whose unit side is an excluded unit.
#' That is the exclusion proper: the mappings go, the unit node stays.
#'
#' Second, drop the elements those links were the only route to. An element is
#' an orphan when it lost a link here and no unit in this file still links to
#' it. Its own triples go with it, and so do the sub-points and examples that
#' elaborate it, walked to a fixed point so a chain of sub-points cannot leave
#' a tail behind. An element any other unit also draws on is left untouched,
#' with every one of its other links intact.
#'
#' A node that is itself an organizing unit is never dropped as an orphan. Unit
#' nodes stay by the terms of the exclusion, and in a framework that reuses one
#' identifier for a unit and for a statement the two are the same IRI.
#'
#' Elements that were already attached to no unit before the exclusion ran are
#' left alone. Only elements this exclusion disconnected are candidates, so the
#' cut is bounded by what the exclusion actually did.
exclude_unit_element_links <- function(lines,
                                       unit_iris,
                                       specs = unit_element_link_predicates(),
                                       slug = "unknown") {
  index <- unit_element_link_index(lines, specs)
  drop_link <- index$is_link & index$unit_end %in% unit_iris

  link_triples_dropped <- sum(drop_link)
  candidates <- unique(index$element_end[drop_link])
  kept <- lines[!drop_link]

  units_all <- unique(nt_subjects_of_type(lines, cybed_organizing_unit_iri))
  subpoints <- unique(nt_subjects_of_type(lines, cybed_subpoint_iri))

  kept_index <- unit_element_link_index(kept, specs)
  still_linked <- unique(
    kept_index$element_end[kept_index$is_link & kept_index$unit_end %in% units_all]
  )

  drop_nodes <- setdiff(candidates, c(still_linked, units_all))

  kept_subjects <- nt_subjects(kept)
  kept_predicates <- nt_predicates(kept)
  kept_objects <- nt_object_iris(kept)
  elaborates <- !is.na(kept_predicates) & kept_predicates == cybed_elaborates_iri &
    !is.na(kept_subjects) & !is.na(kept_objects)

  repeat {
    orphaned_children <- unique(kept_subjects[elaborates & kept_objects %in% drop_nodes])
    extra <- setdiff(orphaned_children, c(drop_nodes, still_linked, units_all))
    if (!length(extra)) {
      break
    }
    drop_nodes <- c(drop_nodes, extra)
  }

  touches <- (!is.na(kept_subjects) & kept_subjects %in% drop_nodes) |
    (!is.na(kept_objects) & kept_objects %in% drop_nodes)
  element_triples_dropped <- sum(touches)

  list(
    lines = kept[!touches],
    link_triples_dropped = as.integer(link_triples_dropped),
    elements_dropped = length(drop_nodes),
    element_triples_dropped = as.integer(element_triples_dropped),
    subpoints_dropped = sum(drop_nodes %in% subpoints),
    dropped_nodes = drop_nodes
  )
}

#' Backstop on an excluded file. Stops if any unit-to-element link from an
#' excluded unit survived the cut.
#'
#' Nothing published here is retractable, so the claim the manifest makes is
#' checked against the lines about to be written rather than trusted.
assert_no_unit_element_links <- function(lines,
                                         unit_iris,
                                         specs = unit_element_link_predicates(),
                                         slug = "unknown") {
  index <- unit_element_link_index(lines, specs)
  surviving <- index$is_link & index$unit_end %in% unit_iris

  if (any(surviving)) {
    offenders <- unique(iri_local_part(index$unit_end[surviving]))
    rlang::abort(
      c(
        "An excluded unit still links to an element after the exclusion ran.",
        "x" = paste0("Framework: ", slug, "."),
        "x" = paste0(sum(surviving), " link triple(s) survived."),
        "x" = paste0("Units: ", paste(sort(offenders), collapse = ", "), "."),
        "i" = "Refusing to write."
      ),
      class = "cybedtools_release_exclusion_verification",
      framework_slug = slug
    )
  }
  invisible(lines)
}

#' The exclusion entries that apply to one framework slug.
release_exclusions_for <- function(config, slug) {
  entries <- config$exclusions %||% list()
  Filter(function(entry) identical(as.character(entry$framework), slug), entries)
}

#' Check the exclusion list against the release allowlist.
#'
#' An exclusion for a framework the release does not ship is a contradiction a
#' human has to resolve, not a line to skip: either the slug was meant to ship
#' and was left off the allowlist, or the exclusion is stale and is claiming a
#' cut nothing applies.
assert_release_exclusions <- function(config) {
  entries <- config$exclusions %||% list()
  if (!length(entries)) {
    return(invisible(config))
  }
  shipped <- as.character(config$shipped %||% character(0))

  for (entry in entries) {
    slug <- as.character(entry$framework %||% NA_character_)
    kind <- as.character(entry$kind %||% NA_character_)

    if (length(slug) != 1L || is.na(slug) || !nzchar(slug)) {
      rlang::abort(
        "An exclusion does not name a framework.",
        class = "cybedtools_release_exclusion_config"
      )
    }
    if (!slug %in% shipped) {
      rlang::abort(
        c(
          "An exclusion names a framework the release does not ship.",
          "x" = paste0("Framework: ", slug, "."),
          "i" = paste0(
            "Either the slug belongs on the `shipped` allowlist or the ",
            "exclusion is stale. Refusing to write."
          )
        ),
        class = "cybedtools_release_exclusion_config",
        framework_slug = slug
      )
    }
    if (length(kind) != 1L || is.na(kind) || !kind %in% release_exclusion_kinds()) {
      rlang::abort(
        c(
          "An exclusion declares a kind the export does not implement.",
          "x" = paste0("Framework: ", slug, ", kind: ", kind, "."),
          "i" = paste0("Known kinds: ",
                       paste(release_exclusion_kinds(), collapse = ", "), ".")
        ),
        class = "cybedtools_release_exclusion_config",
        framework_slug = slug
      )
    }
    if (!length(entry$units %||% NULL)) {
      rlang::abort(
        c(
          "An exclusion names no units.",
          "x" = paste0("Framework: ", slug, ".")
        ),
        class = "cybedtools_release_exclusion_config",
        framework_slug = slug
      )
    }
    reason <- as.character(entry$reason %||% NA_character_)
    if (length(reason) != 1L || is.na(reason) || !nzchar(reason)) {
      rlang::abort(
        c(
          "An exclusion carries no reason.",
          "x" = paste0("Framework: ", slug, "."),
          "i" = "The reason is published verbatim, so a file cannot ship without one."
        ),
        class = "cybedtools_release_exclusion_config",
        framework_slug = slug
      )
    }
  }

  invisible(config)
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

#' Every scope value a manifest entry may carry.
#'
#' `full` is every triple the harmonised graph holds for the framework.
#' `structure_only` is that file with the statement text removed.
#' `full_with_exclusions` is a full file with a named part withheld under an
#' entry in the config's `exclusions` list.
release_scope_values <- function() {
  c("full", "structure_only", "full_with_exclusions")
}

#' Stop on a scope value outside the vocabulary.
assert_release_scope <- function(scope, slug = "unknown") {
  if (length(scope) != 1L || is.na(scope) || !scope %in% release_scope_values()) {
    rlang::abort(
      c(
        "A manifest entry carries a scope outside the release vocabulary.",
        "x" = paste0("Slug: ", slug, ", scope: ", scope, "."),
        "i" = paste0("Known scopes: ",
                     paste(release_scope_values(), collapse = ", "), ".")
      ),
      class = "cybedtools_release_config",
      framework_slug = slug
    )
  }
  invisible(scope)
}

#' The scope a file carries once an exclusion has been applied to it.
#'
#' Only a full file is defined here. An exclusion on a structure-only file
#' would be two cuts described by one word, and a reader could not tell from
#' the scope which of them accounts for a missing triple, so the combination
#' stops the export until someone names it.
release_scope_with_exclusions <- function(scope, slug = "unknown") {
  if (identical(scope, "full")) {
    return("full_with_exclusions")
  }
  rlang::abort(
    c(
      "No scope value is defined for an exclusion on this kind of file.",
      "x" = paste0("Slug: ", slug, ", scope: ", scope, "."),
      "i" = "Refusing to write a file whose scope cannot be stated."
    ),
    class = "cybedtools_release_exclusion_config",
    framework_slug = slug
  )
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
