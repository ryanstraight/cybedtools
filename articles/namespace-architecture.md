# JSON-LD namespace architecture

The core tension is that each framework uses its own vocabulary (work
roles, tasks, competences, skills, levels, learning standards) while
comparative analysis needs a framework-agnostic layer that lets SPARQL
queries operate uniformly across them.

## Design choices

The architecture uses a two-tier namespace structure: a base vocabulary
that is cross-framework, and framework-specific vocabularies that
subclass the base. Each tier has a distinct prefix.

The base vocabulary subsumes the conceptual common ground of all
in-scope frameworks: framework, role, role element (task, knowledge
statement, skill statement, competence, learning standard), element
text, source reference, and structural metadata (jurisdiction, sector,
specificity). Per-framework vocabularies specialize these via
subclassing, so a single SPARQL query targeting `cybed:RoleElement`
returns elements across NICE, DCWF, e-CF, SFIA, and the pedagogical
frameworks in one pass.

Schema.org (`schema:`) and SKOS (`skos:`) provide the outermost
vocabulary layer for generic properties such as name, description,
prefLabel, and altLabel.

The project namespace URI is `https://w3id.org/cybed/ontology#` (prefix
`cybed`). w3id.org provides stable, redirectable URIs for vocabularies
via a community-maintained GitHub repository, which means the URI
persists across changes to the maintainer’s personal infrastructure.
Resolving the URI follows the redirect maintained at the `cybed` entry
in the w3id.org configuration repo.

## Why a custom URI rather than reusing existing ontologies

The natural semantic-web question is: why mint `cybed:` rather than
reuse an existing competency or skills ontology? Three constraints made
reuse insufficient.

**Coverage.** Existing competency ontologies (ESCO, O\*NET, CEDEFOP
qualifications taxonomies) cover labor-market competencies in general
terms but do not represent the structural commitments of the specific
frameworks this package handles. NICE work roles, SFIA skill levels, and
ENISA ECSF role profiles each carry framework-specific structural
metadata (TKS classifications, responsibility levels, cross-framework
references) that an ESCO-based mapping would either lose or distort.

**Pedagogical-frameworks gap.** ESCO and the workforce-competency
ontologies do not represent K-12 or higher-education curricular
frameworks (Cyber.org K-12 standards, CSTA standards, CSEC2017
guidelines, DigComp). The package’s design commitment is to make
workforce frameworks and pedagogical frameworks queryable through the
same schema. That requires a base vocabulary that subsumes both, which
existing competency ontologies do not.

**Comparison-layer purpose.** The `cybed:` schema is designed
specifically for cross-framework comparison: a single SPARQL query
targeting `cybed:RoleElement` returns elements across every framework in
one pass, regardless of whether that element is a NICE TaskStatement, an
SFIA SkillLevel, or a CSEC2017 Essential. Existing ontologies are not
built to subsume this heterogeneity at the comparison layer.

Where existing vocabulary fits cleanly, the schema reuses it: Schema.org
(`schema:`) for generic properties (name, description, version,
publisher, datePublished, license) and SKOS (`skos:`) for prefLabel and
altLabel. Tier 1 `cybed:` types specialize these where framework
structure requires it. Tier 2 framework prefixes specialize `cybed:`
types where framework vocabulary requires it.

## The two-tier shape

A single Tier-1 type, `cybed:RoleElement`, is specialized by every
framework. One SPARQL query against it returns comparable bindings
across all eight frameworks at once.

``` mermaid
flowchart TD
  RE["cybed:RoleElement<br>Tier 1 base vocabulary"]
  RE --> NICE_T["nice:TaskStatement<br>nice:KnowledgeStatement<br>nice:SkillStatement"]
  RE --> DCWF["dcwf:KSA"]
  RE --> SFIA["sfia:SkillLevel"]
  RE --> ECSF["ecsf:Skill"]
  RE --> CYBORG["cyberorg:Standard"]
  RE --> CSTA["csta:Standard"]
  RE --> CSEC["csec:Essential"]
  RE --> DIGCOMP["digcomp:Competence"]

  classDef base fill:#0F172A,stroke:#38BDF8,color:#E0F2FE,stroke-width:2px
  classDef sub fill:#1E293B,stroke:#7DD3FC,color:#E0F2FE
  class RE base
  class NICE_T,DCWF,SFIA,ECSF,CYBORG,CSTA,CSEC,DIGCOMP sub
```

