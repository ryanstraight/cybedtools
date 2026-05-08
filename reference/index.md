# Package index

## JSON-LD construction

Build JSON-LD documents that express a framework in the two-tier cybed
schema.

- [`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/reference/build_jsonld_context.md)
  **\[stable\]** :

  Build a standard JSON-LD `@context` block

- [`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md)
  **\[stable\]** :

  Build a JSON-LD `@context` block covering multiple frameworks

- [`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md)
  **\[stable\]** :

  Construct a `cybed:Framework` top-level node

- [`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md)
  **\[stable\]** :

  Construct a `cybed:OrganizingUnit` node

- [`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)
  **\[stable\]** :

  Construct a `cybed:Role` node (workforce frameworks)

- [`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md)
  **\[stable\]** :

  Construct a `cybed:RoleElement` node

- [`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md)
  **\[stable\]** :

  Assemble a framework-level `@graph` document

## Sub-point and example parsing

Lift prose-encoded enumerations and pedagogical-scaffolding content out
of parent element text and promote each fragment to a first-class graph
element. Framework-as-specified enumerations (“such as” lists,
“including” patterns) become cybed:Subpoint instances with
cybed:elaborates back-pointers. “Clarification statement:” pedagogical
scaffolding becomes cybed:Example instances reachable only via the
parent’s cybed:hasExample predicate. See vignette
cross-framework-analysis for the encoding-strategy finding this enables.

- [`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
  **\[stable\]** : Parse subpoints out of a parent element's text

- [`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md)
  **\[stable\]** :

  Construct a `cybed:Subpoint` node

- [`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md)
  **\[stable\]** :

  Construct a `cybed:Example` node

- [`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)
  **\[stable\]** : Expand parent element nodes with sub-point and
  example child nodes

- [`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md)
  **\[stable\]** : Append Subpoint IDs to a role's child-element id list

## File I/O

- [`read_jsonld_document()`](https://ryanstraight.github.io/cybedtools/reference/read_jsonld_document.md)
  **\[stable\]** : Read a JSON-LD document from file
- [`write_jsonld_document()`](https://ryanstraight.github.io/cybedtools/reference/write_jsonld_document.md)
  **\[stable\]** : Write a JSON-LD document to file

## RDF graph loading

Load assembled JSON-LD or N-Triples into rdflib for SPARQL querying.

- [`load_single_framework_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_single_framework_graph.md)
  **\[stable\]** : Load a single framework's JSON-LD into a new rdflib
  graph
- [`load_unified_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_unified_rdf_graph.md)
  **\[experimental\]** : Load every framework's JSON-LD into a unified
  rdflib graph
- [`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md)
  **\[stable\]** : Load the pre-assembled combined multi-framework
  JSON-LD into an rdflib graph
- [`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md)
  **\[stable\]** : Load the pre-combined N-Triples file into an rdflib
  graph
- [`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
  **\[stable\]** : Build a small in-memory demo RDF graph

## SPARQL helpers

Single-BGP query primitives and domain-level helpers. The package’s
query discipline is one triple-pattern match per SPARQL call, with joins
and aggregation done in R via dplyr; see vignette
cross-framework-analysis for worked examples.

- [`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md)
  **\[stable\]** : Run a single-BGP SPARQL select returning
  subject-object pairs
- [`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)
  **\[stable\]** : Run a single-BGP SPARQL select with fixed predicate
  and object
- [`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md)
  **\[stable\]** : Domain helper: tibble of framework metadata
- [`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
  **\[stable\]** : Domain helper: organizing-unit-to-framework bindings
  with framework name attached
- [`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md)
  **\[stable\]** : Domain helper: role-to-framework bindings with
  framework name attached
- [`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md)
  **\[stable\]** : Domain helper: element-to-framework bindings with
  framework name attached
- [`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
  **\[stable\]** : Domain helper: example-to-framework bindings with
  framework name attached
- [`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md)
  **\[stable\]** : Domain helper: role-to-element bindings

## Validation

- [`validate_jsonld_node()`](https://ryanstraight.github.io/cybedtools/reference/validate_jsonld_node.md)
  **\[stable\]** : Validate a JSON-LD node's minimum required structure

## Datasets

Pre-computed summary tibbles shipped with the package.

- [`framework_summary`](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)
  : Eight-framework summary tibble
