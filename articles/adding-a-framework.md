# Adding a New Framework to cybedtools

## Scope of this vignette

Extending `cybedtools` with a framework beyond the current eight (NICE,
DCWF, SFIA, ECSF, Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2) is a
six-step process. This vignette walks through the steps using a
hypothetical “Framework X” to make the pattern concrete.

The six steps:

1.  Pick a slug and framework prefix.
2.  Stage the source file and write an ingestion script.
3.  Declare invariants.
4.  Add verification field mappings.
5.  Add a JSON-LD assembly adapter.
6.  Verify, assemble, and query.

## Step 1: slug and prefix

Every framework has two identifiers:

- **Slug** (`frameworkx`): used in filesystem paths (`data/raw/<slug>/`,
  `data/processed/jsonld/<slug>.jsonld`) and script names.
- **Prefix** (`fx:`): used in JSON-LD `@context` and SPARQL queries.

Add the prefix to the `cybed_namespaces` list and the
`valid_framework_prefixes` vector in `R/jsonld-helpers.R`:

``` r

# R/jsonld-helpers.R
cybed_namespaces <- list(
  # ... existing prefixes ...
  fx        = "https://frameworkx.example.org/ontology#"
)

valid_framework_prefixes <- c(
  "nice", "dcwf", "ecf", "sfia", "ecsf",
  "cyberorg", "csta", "csec", "digcomp",
  "fx"   # new
)
```

## Step 2: ingestion script

Create `scripts/010-ingest-frameworkx.R`. The script should:

- Stage the source file under `data/raw/frameworkx/`.
- Extract tidy CSVs to `data/raw/frameworkx/tables/`.
- Write a `data/raw/frameworkx/provenance.yml` with SHA256, retrieval
  date, licensing.

Follow the pattern of existing ingestion scripts. The minimum viable
structure:

``` r

# Config block with version, filename, staging_dir, license
frameworkx_config <- list(
  framework_version = "Framework X v1.0",
  version_date      = "2026-01-01",
  publisher         = "Framework X Authority",
  filename          = "frameworkx-source.json",
  staging_dir       = here("data", "raw", "frameworkx"),
  # ...
)

# Extraction functions producing tidy tibbles
extract_frameworkx <- function(source_path) { ... }

# Provenance manifest writer (use existing frameworks as template)
write_provenance_manifest <- function(...) { ... }

# Main wraps it
main <- function() {
  data <- extract_frameworkx(source_path)
  write_csv(data, file.path(tables_dir, "elements.csv"))
  write_provenance_manifest(...)
}
```

## Step 3: declare invariants

Add an entry to `docs/framework-invariants.yml`:

``` yaml
frameworkx:
  version: "Framework X v1.0"
  version_date: "2026-01-01"
  structural_type: "role-first"   # or skill-first, learning-standards, etc.
  jurisdiction: "US"              # or EU, UK, global
  sector: "civilian"              # or defense, K-12-education, etc.
  specificity: "cybersecurity-specific"
  expected:
    roles_count: [10, 12]         # bounds justified in a comment
    elements_count: [95, 105]
  notes: |
    Justification for the tolerance bands, any known quirks, licensing
    reminders.
```

## Step 4: verification field mappings

In `scripts/015-verify-ingestion.R`, add two branches, one for count
extraction and one for text-integrity checks:

``` r
# In framework_actual_counts():
frameworkx = {
  els <- safe_read(file.path(tables_dir, "elements.csv"))
  roles <- safe_read(file.path(tables_dir, "roles.csv"))
  list(
    roles_count    = nrow_or_null(roles),
    elements_count = nrow_or_null(els)
  )
},

# In text_fields_by_framework():
frameworkx = list(
  list(label = "element-text", file = "elements.csv", column = "text")
),

# In verify_id_uniqueness()'s id_specs:
frameworkx = list(
  list(file = "elements.csv", id_col = "element_id", label = "fx-element-id")
),
```

## Step 5: JSON-LD assembly adapter

In `scripts/020-assemble-jsonld.R`, add an assembler function and
register it. The assembler chooses one of two parent-unit constructors
depending on whether the framework is workforce-shaped:

