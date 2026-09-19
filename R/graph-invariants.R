# graph-invariants.R
#
# Checks that only an assembled graph can answer.
#
# scripts/015-verify-ingestion.R runs over the staged CSVs, before anything
# is minted, so it can say nothing about IRIs. The checks here run over the
# graph the assembler produced and cover two things the CSVs cannot show:
#
#   Identity. No IRI may be both an organizing unit and a statement, and no
#   cybed:hasElement triple may point at its own subject. Both are symptoms
#   of the same defect: a framework whose unit ids and statement ids come out
#   of one id space mints one IRI for two different things, and the two nodes
#   fuse. The fusion is lossless for counts, which is why it survived from
#   v0.1.0 to v0.3.1 without a count ever looking wrong, and it is a
#   modelling error all the same: a unit becomes its own element, and a query
#   that walks cybed:hasElement walks in a circle.
#
#   Counts. The graph_invariants block of docs/framework-invariants.yml
#   declares what the assembled graph should hold, per framework and in
#   total. Those numbers are the outputs of the pipeline, not its inputs, so
#   the ingestion verifier cannot enforce them either.
#
# Both are hard failures. A build that mints a fused IRI, or that drifts off
# a declared count, stops before the release export can ship it.

# ---------------------------------------------------------------------------
# Graph reads
# ---------------------------------------------------------------------------

#' Subjects carrying a given prefixed type, as a character vector
#' @noRd
typed_subjects <- function(rdf, type_name) {
  unique(sparql_subjects(rdf, "a", type_name)$s)
}

#' Map every subject to the framework it declares with `cybed:partOf`
#'
#' Returns a named character vector: names are subject IRIs, values are the
#' framework's local name (e.g. `"dcwf-v5.1"`). A subject with no
#' `cybed:partOf` maps to `NA`.
#' @noRd
framework_of_index <- function(rdf) {
  pairs <- sparql_pairs(rdf, "cybed:partOf")
  index <- character(0)
  if (nrow(pairs) == 0) {
    return(index)
  }
  pairs <- pairs[!duplicated(pairs$s), , drop = FALSE]
  index <- sub("^.*framework/", "", pairs$o)
  names(index) <- pairs$s
  index
}

#' First `n` elements of a vector, without reaching for utils
#' @noRd
first_n <- function(x, n) x[seq_len(min(as.integer(n), length(x)))]

#' Name every element of a character vector with the same bullet
#' @noRd
bulleted <- function(x, bullet = "x") {
  names(x) <- rep(bullet, length(x))
  x
}

#' @noRd
framework_of <- function(index, iris) {
  out <- unname(index[iris])
  out[is.na(out)] <- "(no framework)"
  out
}

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

#' Find organizing units that are also statements, and self-referential links
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Two graph-level identity checks, both run over an assembled graph:
#'
#' 1. No IRI may be typed both `cybed:OrganizingUnit` and `cybed:RoleElement`.
#'    An IRI that is both is one node standing for two different things, a
#'    unit and a statement, because the framework numbers them out of one id
#'    space.
#' 2. No `cybed:hasElement` triple may have the same subject and object. A
#'    unit that is its own element is the same defect seen from the edge
#'    rather than from the node.
#'
#' The report is data. [assert_graph_identity()] is the gate.
#'
#' @param rdf An rdf object from [rdflib::rdf_parse()] or
#'   [load_combined_ntriples_graph()].
#' @return A tibble with one row per violation and three columns: `check`
#'   (`"unit_element_collision"` or `"has_element_self_loop"`), `iri`, and
#'   `framework` (the local name of the framework the IRI declares with
#'   `cybed:partOf`, or `"(no framework)"`). Zero rows when the graph is
#'   clean.
#' @family Graph invariants
#' @export
#' @examples
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' graph_identity_violations(rdf)
#' }
graph_identity_violations <- function(rdf) {
  units    <- typed_subjects(rdf, "cybed:OrganizingUnit")
  elements <- typed_subjects(rdf, "cybed:RoleElement")
  collisions <- sort(intersect(units, elements))

  links <- sparql_pairs(rdf, "cybed:hasElement")
  self_loops <- if (nrow(links) == 0) {
    character(0)
  } else {
    sort(unique(links$s[links$s == links$o]))
  }

  index <- framework_of_index(rdf)

  tibble::tibble(
    check = c(rep("unit_element_collision", length(collisions)),
              rep("has_element_self_loop", length(self_loops))),
    iri = c(collisions, self_loops),
    framework = c(framework_of(index, collisions),
                  framework_of(index, self_loops))
  )
}

