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

  Character vector of framework slugs to fetch (as carried by
  [framework_summary](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)`$framework_slug`,
  e.g. `"nice-v2"`), or `NULL` (the default) for every framework the
  release manifest ships.

- version:

  Character scalar release version (e.g. `"1.0.0"`), or `NULL` (the
  default) for the release location's `"latest"` alias.

## Value

Invisibly, a tibble with one row per fetched framework: columns
`framework_slug`, `path` (the cached file's local path),
`sha256_verified` (logical, always `TRUE` on return – a mismatch aborts
instead of returning `FALSE`).

## See also

Other data loading:
[`load_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_graph.md)

## Examples

``` r
# \donttest{
# Requires network access (or a `cybedtools.release_url` override
# pointing at a local mock release for testing).
tryCatch(
  cybed_fetch(frameworks = "nice-v2"),
  cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
)
#> Warning: downloaded length 0 != reported length 9
#> Warning: cannot open URL 'https://github.com/ryanstraight/cybedtools/releases/download/data-vlatest/manifest.json': HTTP status was '404 Not Found'
#> No network: Could not download a release file.
#> ✖ URL: https://github.com/ryanstraight/cybedtools/releases/download/data-vlatest/manifest.json.
#> ℹ Set `options(cybedtools.release_url = ...)` or the CYBEDTOOLS_RELEASE_URL environment variable to point at a reachable release (a `file://` URL works for local testing).
# }
```
