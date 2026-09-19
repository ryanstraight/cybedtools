# Data integrity protocol

**Why this exists.** Every empirical claim derived from this pipeline
must be traceable to source through verifiable, mechanically-checked
invariants. This protocol is the contract between the ingestion layer
and any downstream analysis.

**Scope.** Applies to every framework staged under
`data/raw/<framework>/` and every derivative under `data/processed/`.
Verification runs before any analysis touches the data.

## Invariants

### 1. Source provenance

Every framework must have a `provenance.yml` recording:

- Framework name and version.
- Source publisher, type, and retrieval URL (or manual acquisition
  note).
- SHA256 of the canonical source artifact (XLSX, JSON, SQLite, PDF).
- File size in bytes.
- Retrieval date (ISO-8601) and retriever identity (script path).
- Licensing terms and redistribution constraints.

**Check:** `provenance.yml` exists, parses as YAML, contains the
required keys, and the recorded SHA256 matches the file on disk.

### 2. Extraction invariants

Every framework must declare its expected entity counts in
`docs/framework-invariants.yml`. Actual extraction counts must fall
within a tolerance band.

**Example:**

``` yaml
nice:
  version: "v2"
  expected:
    work_roles: [41, 41]
    unique_tks: [2109, 2113]
sfia:
  version: "SFIA 9"
  expected:
    skills: [145, 149]
    skill_levels: [670, 675]
```

**Check:** Every ingested framework has expected counts declared. Actual
counts fall inside the declared ranges. Tolerance bands are justified in
inline comments.

**Rule:** If actual counts fall outside expected ranges, the ingestion
is flagged as a potential source revision rather than silently accepted.
Human review updates the expected bounds.

### 3. Referential integrity

Every within-framework identifier reference must resolve.

**Examples:**

- DCWF per-role sheets reference Task and KSA IDs that must exist in the
  master catalog.
- ECSF e-competence references must match a known e-CF code pattern.
- SFIA SkillLevel rows reference Skill codes that must exist in the
  Skill table (enforced by foreign keys in SQLite, but verified
  post-extraction).
- NICE role-TKS associations reference both `work_role_id` (must exist
  in `work-roles.csv`) and `statement_id` (must exist in `tasks.csv`,
  `knowledge.csv`, or `skills.csv`).

**Check:** For each declared cross-reference, unresolved references are
enumerated and reported. Zero unresolved is the pass criterion.

**Current implementation status:** Full referential-integrity automation
is in progress. Partial coverage exists via foreign-key constraints in
the source format (SFIA SQLite). Remaining gaps are caught implicitly by
extraction-count bounds (which catch structural drift) and by the SPARQL
queries (which silently drop unresolved references, so a graph with
broken refs shows visible element-count shortfalls in query results). A
full explicit check is on the roadmap.

### 4. Text integrity

Statement text must pass:

- **UTF-8 validity.** No replacement characters (U+FFFD), no unexpected
  encoding artifacts.
- **Non-empty.** Empty strings in element-text columns are errors, not
  data.
- **Length sanity.** Statements under approximately 10 characters or
  over approximately 5,000 characters are flagged for manual review
  (likely extraction errors or merged cells).
- **No truncation at suspicious round numbers.** If every statement
  happens to be exactly 255 characters, that indicates a silent column
  truncation upstream.

**Check:** All flagged conditions produce error output. Nothing is
silently accepted.

### 5. ID uniqueness and namespacing

- Within a framework, every element and role ID is unique.
- Across frameworks, element IDs must be namespaced by framework prefix
  (e.g., `nice:OG-WRL-015-T01`, not bare `T01`). The JSON-LD assembly
  enforces this. The verification rig confirms it.

**Check:** No duplicate IDs within a framework. All IDs in assembled
graphs carry a framework prefix.

### 6. Round-trip reproducibility

Re-running an ingestion script against the same source file must produce
byte-identical tidy CSVs. This means:

- No timestamps or other environment-varying data embedded in output
  files.
- Deterministic row ordering (sort by a stable key before write).
- Fixed locale for number and date formatting.

**Check:** Run ingestion twice and `diff` the outputs. Zero delta is the
pass criterion. (Exception: `provenance.yml` retrieval_date differs and
is excluded from the diff.)

### 7. Audit trail

Every ingestion or verification run writes an entry to
`data/audit/audit-log.ndjson`:

- Timestamp (ISO-8601 with timezone).
- Script path and (when under version control) git commit hash.
- SHA256 of each output file.
- Pass/fail for each invariant.

**Check:** The audit log is append-only. Gaps or rewrites are themselves
errors.

## Enforcement

### When verification runs

- **After every ingestion script.** Each `scripts/010-ingest-*.R` exits
  with non-zero status if verification fails.
- **As a pre-analysis gate.** `scripts/020+` scripts refuse to run if
  the audit log shows any recent failure.
- **As a pre-distribution gate.** Any output artifact built from the
  pipeline cannot be released if verification is failing.

### What fails verification

**Hard failures** (block all downstream work):

- Missing or invalid `provenance.yml`.
- SHA256 mismatch against source file.
- Unresolved within-framework references.
- Duplicate IDs.
- Invalid UTF-8 or empty required text fields.

**Soft flags** (warn but allow, with written justification):

- Extraction count outside expected range (indicates source revision,
  human review required before next run).
- Statements outside length sanity band (likely merged cells or
  truncation, human review).

### The “no silent fixes” rule

If verification fails, the response is never to quietly adjust the data
to pass. The response is:

1.  Investigate root cause.
2.  Update the protocol (if the invariant was wrong) or fix the
    source/extraction (if the data was wrong).
3.  Document the fix in the audit log with human sign-off.
4.  Re-run.
