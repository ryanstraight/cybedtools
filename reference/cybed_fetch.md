# Download and hash-verify per-framework release files into the user cache

**\[experimental\]**

Downloads the release manifest and the named frameworks' `.nt.gz` files
from the configured release location (see the release URL resolution
rules documented below), verifies each file's SHA-256 against the hash
the manifest declares, and writes only into
`tools::R_user_dir("cybedtools", "cache")` – never any other location on
disk, per CRAN policy. A file whose downloaded bytes do not match its
manifest hash is deleted and the call aborts with class
`cybedtools_hash_mismatch` rather than leaving a corrupt cache entry.

Already-cached files whose hash still matches the manifest are not
re-downloaded.

## Usage

``` r
cybed_fetch(frameworks = NULL, version = NULL)
```

## Arguments

- frameworks:

  Character vector of framework slugs to fetch, either the versioned
  form carried by
  [framework_summary](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)`$framework_slug`
  (e.g. `"nice-v2"`) or the short release-file slug (e.g. `"nice"`; see
  "Two slug vocabularies" above), or `NULL` (the default) for every
  framework the release manifest ships.

- version:

  Character scalar release version, either `"2026.09.2"` or
  `"data-v2026.09.2"` (a leading `"data-v"`, matching a GitHub release
  tag, is stripped), or `NULL` (the default) for the data release this
  package version was built against, `cybed_data_release`.

## Value

Invisibly, a tibble with one row per fetched framework: columns
`framework_slug` (the canonical versioned slug, e.g. `"nice-v2"`),
`release_slug` (the short release-file slug, e.g. `"nice"`), `path` (the
cached file's local path), `sha256_verified` (logical, always `TRUE` on
return – a mismatch aborts instead of returning `FALSE`).

## Two slug vocabularies

Two framework-slug vocabularies exist in this package.
[framework_summary](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)
and
[framework_licenses](https://ryanstraight.github.io/cybedtools/reference/framework_licenses.md)
use **versioned** slugs (`"nice-v2"`, `"otccf-v1.1"`), minted into every
framework node's IRI. The public data release's files use **short**
slugs (`"nice"`, `"otccf"`), assigned by `docs/data-release.yml` and
recorded in the release manifest. This function,
[`cybed_license()`](https://ryanstraight.github.io/cybedtools/reference/cybed_license.md),
and
[`framework_similarity()`](https://ryanstraight.github.io/cybedtools/reference/framework_similarity.md)
accept either form for a `frameworks`/`slug`/`from`/`to` argument and
resolve it to the canonical versioned slug. The returned tibble names
both forms explicitly (`framework_slug` and `release_slug`) rather than
silently substituting one for the other.

## See also

Other data loading:
[`load_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_graph.md)

## Examples

``` r
# \donttest{
# Requires network access (or a `cybedtools.release_url` override
# pointing at a local mock release for testing).
tryCatch(
  cybed_fetch(frameworks = "nice"),
  cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
)
# }
```
