# Adding a New Framework to cybedtools

## Scope of this vignette

Extending `cybedtools` with a framework beyond the current corpus (NICE,
DCWF, SFIA, ECSF, Cyber.org K-12, CSTA, CSEC2017, DigComp 3.0, CyQUAL,
CCSSF, OTCCF) follows a fixed sequence of steps. This vignette walks
through the steps using a hypothetical “Framework X” to make the pattern
concrete.

The steps:

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
  "nice", "dcwf", "ecf", "sfia", "ecsf", "cyqual", "ccssf", "otccf",
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
  staging_dir       = here::here("data", "raw", "frameworkx"),
  # ...
)

# Extraction functions producing tidy tibbles
extract_frameworkx <- function(source_path) {
  # your extraction logic here
  # placeholder: return one tidy tibble per output CSV
  tibble::tibble(element_id = character(), text = character())
}

# Provenance manifest writer (use existing frameworks as template)
write_provenance_manifest <- function(config) {
  # your manifest-writing logic here (SHA256, retrieval date, licensing)
  invisible(NULL)  # placeholder
}

# Main wraps it
main <- function(config = frameworkx_config) {
  source_path <- file.path(config$staging_dir, config$filename)
  tables_dir  <- file.path(config$staging_dir, "tables")

  data <- extract_frameworkx(source_path)
  readr::write_csv(data, file.path(tables_dir, "elements.csv"))
  write_provenance_manifest(config)
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

### Can a unit id equal a statement id?

Answer this before you go further, because getting it wrong is silent. A
node’s IRI is the framework prefix plus the node’s local id, so if
Framework X can give an organizing unit and a statement the same id,
both get the same IRI and the two nodes merge into one. Every count
still adds up. What you get instead is a unit that is its own element
and a `cybed:hasElement` edge that points at itself.

Check it directly. Intersect the set of unit ids with the set of
statement ids in your staged tables. If the intersection is empty, and
the two id spaces are structurally incapable of overlapping, there is
nothing to do. If it is not empty, declare a discriminator for the unit
side:

``` yaml
frameworkx:
  unit_iri_prefix: "unit-"
```

The assembler passes it to
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md)
or
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md),
which mint `frameworkx:unit-<id>` and keep the framework’s printed code
as a `schema:identifier` literal. Statement IRIs are untouched, because
those are the codes a reader looks up. Two frameworks in this package
declare one: DCWF numbers work roles and task/KSA statements from a
single range, and Cyber.org K-12 names a grade-band cell after the
standard inside it.

You do not have to catch this by inspection.
`scripts/026-verify-graph.R` fails the build on any fused IRI and names
the framework. But it fails after assembly, and it is cheaper to answer
the question while you are writing the ingester.

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
  CSEC2017, and DigComp 3.0 do this.

