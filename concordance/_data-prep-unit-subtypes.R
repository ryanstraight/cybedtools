# Populates _data/unit_subtypes.rds: framework-specific structural
# sub-breakdowns that framework_summary does not carry (it counts
# cybed:OrganizingUnit / cybed:Role / cybed:RoleElement only, not a
# framework's own internal subtypes). Each figure below is queried
# directly off the combined graph so no framework page hand-types a
# structural sub-count.
#
# Run from the cybedtools repo root (here::here() quirk -- see
# concordance/_data-prep.R and memory/r-environment-quirks.md).

suppressPackageStartupMessages({
  library(cybedtools)
  library(dplyr)
  library(here)
})

data_dir <- here("concordance", "_data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

graph_path <- here("data", "processed", "ntriples", "_combined.nt")
g <- load_combined_ntriples_graph(graph_path)

q <- function(sparql) rdflib::rdf_query(g, sparql)

n_of_type <- function(type_iri) {
  nrow(q(sprintf("SELECT ?s WHERE { ?s a <%s> }", type_iri)))
}

n_distinct_source_section <- function(type_iri) {
  res <- q(sprintf(
    "SELECT ?s ?sec WHERE { ?s a <%s> . ?s <https://w3id.org/cybed/ontology#sourceSection> ?sec }",
    type_iri
  ))
  if (nrow(res) == 0) return(character(0))
  sort(unique(res$sec))
}

# DigComp 3.0: Competence Areas and Competences, the two organizing-unit
# tiers beneath the framework (organizing_unit_count = both combined).
digcomp <- list(
  competence_area_count = n_of_type("https://ec.europa.eu/jrc/digcomp/terms#CompetenceArea"),
  competence_count      = n_of_type("https://ec.europa.eu/jrc/digcomp/terms#Competence")
)

# SCyWF 1.5: Category and Specialty Area, the two organizing-unit tiers
# above Job Role (organizing_unit_count = categories + specialty areas +
# job roles).
scywf <- list(
  category_count       = n_of_type("https://w3id.org/cybed/framework/scywf#Category"),
  specialty_area_count = n_of_type("https://w3id.org/cybed/framework/scywf#SpecialtyArea")
)

# CCSSF 2022: core roles (Annexes A-D, typed ccssf:WorkRole) versus
# cyber-adjacent roles (Annex E, typed ccssf:AdjacentRole). Both are
# cybed:Role and both count toward framework_summary's role_count.
# Activity-area count comes off the distinct cybed:sourceSection labels
# carried by the core (WorkRole) roles only -- adjacent roles carry the
# same field but are not organized into the four activity areas the way
# core roles are.
ccssf <- list(
  core_role_count     = n_of_type("https://w3id.org/cybed/framework/ccssf#WorkRole"),
  adjacent_role_count = n_of_type("https://w3id.org/cybed/framework/ccssf#AdjacentRole"),
  activity_area_count = length(n_distinct_source_section(
    "https://w3id.org/cybed/framework/ccssf#WorkRole"
  ))
)

# OTCCF v1.1: the 30 Technical Skills and Competencies (second root,
# alongside job roles), how many of those are SkillsFuture-derived
# (cybed:sourceCategory tag), and how many career-map tracks the 15 job
# roles sit under (distinct cybed:sourceSection labels on JobRole nodes).
otccf_tsc_total <- n_of_type("https://w3id.org/cybed/framework/otccf#TechnicalSkillCompetency")
otccf_tsc_sf <- nrow(q(paste0(
  "SELECT ?s WHERE { ",
  "?s a <https://w3id.org/cybed/framework/otccf#TechnicalSkillCompetency> . ",
  "?s <https://w3id.org/cybed/ontology#sourceCategory> \"SkillsFuture ICT Framework\" }"
)))
otccf <- list(
  tsc_count             = otccf_tsc_total,
  tsc_skillsfuture_count = otccf_tsc_sf,
  track_count           = length(n_distinct_source_section(
    "https://w3id.org/cybed/framework/otccf#JobRole"
  ))
)

# SFIA 9: distinct proficiency levels in use across the ingested skill x
# level elements, read off the "SFIA <code> Level <n>" cybed:sourceSection
# literal rather than assumed from the published seven-level scale, so a
# level absent from the ingested set (as observed: Level 1 currently has
# no bound elements) is not silently asserted as present.
sfia_sections <- n_distinct_source_section("https://sfia-online.org/en/terms#Skill")
if (length(sfia_sections) == 0) {
  # Skill nodes may not carry sourceSection themselves; pull levels from
  # any sfia-namespaced subject's sourceSection instead (per-level
  # elements do carry it -- see scripts/020-assemble-jsonld.R).
  res <- q(paste0(
    "SELECT ?s ?sec WHERE { ?s <https://w3id.org/cybed/ontology#sourceSection> ?sec . ",
    "FILTER(CONTAINS(STR(?sec), \"SFIA\")) }"
  ))
  sfia_sections <- if (nrow(res) == 0) character(0) else sort(unique(res$sec))
}
sfia_levels <- sort(unique(as.integer(gsub(".*Level ", "", sfia_sections))))
sfia <- list(
  level_count = length(sfia_levels),
  levels      = sfia_levels
)

# Cross-corpus count DCWF's own page compares itself against: "the other
# N frameworks" means the full corpus less DCWF itself.
n_other_frameworks <- nrow(cybedtools::framework_summary) - 1L

unit_subtypes <- list(
  digcomp             = digcomp,
  scywf               = scywf,
  ccssf               = ccssf,
  otccf               = otccf,
  sfia                = sfia,
  n_other_frameworks  = n_other_frameworks
)

saveRDS(unit_subtypes, file.path(data_dir, "unit_subtypes.rds"))

cat("unit_subtypes.rds written:\n")
str(unit_subtypes)
