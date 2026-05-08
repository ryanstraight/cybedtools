# Changelog

## cybedtools 0.2.0

### Breaking changes

This release introduces a structural redesign of the `cybed:` vocabulary
to address two defects v0.1.1 documented but did not fix: `cybed:Role`
was misapplied to non-workforce frameworks (SFIA enumerates skills, not
roles; CSTA, Cyber.org K-12, CSEC2017, and DigComp 2.2 enumerate other
organizing units), and `cybed:Subpoint` overstated what the source
frameworks specify when it promoted Cyber.org K-12 and CSTA
“Clarification statement:” pedagogical scaffolding to first-class
sub-standards. Both fixes require breaking changes to the data model.

#### New abstract type: `cybed:OrganizingUnit`

`cybed:OrganizingUnit` (`subClassOf skos:Concept`) is the
cross-framework abstract that every framework’s top-level enumerated
unit asserts. Cross-framework SPARQL queries should target this type
rather than `cybed:Role`. Adding a new framework in a future release
introduces a new per-framework subtype but does not change existing
cross-framework queries.

#### `cybed:Role` is now workforce-restricted

`cybed:Role` is retained as `subClassOf cybed:OrganizingUnit` but is
asserted only on the three workforce frameworks where the unit is
genuinely a work role or work profile: NICE work roles, DCWF work roles,
and ENISA ECSF profiles. SFIA skills, Cyber.org K-12 grade-band
concepts, CSTA level-concept buckets, CSEC2017 Knowledge Areas, and
DigComp competence areas no longer assert `cybed:Role`. Queries that
filter on `?x a cybed:Role` will return only workforce-framework parents
under v0.2.0; for the cross-framework cut, switch to
`cybed:OrganizingUnit`.

Migration snippet:

``` sparql
# v0.1.x cross-framework parent query (returned all 8 frameworks
# because all parents asserted cybed:Role):
SELECT ?p WHERE { ?p a cybed:Role }

# v0.2.0 equivalent (the same eight-framework cut, via the abstract):
SELECT ?p WHERE { ?p a cybed:OrganizingUnit }
```

``` r

# v0.1.x R helper (returned all 8 frameworks):
role_framework_bindings(rdf)

# v0.2.0 equivalent (cross-framework cut):
organizing_unit_framework_bindings(rdf)

# v0.2.0 workforce-only cut (returns NICE / DCWF / ECSF only):
role_framework_bindings(rdf)
```

#### New atomic type: `cybed:Example` (with `cybed:hasExample` predicate)

`cybed:Example` (`subClassOf cybed:RoleElement`) is a new sibling of
`cybed:Subpoint` for content lifted from “Clarification statement:”
pedagogical scaffolding (Cyber.org K-12 and CSTA convention). Examples
differ from Subpoints in three ways:

1.  Examples carry no framework-native subtype. A Cyber.org K-12 Example
    is typed `cybed:Example` and `cybed:RoleElement` only; it is not
    also typed `cyberorg:Standard`. Queries that filter on the
    per-framework subtype no longer pick up Examples by accident.
2.  Examples are reachable only via the parent element’s
    `cybed:hasExample` predicate. They are excluded from default
    `cybed:hasElement` traversals, so role-level “all elements” queries
    remain restricted to framework-as-specified content.
3.  Examples do not carry `cybed:elaborates` back-pointers. The parent
    owns the Example via `cybed:hasExample`; the Example does not carry
    the converse link.

Two source-data shapes route to `cybed:Example`. (1) Cyber.org K-12
stores Clarification statements inline in the standard text under a
“Clarification statement:” header; the v0.1.1 parser extracted these as
`cybed:Subpoint`, and v0.2.0 reroutes them to `cybed:Example`. (2) CSTA
K-12 CS stores its clarifications in a separate `clarification` column
rather than inline; v0.1.x did not extract this column at all, and
v0.2.0 reads it directly to emit one `cybed:Example` per non-empty
clarification (114 new graph nodes).

SFIA, NICE, ECSF, and CSEC2017 enumerations (from “such as”,
“including”, and semicolon-list patterns rather than Clarification
scaffolding) remain typed `cybed:Subpoint`.

Migration snippet:

``` sparql
# v0.1.x: a Cyber.org K-12 sub-point was typed as a sub-standard:
SELECT ?s WHERE { ?s a cyberorg:Standard }   # picked up Clarification fragments
SELECT ?s WHERE { ?s a cybed:Subpoint }      # picked up Clarification fragments

# v0.2.0: the same fragments are typed cybed:Example instead.
SELECT ?s WHERE { ?s a cybed:Example }       # all Cyber.org + CSTA Clarifications
```