- Use
  [`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
  (which delegates to `build_organizing_unit_node(is_role = TRUE)`) when
  the framework’s parent units are work roles or work profiles. NICE,
  DCWF, and ENISA ECSF do this.
- Use `build_organizing_unit_node(is_role = FALSE)` when the parent
  units are something else (skills, learning standards clusters,
  knowledge areas, competence areas). SFIA, Cyber.org K-12, CSTA,
  CSEC2017, and DigComp 2.2 do this.

Both paths assert `cybed:OrganizingUnit` so cross-framework queries
reach all eight frameworks via the abstract type. Only
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
additionally asserts `cybed:Role`, restricting workforce-only queries
appropriately.

The example below assumes Framework X is workforce-shaped:

``` r

assemble_frameworkx <- function() {
  # Read the manifest and tidy CSVs your ingestion script wrote.
  prov  <- load_framework_provenance("frameworkx")
  roles <- read_framework_table("frameworkx", "roles")
  elements <- read_framework_table("frameworkx", "elements")

  # Build the framework-level JSON-LD node. Subclasses cybed:Framework via
  # the fx: prefix; downstream SPARQL queries match on cybed:Framework
  # and so include this framework automatically.
  framework_node <- build_framework_node(
    framework_id     = "frameworkx-v1",
    framework_name   = prov$framework_version,
    framework_prefix = "fx",
    version          = prov$framework_version,
    publisher        = prov$source$publisher,
    jurisdiction     = "US",
    sector           = "civilian",
    specificity      = "cybersecurity-specific",
    license          = prov$licensing$source_license,
    date_published   = prov$framework_date
  )

  # One JSON-LD node per work role. build_role_node asserts fx:WorkRole +
  # cybed:Role + cybed:OrganizingUnit on each.
  role_nodes <- roles |>
    purrr::pmap(function(role_id, role_name, ...) {
      build_role_node(
        role_id              = role_id,
        role_name            = role_name,
        framework_prefix     = "fx",
        framework_role_type  = "WorkRole",
        framework_id         = "frameworkx-v1"
      )
    })

  # One JSON-LD node per atomic element. Each subclasses cybed:RoleElement
  # so cross-framework SPARQL queries pick them up alongside NICE tasks,
  # SFIA skill levels, CSEC2017 essentials, and the rest.
  element_nodes <- elements |>
    purrr::pmap(function(element_id, text, ...) {
      build_role_element_node(
        element_id             = element_id,
        framework_prefix       = "fx",
        framework_element_type = "Element",
        element_text           = text,
        framework_id           = "frameworkx-v1"
      )
    })

  # The orchestrator collects framework + role + element nodes and the
  # prefix; it then assembles the per-framework JSON-LD document and
  # merges it into the combined graph.
  list(framework = framework_node, roles = role_nodes, elements = element_nodes,
       prefix = "fx")
}

# Register the assembler so the orchestrator can find it.
framework_assemblers[["frameworkx"]] <- assemble_frameworkx
framework_to_prefix[["frameworkx"]]  <- "fx"
```

If Framework X is non-workforce (it enumerates skills, learning
standards clusters, or competence areas rather than roles), replace the
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
call with:

``` r

build_organizing_unit_node(
  unit_id           = unit_id,
  unit_name         = unit_name,
  framework_prefix  = "fx",
  framework_subtype = "Skill",   # or "StandardGroup", "KnowledgeArea", etc.
  is_role           = FALSE,
  framework_id      = "frameworkx-v1"
)
```

Pick a `framework_subtype` that names what the unit IS in the
framework’s own terminology rather than coercing it under “WorkRole.”
See the
[namespace-architecture](https://ryanstraight.github.io/cybedtools/articles/namespace-architecture.md)
article for the existing per-framework subtype table; new frameworks
should follow the same pattern.

And in `assembly_config$frameworks`, add `"frameworkx"` so the loop
picks it up.

## Step 6: run the pipeline

``` bash
# Ingest
Rscript scripts/010-ingest-frameworkx.R

# Verify
Rscript scripts/015-verify-ingestion.R

# Assemble
Rscript scripts/020-assemble-jsonld.R

# Query (existing queries will now return rows for Framework X)
Rscript scripts/040-run-sparql.R
```

Existing SPARQL queries automatically include the new framework because
they match on `cybed:Framework`, `cybed:OrganizingUnit`, and
`cybed:RoleElement`, the framework-agnostic types. Queries that
explicitly target `cybed:Role` (workforce-only) include the new
framework only if its parents assert `cybed:Role` (i.e.,
`build_role_node` was used). No query rewrites required.

## What if the source is a PDF?

For PDF-only source frameworks (CSEC2017 and DigComp follow this
pattern):

1.  Convert via markitdown or pdfplumber to an intermediate text file
    under `data/raw/<slug>/extracted-text.md`.
2.  In the ingestion script, parse the intermediate text with regex or
    line-scanning against the known framework structure.
3.  Document the extraction approach and its limitations in the `notes`
    field of `provenance.yml`.

PDF extraction is usually best-effort. Mark the extraction scope
honestly in the provenance so downstream users know what’s structurally
complete vs approximate.

## What if the source has license restrictions?

1.  Record the exact license terms in the ingestion script’s config and
    in `provenance.yml`.
2.  Check whether redistribution in `data/raw/` is permissible. If not,
    require manual staging (like SFIA and DCWF do, where the user
    downloads the source themselves).
3.  Ensure `.Rbuildignore` excludes `data/raw/` from the R package build
    if framework text cannot be redistributed. This is already
    configured.

The package’s layered licensing (code = MIT, framework data = upstream)
handles mixed restrictions cleanly.
