# cybedtools licensing notes

This document complements
[`LICENSE.md`](https://ryanstraight.github.io/cybedtools/LICENSE.md)
(which contains the canonical MIT license for the package code). It
addresses how licensing applies across the package’s three layers: code,
framework source text, and analytical outputs.

## TL;DR

If you are using cybedtools for academic research:

- Install the package, run analyses, cite it in your papers, you’re
  fine.
- Code (R helpers, SPARQL templates, scripts) is MIT-licensed. Reuse
  freely.
- Framework source text is each framework’s own license. The package
  does not redistribute it. You stage source files yourself per
  [`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md).
- Derivative analytical outputs (counts, comparisons, mappings) are
  publishable with attribution to the source frameworks, subject to the
  upstream license.

If you are integrating cybedtools into a commercial product:

- The MIT license on the code accommodates this.
- Framework content is mixed. Some frameworks (NICE, DCWF) are public
  domain. Others (SFIA, Cyber.org K-12, CSTA, ACM/IEEE) impose
  non-commercial or attribution constraints. Read the per-framework
  licenses in
  [`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md)
  before redistributing framework text. **It is incumbent upon you to
  obtain proper licensing**.

## Scope of the MIT license

The MIT license in `LICENSE.md` applies to the **code** in this
repository: R scripts, SPARQL queries, schema definitions, and
supporting infrastructure.

This license does NOT extend to:

- **Framework source text** that users stage under `data/raw/`. Each
  framework carries its own licensing, recorded in
  `data/raw/<framework>/provenance.yml` by the ingestion scripts.
  Notably: SFIA content is under the SFIA Foundation Use Policy (free
  use varies by user category; redistribution of full skill text
  restricted regardless); Cyber.org K-12 standards are CC BY-NC 4.0
  (non-commercial); CSTA standards are CC BY-NC-SA 4.0; ENISA ECSF is
  published under ENISA’s re-use notice (typically equivalent to CC BY
  4.0; verify against the specific artifact); CSEC2017 is
  ACM/IEEE/AIS/IFIP copyright with educational-use permission; DigComp
  is JRC EU open re-use; NICE and DCWF are US Government works in the
  public domain.
- **Framework analyses** produced by running this pipeline on framework
  source text. Derivative analytical outputs (code frequencies,
  cross-framework mappings) are generally safe to publish with
  attribution, but specific licensing turns on the source framework.

When redistributing or building on this toolkit, respect the upstream
framework licenses in addition to the MIT license on the code.