#### Per-framework subtype renames

Two cluster-type names were renamed because v0.1.x’s `StandardCluster`
suffix did not match the framework’s own structural axes. Cyber.org K-12
and CSTA both organize their numbered standards by cells in
multi-dimensional axes (grade band x sub-concept for Cyber.org K-12;
level x concept for CSTA), but neither framework names the cell itself
in published documentation. cybedtools therefore uses the descriptive
`StandardGroup` label rather than coining a pedagogy term the source
frameworks did not originate:

| Framework      | v0.1.x type                | v0.2.0 type              |
|----------------|----------------------------|--------------------------|
| Cyber.org K-12 | `cyberorg:StandardCluster` | `cyberorg:StandardGroup` |
| CSTA K-12 CS   | `csta:StandardCluster`     | `csta:StandardGroup`     |

SFIA’s `sfia:Skill`, CSEC2017’s `csec:KnowledgeArea`, and DigComp’s
`digcomp:CompetenceArea` retain their existing names but no longer
subclass `cybed:Role`; they now subclass `cybed:OrganizingUnit`
directly. NICE / DCWF / ECSF parent subtypes are unchanged.

#### `framework_summary` column changes

The shipped `framework_summary` tibble has new column names that match
v0.2.0 semantics. Two element-count columns are surfaced so analyses can
choose the strict count (parents + Subpoints) or the inclusive count
(parents + Subpoints + Examples).

| v0.1.x column | v0.2.0 column |
|----|----|
| `role_count` | `organizing_unit_count` |
| `element_count` | `element_count_strict`, `element_count_with_examples`, `example_count` |
| `elements_per_role` | `elements_per_organizing_unit_strict`, `elements_per_organizing_unit_with_examples` |

The README headline density figure now uses
`elements_per_organizing_unit_strict`. The cross-framework-analysis
vignette shows both the strict and with-examples columns and discusses
the encoding heterogeneity that drives the difference.

#### New exported helpers

