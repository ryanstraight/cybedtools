# Shipped framework_summary tibble.
#
# Pins the object's shape and, for the original eight frameworks, its
# pre-existing values. Those numbers are quoted in the README, the
# cross-framework-analysis vignette, and the Concordance manuscript, so a
# silent change to any of them is a regression rather than a refresh.

test_that("framework_summary has the expected shape", {
  expect_s3_class(framework_summary, "tbl_df")
  expect_equal(nrow(framework_summary), 14L)
  expect_named(
    framework_summary,
    c("framework_slug", "framework_name", "framework_type", "jurisdiction",
      "organizing_unit_count", "role_count", "element_count_strict",
      "subpoint_count", "example_count", "element_count_with_examples",
      "unit_relation_count", "elements_per_organizing_unit_strict",
      "elements_per_organizing_unit_with_examples", "elements_per_role_strict",
      "elements_per_role_with_examples", "license")
  )
})

test_that("framework slugs are unique and cover all fourteen frameworks", {
  expect_equal(anyDuplicated(framework_summary$framework_slug), 0L)
  expect_setequal(
    framework_summary$framework_slug,
    c("nice-v2", "dcwf-v5.1", "ecsf-v1", "sfia-9", "cyberorg-k12-v1.0",
      "csta-2017", "csec2017-v1", "digcomp-3.0", "cyqual-v1.2.0",
      "ccssf-2022", "otccf-v1.1", "csta-2026", "scywf-1.5", "cybok-v1.1.0")
  )
})

test_that("the three v0.3.0 frameworks carry their jurisdictions and types", {
  new_rows <- framework_summary[
    framework_summary$framework_slug %in%
      c("cyqual-v1.2.0", "ccssf-2022", "otccf-v1.1"), ]
  expect_equal(nrow(new_rows), 3L)
  expect_true(all(new_rows$framework_type == "workforce"))
  expect_equal(
    new_rows$jurisdiction[match(
      c("cyqual-v1.2.0", "ccssf-2022", "otccf-v1.1"), new_rows$framework_slug)],
    c("CZ", "CA", "SG")
  )
})

test_that("role_count never exceeds organizing_unit_count", {
  expect_true(all(
    framework_summary$role_count <= framework_summary$organizing_unit_count,
    na.rm = TRUE
  ))
})

test_that("role_count is NA exactly for the frameworks that assert no roles", {
  na_slugs <- framework_summary$framework_slug[is.na(framework_summary$role_count)]
  expect_setequal(
    na_slugs,
    c("sfia-9", "cyberorg-k12-v1.0", "csta-2017", "csec2017-v1", "digcomp-3.0",
      "csta-2026", "cybok-v1.1.0")
  )
  # The role-dependent columns are NA together.
  expect_equal(is.na(framework_summary$elements_per_role_strict),
               is.na(framework_summary$role_count))
  expect_equal(is.na(framework_summary$elements_per_role_with_examples),
               is.na(framework_summary$role_count))
  # No other column is allowed to be NA.
  other <- framework_summary[, setdiff(
    names(framework_summary),
    c("role_count", "elements_per_role_strict", "elements_per_role_with_examples")
  )]
  expect_false(any(is.na(other)))
})

test_that("element_count_strict is with-examples less subpoints less examples", {
  expect_equal(
    framework_summary$element_count_strict,
    framework_summary$element_count_with_examples -
      framework_summary$subpoint_count -
      framework_summary$example_count
  )
})

test_that("OTCCF is the only framework publishing unit relations, and it has 310", {
  otccf <- framework_summary[framework_summary$framework_slug == "otccf-v1.1", ]
  expect_equal(otccf$unit_relation_count, 310L)
  others <- framework_summary[framework_summary$framework_slug != "otccf-v1.1", ]
  expect_true(all(others$unit_relation_count == 0L))
})

