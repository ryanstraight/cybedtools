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
    rdf <- load_graph(frameworks = "nice")
    framework_metadata(rdf)
  },
  cybedtools_download_failed = function(cnd) message("No network: ", conditionMessage(cnd))
)
#> # A tibble: 1 × 6
#>   framework                 name  jurisdiction sector specificity framework_slug
#>   <chr>                     <chr> <chr>        <chr>  <chr>       <chr>         
#> 1 https://w3id.org/cybed/o… NICE… US           civil… cybersecur… nice-v2       
# }
```
