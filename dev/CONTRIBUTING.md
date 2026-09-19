# Contributing to cybedtools

Contributions are welcome. This document describes the expected
workflow.

## Reporting issues

Open a GitHub issue with:

- Framework and version involved (if relevant).
- Reproduction steps: which script was run, with what command, and what
  output appeared.
- Your R session info
  ([`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html)).
- If verification failed: the full output of
  `Rscript scripts/015-verify-ingestion.R`.

## Adding a new framework

See the vignette `adding-a-framework.Rmd` for the complete six-step
process. Summary:

1.  Pick a slug and framework prefix.
2.  Stage the source file at `data/raw/<slug>/` and write
    `scripts/010-ingest-<slug>.R`.
3.  Declare invariants in `docs/framework-invariants.yml`.
4.  Add verification field mappings in `scripts/015-verify-ingestion.R`.
5.  Add a JSON-LD assembly adapter in `scripts/020-assemble-jsonld.R`.
6.  Verify, assemble, run queries.

Include a `provenance.yml` manifest and (if applicable) notes on
extraction limitations.

## Code style

- Native R pipes (`|>`) and tidyverse idioms where reasonable.
- [`here::here()`](https://here.r-lib.org/reference/here.html) for
  paths. No hardcoded paths.
- `suppressPackageStartupMessages({ library(...) })` at the top of
  scripts.
- Function names descriptive, not abbreviated. No `p` or `k` for
  variables.
- Spelling: package prose (vignettes, NEWS, roxygen comments) uses
  American English (`Language: en-US` in DESCRIPTION). Framework names
  that originate with their publishers (e.g., “European Commission Joint
  Research Centre”) retain the publisher’s spelling. Run
  `devtools::spell_check()` before opening a PR. Add new domain
  vocabulary to `inst/WORDLIST` rather than rewording.
- Every ingestion script writes a `provenance.yml` with SHA256,
  retrieval date, and licensing.

## Tests

New functions need unit tests under `tests/testthat/`. Run tests with:

``` r

devtools::test()
# or
testthat::test_local()
```

## Documentation

- Every exported function needs roxygen docs with `@param`, `@return`,
  `@export`.
- Regenerate `NAMESPACE` and `man/` with `devtools::document()`.
- Update `NEWS.md` for user-facing changes.

## Framework licensing

New frameworks must document their upstream license in
`data/raw/<slug>/provenance.yml`. If the source license prohibits
redistribution, the ingestion script should require user-supplied source
files rather than auto-download. See SFIA and DCWF ingestion scripts for
the manual-stage pattern.

## Pull requests

Pull requests should:

- Target `main`.
- Pass `R CMD check` locally (CI runs this on macOS, Windows, and
  Ubuntu).
- Include tests for new functionality.
- Update `NEWS.md` if user-facing.
- Update the relevant vignette if adding new functions or workflows.

## Questions

Open an issue.
