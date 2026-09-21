# Load a graph from the cached release files, fetching first if needed

**\[experimental\]**

Ensures the requested frameworks are cached (calling
[`cybed_fetch()`](https://ryanstraight.github.io/cybedtools/reference/cybed_fetch.md)
internally, which is a no-op for files already cached with a verified
hash) and parses them into one shared rdf object.

## Usage

``` r
load_graph(frameworks = NULL, version = NULL)
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

An rdf object
([`rdflib::rdf()`](https://docs.ropensci.org/rdflib/reference/rdf.html))
with every requested framework's triples loaded.

## See also

Other data loading:
[`cybed_fetch()`](https://ryanstraight.github.io/cybedtools/reference/cybed_fetch.md)

## Examples

``` r
# \donttest{
tryCatch(
  {
    rdf <- load_graph(frameworks = "nice-v2")
    framework_metadata(rdf)
  },
  cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
)
#> Warning: downloaded length 0 != reported length 9
#> Warning: cannot open URL 'https://github.com/ryanstraight/cybedtools/releases/download/data-vlatest/manifest.json': HTTP status was '404 Not Found'
#> No network: Could not download a release file.
#> ✖ URL: https://github.com/ryanstraight/cybedtools/releases/download/data-vlatest/manifest.json.
#> ℹ Set `options(cybedtools.release_url = ...)` or the CYBEDTOOLS_RELEASE_URL environment variable to point at a reachable release (a `file://` URL works for local testing).
# }
```
