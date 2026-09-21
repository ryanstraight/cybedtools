# Shipped framework_licenses tibble and the cybed_license() accessor.
#
# framework_licenses is the package's single owner of licence facts. A wrong
# licence statement in a public package is worse than none, so these tests
# pin the shape, the controlled vocabulary, the agreement with
# docs/framework-invariants.yml, the derivation of framework_summary$license,
# and the one row whose wording was decided deliberately (CCSSF).

test_that("framework_licenses has one row per framework plus exactly one code row", {
  expect_s3_class(framework_licenses, "tbl_df")
  expect_named(
    framework_licenses,
    c("layer", "slug", "framework_name", "license_short", "license",
      "attribution", "public_redistribution", "terms_url", "granted",
      "verified")
  )
  expect_equal(sum(framework_licenses$layer == "code"), 1L)
  expect_true(all(framework_licenses$layer %in% c("code", "framework")))

  expect_setequal(
    framework_licenses$slug[framework_licenses$layer == "framework"],
    framework_summary$framework_slug
  )
  expect_equal(
    nrow(framework_licenses),
    nrow(framework_summary) + 1L
  )
})

test_that("slugs are unique and the code row is the package itself", {
  expect_equal(anyDuplicated(framework_licenses$slug), 0L)
  code_row <- framework_licenses[framework_licenses$layer == "code", ]
  expect_equal(code_row$slug, "cybedtools")
  expect_equal(code_row$license_short, "MIT")
})

test_that("public_redistribution uses the declared vocabulary", {
  expect_true(all(
    framework_licenses$public_redistribution %in%
      c("unrestricted", "full_with_attribution", "structure_only",
        "local_only")
  ))
})

test_that("public_redistribution agrees with docs/framework-invariants.yml", {
  # Hard-coded from docs/framework-invariants.yml, which is the declaring
  # document. A framework carrying no `public_redistribution` key there means
  # "unrestricted"; only twelve frameworks declare one. The test suite does not
  # otherwise read that YAML, so the map is pinned here rather than parsed.
  # If the YAML changes, this map changes with it.
  expected <- c(
    "nice-v2"           = "unrestricted",
    "dcwf-v5.1"         = "unrestricted",
    "ecsf-v1"           = "full_with_attribution",
    "sfia-9"            = "local_only",
    "cyberorg-k12-v1.0" = "full_with_attribution",
    "csta-2017"         = "full_with_attribution",
    "csta-2026"         = "full_with_attribution",
    "csec2017-v1"       = "structure_only",
    "digcomp-3.0"       = "full_with_attribution",
    "cyqual-v1.2.0"     = "full_with_attribution",
    "ccssf-2022"        = "structure_only",
    "otccf-v1.1"        = "structure_only",
    "scywf-1.5"         = "full_with_attribution",
    "cybok-v1.1.0"      = "full_with_attribution"
  )

  fw <- framework_licenses[framework_licenses$layer == "framework", ]
  expect_setequal(fw$slug, names(expected))
  expect_equal(
    fw$public_redistribution[match(names(expected), fw$slug)],
    unname(expected)
  )
})

test_that("license_short is a short non-empty label everywhere", {
  expect_true(all(nzchar(framework_licenses$license_short)))
  expect_true(all(!is.na(framework_licenses$license_short)))
  expect_true(all(nchar(framework_licenses$license_short) < 40L))
})

test_that("every terms_url is https", {
  expect_true(all(grepl("^https://", framework_licenses$terms_url)))
})

test_that("only attribution may be NA, and granted is logical", {
  other_cols <- setdiff(names(framework_licenses), "attribution")
  expect_false(any(is.na(framework_licenses[other_cols])))
  expect_type(framework_licenses$granted, "logical")
  expect_s3_class(framework_licenses$verified, "Date")
})

test_that("granted is TRUE only where a steward gave written permission", {
  expect_setequal(
    framework_licenses$slug[framework_licenses$granted],
    c("cyqual-v1.2.0", "otccf-v1.1", "scywf-1.5")
  )
})