#' Stop the build when an assembled graph fuses a unit with a statement
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Calls [graph_identity_violations()] and raises a classed condition when it
#' returns any row. The message names each affected framework, how many IRIs
#' it contributes, and the first few of them, so the offending framework is
#' identifiable without re-querying the graph.
#'
#' The remedy is to declare a `unit_iri_prefix` for that framework in
#' `docs/framework-invariants.yml` and let the assembler mint its unit IRIs
#' with it. See [build_organizing_unit_node()].
#'
#' @param rdf An rdf object.
#' @param examples Integer, how many offending IRIs to name per framework.
#' @return Invisibly `TRUE` when the graph is clean.
#' @family Graph invariants
#' @export
#' @examples
#' \dontrun{
#' assert_graph_identity(load_combined_ntriples_graph())
#' }
assert_graph_identity <- function(rdf, examples = 3L) {
  violations <- graph_identity_violations(rdf)
  if (nrow(violations) == 0) {
    return(invisible(TRUE))
  }

  detail <- character(0)
  for (check_name in unique(violations$check)) {
    rows <- violations[violations$check == check_name, , drop = FALSE]
    headline <- switch(
      check_name,
      unit_element_collision =
        "IRI(s) typed both cybed:OrganizingUnit and cybed:RoleElement",
      has_element_self_loop =
        "cybed:hasElement triple(s) whose subject and object are the same IRI",
      check_name
    )
    detail <- c(detail, bulleted(paste0(nrow(rows), " ", headline, ".")))
    for (fw in unique(rows$framework)) {
      named <- rows$iri[rows$framework == fw]
      shown <- first_n(named, examples)
      detail <- c(detail, bulleted(
        paste0(fw, ": ", length(named), ", first ", length(shown), " ",
               paste(shown, collapse = ", "), ".")
      ))
    }
  }

  rlang::abort(
    c(
      "The assembled graph mints one IRI for an organizing unit and a statement.",
      detail,
      "i" = paste0(
        "A framework whose unit ids and statement ids share one id space needs ",
        "a unit_iri_prefix declared for it in docs/framework-invariants.yml."
      )
    ),
    class = "cybedtools_graph_identity",
    violations = violations
  )
}

# ---------------------------------------------------------------------------
# Declared counts
# ---------------------------------------------------------------------------

#' Measure the counts that `graph_invariants` declares
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Computes, from an assembled graph, every quantity the `graph_invariants`
#' block of `docs/framework-invariants.yml` declares a band for: the combined
#' totals, and the per-framework element split into parents, sub-points and
#' examples. The strict-inflation ratio is derived here rather than declared,
#' so the file and the graph cannot disagree about how it is computed.
#'
#' @param rdf An rdf object.
#' @return A tibble with columns `scope` (`"combined"` or a framework's local
#'   name), `measure` and `value`.
#' @family Graph invariants
#' @export
#' @examples
#' \dontrun{
#' graph_invariant_counts(load_combined_ntriples_graph())
#' }
graph_invariant_counts <- function(rdf) {
  units     <- typed_subjects(rdf, "cybed:OrganizingUnit")
  roles     <- typed_subjects(rdf, "cybed:Role")
  elements  <- typed_subjects(rdf, "cybed:RoleElement")
  subpoints <- typed_subjects(rdf, "cybed:Subpoint")
  examples  <- typed_subjects(rdf, "cybed:Example")
  relations <- typed_subjects(rdf, "cybed:UnitRelation")
  frameworks <- typed_subjects(rdf, "cybed:Framework")

  parents <- setdiff(elements, union(subpoints, examples))
  index <- framework_of_index(rdf)

  combined <- tibble::tibble(
    scope = "combined",
    measure = c("organizing_unit_count", "role_count",
                "total_elements_with_subpoints", "total_elements_full",
                "example_count", "unit_relation_count", "framework_count"),
    value = c(length(units), length(roles),
              length(setdiff(elements, examples)), length(elements),
              length(examples), length(relations), length(frameworks))
  )

  per_framework_counts <- function(iris) {
    table(framework_of(index, iris))
  }
  parent_tab   <- per_framework_counts(parents)
  subpoint_tab <- per_framework_counts(subpoints)
  example_tab  <- per_framework_counts(examples)

  scopes <- sort(unique(c(names(parent_tab), names(subpoint_tab),
                          names(example_tab))))
  lookup <- function(tab, scope) {
    if (scope %in% names(tab)) as.integer(tab[[scope]]) else 0L
  }

  per_framework <- lapply(scopes, function(scope) {
    parent_n   <- lookup(parent_tab, scope)
    subpoint_n <- lookup(subpoint_tab, scope)
    example_n  <- lookup(example_tab, scope)
    strict     <- parent_n + subpoint_n
    tibble::tibble(
      scope = scope,
      measure = c("parent_elements", "subpoint_elements", "example_elements",
                  "total_elements_with_subpoints", "total_elements_full",
                  "strict_inflation"),
      value = c(parent_n, subpoint_n, example_n, strict,
                strict + example_n,
                if (parent_n > 0) strict / parent_n else NA_real_)
    )
  })

  dplyr::bind_rows(c(list(combined), per_framework))
}