test_that("seven of the original eight frameworks' pre-existing values are unchanged", {
  # Pinned from the v0.2.0 shipped object. These are published figures.
  # DigComp is excluded here: 3.0 replaced 2.2 in place (2026-09-21), a
  # deliberate content change, not a regression. See the dedicated
  # "DigComp 3.0" test below for its pinned values.
  pinned <- tibble::tibble(
    framework_slug = c("nice-v2", "dcwf-v5.1", "ecsf-v1", "sfia-9",
                       "cyberorg-k12-v1.0", "csta-2017", "csec2017-v1"),
    organizing_unit_count = c(53L, 74L, 12L, 147L, 116L, 25L, 8L),
    element_count_strict =
      c(2211L, 2945L, 374L, 672L, 123L, 120L, 38L),
    subpoint_count = c(14L, 1107L, 16L, 149L, 0L, 24L, 2L),
    example_count = c(0L, 0L, 0L, 0L, 369L, 114L, 0L),
    element_count_with_examples =
      c(2225L, 4052L, 390L, 821L, 492L, 258L, 40L),
    elements_per_organizing_unit_strict =
      c(41.7, 39.8, 31.2, 4.6, 1.1, 4.8, 4.8),
    elements_per_organizing_unit_with_examples =
      c(42.0, 54.8, 32.5, 5.6, 4.2, 10.3, 5.0)
  )

  got <- framework_summary[match(pinned$framework_slug,
                                 framework_summary$framework_slug), ]
  expect_equal(nrow(got), 7L)

  for (cl in setdiff(names(pinned), "framework_slug")) {
    expect_equal(got[[cl]], pinned[[cl]], info = cl)
  }

  expect_equal(
    got$framework_type,
    c("workforce", "workforce", "workforce", "workforce",
      "pedagogy", "pedagogy", "pedagogy")
  )
  expect_equal(
    got$jurisdiction,
    c("US", "US", "EU", "global", "US", "US", "global")
  )
})

test_that("role densities are pinned for the six v0.3.0 role-asserting frameworks", {
  role_rows <- framework_summary[!is.na(framework_summary$role_count), ]
  expect_equal(nrow(role_rows), 7L)

  expect_equal(
    role_rows$role_count[match(
      c("nice-v2", "dcwf-v5.1", "ecsf-v1", "cyqual-v1.2.0", "ccssf-2022",
        "otccf-v1.1"),
      role_rows$framework_slug)],
    c(42L, 74L, 12L, 102L, 59L, 15L)
  )
  expect_equal(
    role_rows$elements_per_role_strict[match(
      c("nice-v2", "dcwf-v5.1", "ecsf-v1", "cyqual-v1.2.0", "ccssf-2022",
        "otccf-v1.1"),
      role_rows$framework_slug)],
    c(44.4, 39.8, 31.2, 22.9, 19.5, 18.0)
  )
  expect_equal(
    role_rows$elements_per_role_with_examples[match(
      c("nice-v2", "dcwf-v5.1", "ecsf-v1", "cyqual-v1.2.0", "ccssf-2022",
        "otccf-v1.1"),
      role_rows$framework_slug)],
    c(44.7, 54.8, 32.5, 30.9, 22.8, 18.0)
  )
})

test_that("the csta-2026 row carries its measured counts", {
  row <- framework_summary[framework_summary$framework_slug == "csta-2026", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$framework_type, "pedagogy")
  expect_equal(row$jurisdiction, "US")
  expect_equal(row$organizing_unit_count, 53L)
  expect_true(is.na(row$role_count))
  expect_equal(row$element_count_strict, 331L)
  expect_equal(row$example_count, 652L)
  expect_equal(row$element_count_with_examples,
               row$element_count_strict + row$subpoint_count + row$example_count)
  expect_equal(row$license, "CC BY-NC-SA 4.0")
})

test_that("the scywf row carries its measured counts", {
  row <- framework_summary[framework_summary$framework_slug == "scywf-1.5", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$framework_name, "SCyWF 1.5")
  expect_equal(row$framework_type, "workforce")
  expect_equal(row$jurisdiction, "SA")
  # 40 job roles + 24 competency areas + 12 specialty areas + 5 categories.
  expect_equal(row$organizing_unit_count, 81L)
  expect_equal(row$role_count, 40L)
  expect_equal(row$element_count_strict, 1419L)
  expect_equal(row$subpoint_count, 0L)
  expect_equal(row$example_count, 0L)
  expect_equal(row$element_count_with_examples, 1419L)
  expect_equal(row$unit_relation_count, 0L)
  expect_equal(row$elements_per_organizing_unit_strict, 17.5)
  # 1,418 distinct statements reach a role. S1505 is on no role card.
  expect_equal(row$elements_per_role_strict, 35.5)
  expect_equal(row$license, "NCA written permission")
})

test_that("the cybok row carries its measured counts", {
  row <- framework_summary[framework_summary$framework_slug == "cybok-v1.1.0", ]
  expect_equal(nrow(row), 1L)
  expect_equal(row$framework_name, "CyBOK v1.1.0")
  expect_equal(row$framework_type, "pedagogy")
  expect_equal(row$jurisdiction, "UK")
  # 21 Knowledge Areas. CyBOK asserts no roles.
  expect_equal(row$organizing_unit_count, 21L)
  expect_true(is.na(row$role_count))
  # 119 Topics, with the 477 Indicative Material nodes as Subpoints.
  expect_equal(row$element_count_strict, 119L)
  expect_equal(row$subpoint_count, 477L)
  expect_equal(row$example_count, 0L)
  expect_equal(row$element_count_with_examples, 596L)
  expect_equal(row$unit_relation_count, 0L)
  expect_equal(row$license, "OGL v3.0")
})
