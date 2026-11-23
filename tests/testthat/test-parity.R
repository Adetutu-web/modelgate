# Parity with bdp-model-gate 0.7.0, from fixtures made by tools/make_parity_fixtures.py.
# Parity is a second layer: the Python library has shipped wrong-but-plausible
# numbers before, so hand-derived known answers (test-split-overlap.R) come first.
skip_if_not_installed("jsonlite")
fx <- jsonlite::fromJSON(testthat::test_path("fixtures", "split_overlap_parity.json"),
                         simplifyVector = FALSE)

col_from_json <- function(x) {
  if (length(x) == 0L) return(logical(0))
  unlist(lapply(x, function(v) if (is.null(v)) NA else v))
}
frame_from_json <- function(cols) {
  if (is.null(cols)) return(NULL)
  as.data.frame(lapply(cols, col_from_json), stringsAsFactors = FALSE, check.names = FALSE)
}

test_that("fixtures were generated from the pinned upstream version", {
  expect_equal(fx$upstream_version, "0.7.0")
  expect_gt(length(fx$cases), 8L)
})

for (case in fx$cases) {
  local({
    case <- case
    test_that(paste("parity:", case$name), {
      cfg <- do.call(validation_config, case$config)
      expect_error_expected <- identical(case$expected[[1]]$flag, "CHECK_ERROR")
      rep <- run_gate_strict(
        gate_context(frame_from_json(case$X), X_train = frame_from_json(case$X_train)),
        list(split_overlap_check(cfg)),
        allow_check_error = expect_error_expected
      )
      expect_equal(length(rep$results), length(case$expected))
      for (i in seq_along(case$expected)) {
        got <- rep$results[[i]]; want <- case$expected[[i]]
        expect_equal(got$flag, want$flag, info = case$name)
        expect_equal(got$blocking, want$blocking, info = case$name)
        for (key in names(want$metadata)) {
          w <- want$metadata[[key]]
          if (is.numeric(w)) expect_equal(got$metadata[[key]], w, tolerance = 1e-4, info = paste(case$name, key))
          else expect_equal(got$metadata[[key]], w, info = paste(case$name, key))
        }
      }
    })
  })
}

# validation_strategy ---------------------------------------------------------
# These fixtures also carry upstream's `detail` text, compared after its em
# dashes become the ASCII hyphens this package uses.
vs <- jsonlite::fromJSON(testthat::test_path("fixtures", "validation_strategy_parity.json"),
                         simplifyVector = FALSE)
as_args <- function(x) lapply(x, function(v) if (is.list(v)) unlist(v) else v)
ascii_dashes <- function(x) gsub(" — ", " - ", x, fixed = TRUE)

test_that("validation_strategy fixtures were generated from the pinned upstream version", {
  expect_equal(vs$upstream_version, "0.7.0")
  expect_gt(length(vs$cases), 15L)
})

for (case in vs$cases) {
  local({
    case <- case
    test_that(paste("parity: validation_strategy", case$name), {
      chk <- validation_strategy_check(do.call(validation_config, as_args(case$config)),
                                       do.call(compliance_config, as_args(case$compliance)))
      rep <- run_gate_strict(gate_context(data.frame(a = c(1, 2, 3)), model_card = case$model_card),
                             list(chk))
      expect_equal(length(rep$results), length(case$expected))
      for (i in seq_along(case$expected)) {
        got <- rep$results[[i]]; want <- case$expected[[i]]
        expect_identical(got$flag, want$flag)
        expect_identical(got$blocking, want$blocking)
        expect_identical(got$detail, ascii_dashes(want$detail))
        expect_setequal(as.character(names(got$metadata)), as.character(names(want$metadata)))
        for (key in names(want$metadata)) {
          expect_identical(got$metadata[[key]], want$metadata[[key]], label = paste(case$name, key))
        }
      }
    })
  })
}

# feature_drift -----------------------------------------------------------------
fd <- jsonlite::fromJSON(testthat::test_path("fixtures", "feature_drift_parity.json"),
                         simplifyVector = FALSE)

test_that("feature_drift fixtures were generated from the pinned upstream version", {
  expect_equal(fd$upstream_version, "0.7.0")
  expect_gt(length(fd$cases), 15L)
})

for (case in fd$cases) {
  local({
    case <- case
    test_that(paste("parity: feature_drift", case$name), {
      ctx <- gate_context(frame_from_json(case$X), X_train = frame_from_json(case$X_train))
      rep <- run_gate_strict(ctx, list(feature_drift_check(do.call(validation_config, as_args(case$config)))))
      expect_equal(length(rep$results), length(case$expected))
      for (i in seq_along(case$expected)) {
        got <- rep$results[[i]]; want <- case$expected[[i]]
        expect_identical(got$flag, want$flag)
        expect_identical(got$blocking, want$blocking)
        expect_identical(got$detail, ascii_dashes(want$detail))
        expect_setequal(as.character(names(got$metadata)), as.character(names(want$metadata)))
        for (key in names(want$metadata)) {
          w <- want$metadata[[key]]
          if (is.numeric(w)) expect_equal(got$metadata[[key]], w, tolerance = 1e-4, label = paste(case$name, key))
          else expect_identical(got$metadata[[key]], w, label = paste(case$name, key))
        }
      }
    })
  })
}

# feature_contract ----------------------------------------------------------------
fc <- jsonlite::fromJSON(testthat::test_path("fixtures", "feature_contract_parity.json"),
                         simplifyVector = FALSE)
# Upstream metadata holds lists of names, or None where there is nothing to show.
expect_meta <- function(got, want, label) {
  if (is.null(want)) expect_null(got, label = label)
  else if (is.list(want)) expect_identical(got, as.character(unlist(want)), label = label)
  else expect_identical(got, want, label = label)
}

test_that("feature_contract fixtures were generated from the pinned upstream version", {
  expect_equal(fc$upstream_version, "0.7.0")
  expect_gt(length(fc$cases), 12L)
})

for (case in fc$cases) {
  local({
    case <- case
    test_that(paste("parity: feature_contract", case$name), {
      ef <- case$expected_features
      if (!is.null(ef)) ef <- as.character(unlist(ef))
      ctx <- gate_context(frame_from_json(case$X), X_train = frame_from_json(case$X_train),
                          expected_features = ef)
      rep <- run_gate_strict(ctx, list(feature_contract_check()))
      expect_equal(length(rep$results), length(case$expected))
      got <- rep$results[[1]]; want <- case$expected[[1]]
      expect_identical(got$flag, want$flag)
      expect_identical(got$blocking, want$blocking)
      expect_identical(got$detail, ascii_dashes(want$detail))
      expect_setequal(as.character(names(got$metadata)), as.character(names(want$metadata)))
      for (key in names(want$metadata)) {
        expect_meta(got$metadata[[key]], want$metadata[[key]], paste(case$name, key))
      }
    })
  })
}