test_that("framework_summary's license column is the join of license_short", {
  fw <- framework_licenses[framework_licenses$layer == "framework", ]
  expect_equal(
    framework_summary$license,
    fw$license_short[match(framework_summary$framework_slug, fw$slug)]
  )
})

test_that("the CCSSF row never claims permission", {
  # Decided 2026-09-19: the steward said only that the material is
  # copyrighted under the Government of Canada and should be referenced when
  # used. Public text must not characterise that as permission until the
  # steward confirms.
  ccssf <- framework_licenses[framework_licenses$slug == "ccssf-2022", ]
  expect_equal(nrow(ccssf), 1L)
  expect_false(ccssf$granted)
  expect_false(
    any(grepl("permission", unlist(ccssf), ignore.case = TRUE))
  )
  expect_equal(ccssf$license_short, "Government of Canada copyright")
  expect_equal(ccssf$public_redistribution, "structure_only")
})

test_that("the OTCCF row carries CSA's prescribed attribution verbatim", {
  otccf <- cybed_license("otccf-v1.1")
  expect_equal(
    otccf$attribution,
    paste0(
      "Derived from the Operational Technology Cybersecurity Competency ",
      "Framework (OTCCF), published by the Cyber Security Agency of ",
      "Singapore (CSA). Available at: ",
      "https://www.csa.gov.sg/resources/publications/",
      "operational-technology-cybersecurity-competency-framework--otccf-/"
    )
  )
})

test_that("cybed_license returns the whole tibble, one row, or a classed error", {
  expect_identical(cybed_license(), framework_licenses)
  expect_identical(cybed_license(NULL), framework_licenses)

  one <- cybed_license("nice-v2")
  expect_s3_class(one, "tbl_df")
  expect_equal(nrow(one), 1L)
  expect_equal(one$slug, "nice-v2")

  expect_equal(nrow(cybed_license("cybedtools")), 1L)

  expect_error(
    cybed_license("not-a-framework"),
    class = "cybedtools_framework_not_found"
  )
  expect_error(
    cybed_license(c("nice-v2", "sfia-9")),
    class = "cybedtools_scalar_input"
  )
})

test_that("the csta-2026 row cites the document's licence page and DOI", {
  row <- cybed_license("csta-2026")
  expect_equal(row$license_short, "CC BY-NC-SA 4.0")
  expect_equal(row$public_redistribution, "full_with_attribution")
  expect_false(row$granted)
  expect_match(row$license, "p. iv", fixed = TRUE)
  expect_match(row$attribution, "Computer Science Teachers Association", fixed = TRUE)
  expect_match(row$attribution, "10.1145/3820482", fixed = TRUE)
})

test_that("the scywf row names NCA, links the official page and records the grant", {
  row <- cybed_license("scywf-1.5")
  expect_equal(row$public_redistribution, "full_with_attribution")
  expect_true(row$granted)
  expect_equal(row$terms_url, "https://nca.gov.sa/en/pages/scywf.html")
  expect_match(row$attribution, "National Cybersecurity Authority (NCA)", fixed = TRUE)
  expect_match(row$attribution, "https://nca.gov.sa/en/pages/scywf.html", fixed = TRUE)
  expect_match(row$attribution, "SCyWF – 1.5: 2026", fixed = TRUE)
  expect_match(row$license, "verbatim", fixed = TRUE)
  expect_match(row$license, "derived", fixed = TRUE)
})

test_that("the cybok row carries the OGL and CyBOK's prescribed attribution", {
  row <- cybed_license("cybok-v1.1.0")
  expect_equal(row$public_redistribution, "full_with_attribution")
  expect_false(row$granted)
  expect_equal(row$license_short, "OGL v3.0")
  expect_identical(
    row$attribution,
    "CyBOK © Crown Copyright, The National Cyber Security Centre 2021, licensed under the Open Government Licence: http://www.nationalarchives.gov.uk/doc/open-government-licence/."
  )
  expect_match(row$license, "Open Government Licence v3.0", fixed = TRUE)
  expect_match(row$terms_url, "nationalarchives.gov.uk/doc/open-government-licence", fixed = TRUE)
})
