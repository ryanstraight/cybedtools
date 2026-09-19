# Shared helpers for the scripts/010-ingest-*.R ingesters.
#
# Source this from an ingester after its library() block:
#   source(here("scripts", "_ingest-common.R"), local = TRUE)
#
# scripts/ is .Rbuildignore'd, so nothing here ships in the package.

# ---------------------------------------------------------------------------
# Retrieval dates
# ---------------------------------------------------------------------------
#
# retrieved_date records when a source file was obtained, not when an ingester
# last ran. Stamping format(Sys.Date(), "%Y-%m-%d") into the manifest on every
# run overwrote the real retrieval date of a file staged months earlier with
# today's, silently, and the only way back was to restore the value by hand.
#
# resolve_retrieved_date() carries the recorded date forward when the manifest
# already exists and the source file's hash is unchanged. A new date is stamped
# only when there is no manifest yet, or when a hash has moved, which is the
# only case in which the file was actually retrieved again.
#
# `hashes` is a named vector of <manifest retrieval field> = <sha256>, for
# example c(pdf_sha256 = pdf_sha, text_sha256 = text_sha). Every named field is
# compared against the value the existing manifest recorded under the same
# name. A field that is NA on both sides carries no information and is skipped;
# if every field is skipped, today's date is stamped.

resolve_retrieved_date <- function(manifest_path, hashes, today = Sys.Date()) {
  stamp <- format(today, "%Y-%m-%d")

  if (!length(hashes) || is.null(names(hashes)) ||
      anyNA(names(hashes)) || !all(nzchar(names(hashes)))) {
    stop("resolve_retrieved_date(): `hashes` must be a named vector of ",
         "<manifest retrieval field> = <sha256>.")
  }
  hashes <- vapply(hashes, function(h) {
    if (is.null(h) || !length(h)) NA_character_ else as.character(h)[1]
  }, character(1))
  hashes[!is.na(hashes) & !nzchar(hashes)] <- NA_character_

  if (!file.exists(manifest_path)) return(stamp)
  prev <- tryCatch(yaml::read_yaml(manifest_path), error = function(e) NULL)
  if (is.null(prev)) return(stamp)

  prev_ret <- prev$retrieval
  if (is.null(prev_ret)) return(stamp)
  prev_date <- prev_ret$retrieved_date
  if (is.null(prev_date) || !length(prev_date)) return(stamp)
  prev_date <- as.character(prev_date)[1]
  if (is.na(prev_date) || !nzchar(prev_date)) return(stamp)

  compared <- 0L
  for (field in names(hashes)) {
    current <- unname(hashes[[field]])
    recorded <- prev_ret[[field]]
    recorded <- if (is.null(recorded) || !length(recorded)) {
      NA_character_
    } else {
      as.character(recorded)[1]
    }
    if (is.na(current) && is.na(recorded)) next
    if (is.na(current) != is.na(recorded)) return(stamp)
    if (!identical(current, recorded)) return(stamp)
    compared <- compared + 1L
  }
  if (compared == 0L) return(stamp)

  prev_date
}