#' Read the `graph_invariants` block of the framework invariants file
#'
#' @param invariants_path Character path to `docs/framework-invariants.yml`.
#'   Defaults to the copy in the source checkout.
#' @return The `graph_invariants` list.
#' @noRd
read_graph_invariants <- function(invariants_path = NULL) {
  if (is.null(invariants_path)) {
    invariants_path <- here::here("docs", "framework-invariants.yml")
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    rlang::abort(
      c(
        "Reading the framework invariants file needs the yaml package.",
        "i" = "Install it with install.packages(\"yaml\")."
      ),
      class = "cybedtools_missing_suggest"
    )
  }
  if (!file.exists(invariants_path)) {
    rlang::abort(
      c(
        "The framework invariants file was not found.",
        "x" = paste0("Expected at: ", invariants_path, "."),
        "i" = wrong_directory_hint()
      ),
      class = "cybedtools_file_not_found"
    )
  }
  declared <- yaml::read_yaml(invariants_path)$graph_invariants
  if (is.null(declared)) {
    rlang::abort(
      c(
        "The framework invariants file declares no graph_invariants block.",
        "x" = paste0("File: ", invariants_path, ".")
      ),
      class = "cybedtools_graph_invariant"
    )
  }
  declared
}

#' Check an assembled graph against the declared `graph_invariants` bands
#'
#' @description
#' `r lifecycle::badge("stable")`
#'
#' Compares [graph_invariant_counts()] against the bands declared in the
#' `graph_invariants` block of `docs/framework-invariants.yml`. Each band is a
#' pair of inclusive bounds; a pair with two equal bounds is an exact value.
#' A measured quantity outside its band raises a classed condition naming
#' every disagreement.
#'
#' Bands are the file's claim about the pipeline's output. A value that leaves
#' its band is a human-review event: something upstream moved, and the right
#' response is to find out what before editing the number.
#'
#' @param rdf An rdf object.
#' @param invariants_path Character path to the invariants file. Defaults to
#'   `docs/framework-invariants.yml` in the source checkout.
#' @param declared Optional pre-read `graph_invariants` list, used in place of
#'   reading the file. Mainly for tests.
#' @return Invisibly, the tibble of measured counts.
#' @family Graph invariants
#' @export
#' @examples
#' \dontrun{
#' assert_graph_invariants(load_combined_ntriples_graph())
#' }
assert_graph_invariants <- function(rdf,
                                    invariants_path = NULL,
                                    declared = NULL) {
  if (is.null(declared)) {
    declared <- read_graph_invariants(invariants_path)
  }
  measured <- graph_invariant_counts(rdf)

  bands <- list()
  add_band <- function(bands, scope, block) {
    for (measure in names(block)) {
      band <- block[[measure]]
      if (!is.numeric(unlist(band)) || length(unlist(band)) != 2L) {
        next
      }
      bands[[length(bands) + 1L]] <- list(
        scope = scope, measure = measure,
        lower = unlist(band)[[1L]], upper = unlist(band)[[2L]]
      )
    }
    bands
  }

  if (!is.null(declared$combined)) {
    bands <- add_band(bands, "combined", declared$combined)
  }
  per_framework_declared <- declared$per_framework
  if (is.null(per_framework_declared)) per_framework_declared <- list()
  for (scope in names(per_framework_declared)) {
    bands <- add_band(bands, scope, per_framework_declared[[scope]])
  }

  failures <- character(0)
  checked <- 0L
  for (band in bands) {
    row <- measured[measured$scope == band$scope &
                      measured$measure == band$measure, , drop = FALSE]
    if (nrow(row) != 1L) {
      failures <- c(failures, paste0(
        band$scope, " / ", band$measure,
        ": declared, but the graph carries no such measurement."
      ))
      next
    }
    checked <- checked + 1L
    value <- row$value[[1L]]
    if (is.na(value) || value < band$lower || value > band$upper) {
      failures <- c(failures, paste0(
        band$scope, " / ", band$measure, ": measured ", format(value),
        ", declared [", band$lower, ", ", band$upper, "]."
      ))
    }
  }

  if (length(failures)) {
    rlang::abort(
      c(
        "The assembled graph is outside a declared graph invariant.",
        bulleted(failures),
        "i" = paste0(
          "Find out what moved upstream before editing the declared band. ",
          "The band is the claim; the graph is the evidence."
        )
      ),
      class = "cybedtools_graph_invariant",
      failures = failures
    )
  }

  message(sprintf("  %d declared graph invariant(s) checked, all within band",
                  checked))
  invisible(measured)
}