- [`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md)
  — generic constructor for any framework’s parent unit. Pass
  `is_role = TRUE` for workforce frameworks.
  [`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
  is retained as a thin wrapper.
- [`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md)
  — constructor for pedagogical-scaffolding nodes parallel to
  [`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md).
- [`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
  — cross-framework parent-to- framework bindings. Returns all eight
  frameworks’ parents.
- [`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
  — `cybed:Example` subset of
  [`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md).
  Returns only the Cyber.org K-12 and CSTA Clarification scaffolding.

#### Parser output schema

[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
returns a third column, `node_type`, with values `"Subpoint"`
(framework-as-specified enumeration) or `"Example"`
(Clarification-statement scaffolding). The same parser handles both
patterns; the routing happens via the `node_type` tag.

[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)
returns the result list with the index field renamed `subpoint_index` →
`subnode_index`, and the index columns renamed `subpoint_id` →
`subnode_id` plus the new `node_type` column.

[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md)
now filters to `node_type == "Subpoint"` when back-filling a role’s
`cybed:hasElement` collection. Examples are deliberately excluded from
this collection so role-level “all elements” queries remain restricted
to framework-as-specified content.

#### Resolved from v0.1.1’s “known limitations”

Both items the v0.1.1 NEWS flagged as known limitations carrying into
v0.1.2 are addressed in this release: the `cybed:Role` abstraction is no
longer applied to non-workforce frameworks, and the Cyber.org K-12 /
CSTA Clarification fragments no longer carry `cybed:Subpoint` typing or
framework-native subtypes. The version label moved from v0.1.2 to v0.2.0
because the changes are breaking and semver requires minor bumps for
breaking changes in the 0.x range.

## cybedtools 0.1.1

- **Hidden granularity fix.** A 2026-05-08 audit of all eight frameworks
  found that several encode pedagogical or specification detail in prose
  (“Clarification statement:” segments, “such as” example lists,
  semicolon- delimited enumerations) inside `cybed:elementText` literals
  rather than as discrete numbered standards. The naive element count
  under-represented the actual content density of those frameworks.

  v0.1.1 adds a uniform sub-point parser
  ([`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md))
  that runs against every framework’s elementText literals at JSON-LD
  assembly time and promotes each parsed sub-point to a first-class
  child element node. Frameworks where the parser finds no sub-points
  (NICE, DCWF, DigComp 2.2) are unchanged. Affected frameworks gain
  sub-point children:

  ``` R
  Framework               | v0.1.0 | v0.1.1 | Inflation
  NICE v2                 |  2,111 |  2,115 |  1.00x
  DCWF v5.1               |  2,945 |  2,945 |  1.00x
  ECSF v1                 |    374 |    390 |  1.04x
  SFIA 9                  |    672 |    830 |  1.24x
  Cyber.org K-12 v1.0     |    123 |    500 |  4.07x
  CSTA K-12 CS (Rev 2017) |    120 |    140 |  1.17x
  ACM/IEEE CSEC2017       |     38 |     40 |  1.05x
  DigComp 2.2             |     21 |     21 |  1.00x
  ```

  Cross-framework per-organizing-unit density recomputes from ~50x in
  v0.1.0 to ~12x in v0.1.1. The framing also shifts: the eight
  frameworks specify at incommensurable units of analysis (work role,
  skill level, competence, standard, Knowledge Area, competence area)
  and reflect different design philosophies. The cybedtools comparison
  layer makes them queryable in one graph but does not erase those
  structural distinctions. Density figures are comparison aids, not
  quality claims.

- **Parser robustness.** The first iteration of
  [`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
  over- extracted on multi-sentence elementText (notably SFIA’s
  responsibility prose) by greedily consuming past sentence boundaries.
  Two refinements landed: a sentence-boundary stop (period +
  whitespace + uppercase) and a pure-connective filter (drops
  “and”/“or”/“the” artifacts from source- truncated lists).
  Re-spot-check brought SFIA from ~30% false-positive rate to 0/10
  sampled, and CSEC2017 from ~33% to 0/2. All eight frameworks run with
  the parser enabled at release.

- **New JSON-LD vocabulary.** Two terms added to the `cybed:` ontology:
  `cybed:Subpoint` (a `cybed:RoleElement` subtype tagging parsed
  sub-points) and `cybed:elaborates` (a predicate linking a sub-point to
  its parent standard). Sub-points retain framework-native subtypes for
  polymorphic queries: a Cyber.org K-12 sub-point is typed as
  `cyberorg:Standard`, `cybed:Subpoint`, and `cybed:RoleElement`
  simultaneously.

- **New exported helpers in `R/jsonld-helpers.R`:**

  - [`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
    heuristic regex parser
  - [`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md)
    JSON-LD constructor for sub-points
  - [`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)
    orchestrator that walks parent elements and emits sub-point children
    with deterministic IRIs (`parent.sub.N`)
  - [`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md)
    helper for role-builder integration

- **Per-framework opt-out.** The environment variable
  `CYBED_DISABLE_SUBPOINT_PARSER` (comma-separated framework slugs)
  disables sub-point parsing for the listed frameworks. Useful if a
  framework steward prefers numbered-only counts.

- **Pipeline scripts now load the package directly.** The
  020-assemble-jsonld script previously sourced helpers from a
  hand-mirrored file path. v0.1.1 uses
  [`pkgload::load_all()`](https://pkgload.r-lib.org/reference/load_all.html)
  (when running from a working tree) or
  [`library(cybedtools)`](https://github.com/ryanstraight/cybedtools)
  (when running from an installed package).

- **Tests.** 52 new unit and semantic tests across parser determinism,
  sub-point IRI stability, type polymorphism, `cybed:elaborates`
  traversal, cluster-to-leaf reachability, and JSON-LD round-trip. 111
  tests pass on release, no skips.

- **Known limitations carrying into v0.1.2.**

  - **The `cybed:Role` abstraction is structurally coerced** for
    frameworks that do not enumerate roles (SFIA enumerates skills;
    CSTA, Cyber.org K-12, CSEC2017, and DigComp 2.2 enumerate organizing
    units that are not roles). The “roles” column in `framework_summary`
    is “the framework’s top-level organizing unit, whatever the
    framework calls it” rather than a count of roles in the workforce
    sense. v0.1.2 is slated to redesign or split this abstraction. See
    `docs/framework-data-sources.md` for the per-framework structural
    mapping.
  - **The `cybed:Subpoint` type is overstated** for Cyber.org K-12 and
    CSTA “Clarification statement:” examples. These are formally
    teacher- facing scaffolding describing the level-of-rigor
    expectation for the standard, not enumerable sub-standards. The
    current schema types them as if they were sub-standards, which is
    queryable but slightly overstates what the framework expects. v0.1.2
    will introduce a distinct `cybed:Example` type and exclude these
    promoted nodes from default `cybed:hasElement` collections.

## cybedtools 0.1.0

- Initial public release. Eight cybersecurity workforce and learning
  frameworks (NICE, DCWF, ECSF, SFIA, Cyber.org K-12, CSTA, ACM/IEEE
  CSEC2017, DigComp 2.2) ingested into a shared two-tier JSON-LD schema
  and queryable via single-BGP SPARQL with R-side joins.
