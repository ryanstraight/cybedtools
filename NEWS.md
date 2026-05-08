# cybedtools 0.1.1

* **Hidden granularity fix.** A 2026-05-08 audit of all eight frameworks found
  that several encode pedagogical or specification detail in prose
  ("Clarification statement:" segments, "such as" example lists, semicolon-
  delimited enumerations) inside `cybed:elementText` literals rather than as
  discrete numbered standards. The naive element count under-represented the
  actual content density of those frameworks.

  v0.1.1 adds a uniform sub-point parser (`parse_subpoints()`) that runs
  against every framework's elementText literals at JSON-LD assembly time
  and promotes each parsed sub-point to a first-class child element node.
  Frameworks where the parser finds no sub-points (NICE, DCWF, DigComp 2.2)
  are unchanged. Affected frameworks gain sub-point children:

      Framework               | v0.1.0 | v0.1.1 | Inflation
      NICE v2                 |  2,111 |  2,115 |  1.00x
      DCWF v5.1               |  2,945 |  2,945 |  1.00x
      ECSF v1                 |    374 |    390 |  1.04x
      SFIA 9                  |    672 |    830 |  1.24x
      Cyber.org K-12 v1.0     |    123 |    500 |  4.07x
      CSTA K-12 CS (Rev 2017) |    120 |    140 |  1.17x
      ACM/IEEE CSEC2017       |     38 |     40 |  1.05x
      DigComp 2.2             |     21 |     21 |  1.00x

  Cross-framework per-organizing-unit density recomputes from ~50x in v0.1.0
  to ~12x in v0.1.1. The framing also shifts: the eight frameworks specify
  at incommensurable units of analysis (work role, skill level, competence,
  standard, Knowledge Area, competence area) and reflect different design
  philosophies. The cybedtools comparison layer makes them queryable in one
  graph but does not erase those structural distinctions. Density figures
  are comparison aids, not quality claims.

* **Parser robustness.** The first iteration of `parse_subpoints()` over-
  extracted on multi-sentence elementText (notably SFIA's responsibility
  prose) by greedily consuming past sentence boundaries. Two refinements
  landed: a sentence-boundary stop (period + whitespace + uppercase) and a
  pure-connective filter (drops "and"/"or"/"the" artifacts from source-
  truncated lists). Re-spot-check brought SFIA from ~30% false-positive
  rate to 0/10 sampled, and CSEC2017 from ~33% to 0/2. All eight frameworks
  run with the parser enabled at release.

* **New JSON-LD vocabulary.** Two terms added to the `cybed:` ontology:
  `cybed:Subpoint` (a `cybed:RoleElement` subtype tagging parsed sub-points)
  and `cybed:elaborates` (a predicate linking a sub-point to its parent
  standard). Sub-points retain framework-native subtypes for polymorphic
  queries: a Cyber.org K-12 sub-point is typed as `cyberorg:Standard`,
  `cybed:Subpoint`, and `cybed:RoleElement` simultaneously.

* **New exported helpers in `R/jsonld-helpers.R`:**
  - `parse_subpoints()` heuristic regex parser
  - `build_subpoint_node()` JSON-LD constructor for sub-points
  - `expand_with_subpoints()` orchestrator that walks parent elements and
    emits sub-point children with deterministic IRIs (`parent.sub.N`)
  - `extend_role_element_ids()` helper for role-builder integration

* **Per-framework opt-out.** The environment variable
  `CYBED_DISABLE_SUBPOINT_PARSER` (comma-separated framework slugs) disables
  sub-point parsing for the listed frameworks. Useful if a framework steward
  prefers numbered-only counts.

* **Pipeline scripts now load the package directly.** The 020-assemble-jsonld
  script previously sourced helpers from a hand-mirrored file path. v0.1.1
  uses `pkgload::load_all()` (when running from a working tree) or
  `library(cybedtools)` (when running from an installed package).

* **Tests.** 52 new unit and semantic tests across parser determinism,
  sub-point IRI stability, type polymorphism, `cybed:elaborates` traversal,
  cluster-to-leaf reachability, and JSON-LD round-trip. 111 tests pass on
  release, no skips.

* **Known limitations carrying into v0.1.2.**

  - **The `cybed:Role` abstraction is structurally coerced** for frameworks
    that do not enumerate roles (SFIA enumerates skills; CSTA, Cyber.org
    K-12, CSEC2017, and DigComp 2.2 enumerate organizing units that are
    not roles). The "roles" column in `framework_summary` is "the
    framework's top-level organizing unit, whatever the framework calls
    it" rather than a count of roles in the workforce sense. v0.1.2 is
    slated to redesign or split this abstraction. See
    `docs/framework-data-sources.md` for the per-framework structural
    mapping.
  - **The `cybed:Subpoint` type is overstated** for Cyber.org K-12 and
    CSTA "Clarification statement:" examples. These are formally teacher-
    facing scaffolding describing the level-of-rigor expectation for the
    standard, not enumerable sub-standards. The current schema types
    them as if they were sub-standards, which is queryable but slightly
    overstates what the framework expects. v0.1.2 will introduce a
    distinct `cybed:Example` type and exclude these promoted nodes from
    default `cybed:hasElement` collections.

# cybedtools 0.1.0

* Initial public release. Eight cybersecurity workforce and learning frameworks
  (NICE, DCWF, ECSF, SFIA, Cyber.org K-12, CSTA, ACM/IEEE CSEC2017, DigComp 2.2)
  ingested into a shared two-tier JSON-LD schema and queryable via single-BGP
  SPARQL with R-side joins.