`cybed:Role` and `cybed:Framework` follow the same pattern.

### Tier 1: Base vocabulary (`cybed:`)

Framework-agnostic terms that every framework supported here has in some
form.

- `cybed:Framework`, top-level container for a specific framework.
- `cybed:Role`, named work role, role profile, skill, knowledge area, or
  grade-band concept cluster (the framework’s top-level organizing
  unit).
- `cybed:RoleElement`, a task, competence, skill, knowledge statement,
  learning standard, or similar atomic element attached to a role.
- `cybed:Subpoint`, subClassOf `cybed:RoleElement`. Tags graph nodes
  that were lifted from prose enumeration in a parent element’s text
  (e.g., a “such as” example list, a “Clarification statement:” segment)
  and promoted to first-class child elements at JSON-LD assembly time.
- `cybed:hasElement`, object property from Role to RoleElement.
  Cluster-level queries return all leaf elements (parents plus
  sub-points) directly via this predicate.
- `cybed:partOf`, links Role to Framework and Element to Framework.
- `cybed:elaborates`, object property from a `cybed:Subpoint` to its
  parent `cybed:RoleElement`. Use this predicate to recover the
  parent-standard-vs-sub-point distinction when both appear in the same
  `cybed:hasElement` collection. Top-level standards are queryable as
  elements where `cybed:elaborates` is unbound.
- `cybed:elementText`, literal text of the element.
- `cybed:sourceSection`, where this element appears in the source
  document.
- `cybed:jurisdiction`, e.g., “US”, “EU”, “UK”, “global”.
- `cybed:sector`, e.g., “civilian”, “defense”, “general”,
  “K-12-education”, “higher-education”, “citizen-education”.
- `cybed:specificity`, e.g., “general-IT”, “cybersecurity-specific”,
  “general-computing”, “general-digital-competence”.

### Tier 2: Framework-specific vocabularies

Each framework gets its own prefix and defines subclasses of Tier 1
terms.

- `nice:`, WorkRole subclasses cybed:Role. TaskStatement,
  KnowledgeStatement, SkillStatement subclass cybed:RoleElement.
- `dcwf:`, inherits from nice: where aligned. Adds SpecialtyArea for
  DoD-specific groupings.
- `ecf:`, Competence subclasses cybed:RoleElement.
  EuropeanQualificationLevel attached.
- `sfia:`, Skill, SkillLevel, ResponsibilityLevel.
- `ecsf:`, RoleProfile, CybersecurityTaskCategory.
- `cyberorg:`, GradeBandConcept, Standard.
- `csta:`, Standard, Cluster, Concept.
- `csec:`, KnowledgeArea, Essential.
- `digcomp:`, CompetenceArea, Competence.

## Example JSON-LD document (sketch)

``` json
{
  "@context": {
    "schema": "http://schema.org/",
    "skos": "http://www.w3.org/2004/02/skos/core#",
    "cybed": "https://w3id.org/cybed/ontology#",
    "nice": "https://nice.nist.gov/framework/terms#"
  },
  "@graph": [
    {
      "@id": "nice:OG-WRL-015",
      "@type": ["nice:WorkRole", "cybed:Role"],
      "schema:name": "Technology Portfolio Management",
      "cybed:jurisdiction": "US",
      "cybed:sector": "civilian",
      "cybed:specificity": "cybersecurity-specific",
      "cybed:hasElement": [
        { "@id": "nice:OG-WRL-015-T01" }
      ]
    },
    {
      "@id": "nice:OG-WRL-015-T01",
      "@type": ["nice:TaskStatement", "cybed:RoleElement"],
      "cybed:elementText": "Evaluate the strategic alignment of emerging technologies..."
    }
  ]
}
```