Both paths assert `cybed:OrganizingUnit` so cross-framework queries
reach every framework in the corpus via the abstract type. Only
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
  list(
    framework = framework_node,
    roles = role_nodes,
    elements = element_nodes,
    prefix = "fx"
  )
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
[namespace-architecture](https://ryanstraight.github.io/cybedtools/articles/namespace-architecture.html)
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
Rscript scripts/025-export-ntriples.R

# Check the assembled graph: no fused IRIs, declared counts in band
Rscript scripts/026-verify-graph.R

# Query (existing queries will now return rows for Framework X)
Rscript scripts/040-run-sparql.R
```

Existing SPARQL queries automatically include the new framework because
they match on `cybed:Framework`, `cybed:OrganizingUnit`, and
`cybed:RoleElement`, the framework-agnostic types. Queries that
explicitly target `cybed:Role` (workforce-only) include the new
framework only if its parents assert `cybed:Role` (i.e.,
`build_role_node` was used). No query rewrites required.

## What if one unit relates to another?

Some frameworks say that one organizing unit stands in a relation to
another. The OTCCF is the case that prompted the vocabulary: CSA
publishes which technical skills each job role requires, and at what
proficiency level. Two helpers cover this, and you usually want both.

[`build_related_unit_metadata()`](https://ryanstraight.github.io/cybedtools/reference/build_related_unit_metadata.md)
produces the plain edge, a `cybed:relatedUnit` key you fold into the
`metadata` argument of
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md)
or
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md).
It answers “what is this unit connected to” in one hop. Call it **once
per source unit**, passing every target that unit has in a single call.
Two calls merged with [`c()`](https://rdrr.io/r/base/c.html) give the
node two `cybed:relatedUnit` keys, which is not valid JSON-LD. Targets
in more than one framework go in the same call, with `to_prefix`
supplied per target.

``` r

rel_meta <- build_related_unit_metadata(
  to_unit_ids = c("network-security", "incident-response"),
  to_prefix   = "fx"
)

build_role_node(
  role_id             = "ot-security-engineer",
  role_name           = "OT Security Engineer",
  framework_prefix    = "fx",
  framework_role_type = "JobRole",
  framework_id        = "frameworkx-v1",
  metadata            = rel_meta
)
```

[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/reference/build_unit_relation_node.md)
produces the qualified statement, a `cybed:UnitRelation` node carrying
`cybed:fromUnit`, `cybed:toUnit`, `cybed:relationLabel`, and
`cybed:proficiencyLevel`. Use it when the publisher says more than
“these two are related”. Levels are stored as character, exactly as
printed. Do not convert them to numbers and do not normalize them across
frameworks. One framework’s 4 and another’s Intermediate are not on the
same scale, and a shared numeric type would assert a comparability the
sources do not.

``` r

rel <- build_unit_relation_node(
  from_unit_id      = "ot-security-engineer",
  to_unit_id        = "network-security",
  from_prefix       = "fx",
  relation_label    = "requires",
  proficiency_level = "4",
  framework_id      = "frameworkx-v1"
)
```

Collect the relation nodes and return them from your assembler in the
optional `relation_nodes` slot of
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md).
Frameworks with no unit-to-unit statements leave it out, and the
document is unchanged.

``` r

assemble_framework_document(
  framework_node   = fx_framework,
  role_nodes       = fx_units,
  element_nodes    = fx_elements,
  framework_prefix = "fx",
  relation_nodes   = fx_relations
)
```

## What if the steward asks to be credited, or the text is not in English?

[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md)
takes two optional arguments for this. `attribution` writes
`schema:creditText` and holds the steward’s wording verbatim. If a
permission letter gives you a sentence to use, put that sentence here
without rewording it. `in_language` writes `schema:inLanguage` and takes
a BCP 47 tag. Set it when the framework’s text is not English, so a
reader of the graph is not left to guess.

``` r

build_framework_node(
  framework_id     = "frameworkx-v1",
  framework_name   = "Framework X",
  framework_prefix = "fx",
  version          = "1.0",
  publisher        = "Example Authority",
  jurisdiction     = "CZ",
  sector           = "public",
  specificity      = "cybersecurity-specific",
  attribution      = "Framework X, published by the Example Authority. Used with permission.",
  in_language      = "cs"
)
```

## What if the steward limits what may be republished?

Permission to build a graph is not always permission to publish the
framework’s text. Record what the steward actually granted in the
framework’s block in `docs/framework-invariants.yml`, under
`public_redistribution`. Two values are in use. `full_with_attribution`
means the statement text may be published as long as the attribution
travels with it, which is where CyQUAL and CCSSF sit. `structure_only`
means titles, categories, levels, and mappings may be published and the
statement text may not, which is where OTCCF sits. Put the reasoning in
a comment beside the value, including the date of the written
permission, so the next reader does not have to reconstruct it.

Treat the value as binding on anything the package makes public, which
includes the Concordance site and any data deposit. Analysis on a local
graph is unaffected. If a steward’s terms do not fit either value, add a
new one and say so in the comment rather than rounding down to the
nearest existing label.

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
