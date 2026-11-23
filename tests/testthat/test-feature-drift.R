# Known answers for feature_drift, worked out by hand. Parity with the Python
# library is a second layer, in test-parity.R.
drift <- function(X, X_train, config = validation_config()) {
  rep <- run_gate_strict(gate_context(X, X_train = X_train), list(feature_drift_check(config)))
  rep$results
}
flags <- function(results) vapply(results, function(r) r$flag, character(1))

# Training values -1 and 1, ten of each: mean 0, sample sd sqrt(20 / 19).
base <- rep(c(-1, 1), 10)
sd_base <- sqrt(20 / 19)

test_that("a numeric shift is measured in training standard deviations", {
  r <- drift(data.frame(x = base + 0.5), data.frame(x = base))
  expect_identical(flags(r), "DRIFT_RISK")
  expect_equal(r[[1]]$metadata$shift, round(0.5 / sd_base, 4))
  expect_identical(r[[1]]$metadata$measure, "standardised mean shift")
  expect_identical(r[[1]]$metadata$threshold, 0.25)
  expect_identical(r[[1]]$detail, sprintf(paste0(
    "x: standardised mean shift %.3f between training and validation (max 0.25) - the ",
    "model is being graded on a different population from the one it was fitted to"),
    0.5 / sd_base))
})

test_that("a shift clearly under the threshold passes, and one clearly over is flagged", {
  expect_identical(flags(drift(data.frame(x = base + 0.2 * sd_base), data.frame(x = base))), "OK")
  expect_identical(flags(drift(data.frame(x = base + 0.3 * sd_base), data.frame(x = base))), "DRIFT_RISK")
})

test_that("the measure ignores units and the direction of the shift", {
  up <- drift(data.frame(x = base + 0.5), data.frame(x = base))[[1]]$metadata$shift
  down <- drift(data.frame(x = base - 0.5), data.frame(x = base))[[1]]$metadata$shift
  scaled <- drift(data.frame(x = (base + 0.5) * 1000), data.frame(x = base * 1000))[[1]]$metadata$shift
  expect_equal(down, up)
  expect_equal(scaled, up)
})

test_that("categories are compared by total variation distance", {
  # Disjoint levels: TVD is exactly 1.
  r <- drift(data.frame(region = rep("Kano", 30)), data.frame(region = rep("Lagos", 30)))
  expect_identical(r[[1]]$metadata$shift, 1)
  expect_identical(r[[1]]$metadata$measure, "total variation distance")
  # 50/50 in training, 75/25 in validation: TVD = 0.25.
  r <- drift(data.frame(c = rep(c("a", "b"), c(30, 10))), data.frame(c = rep(c("a", "b"), 20)))
  expect_identical(r[[1]]$metadata$shift, 0.25)
  expect_identical(r[[1]]$metadata$threshold, 0.15)
  # The same mix in both frames: TVD = 0.
  expect_identical(flags(drift(data.frame(c = rep(c("a", "b"), 20)), data.frame(c = rep(c("b", "a"), 20)))), "OK")
})

test_that("a shift exactly at the threshold is not drift; only above it is", {
  # 75/25 against 50/50 is a TVD of exactly 0.25, with no rounding on the way.
  X <- data.frame(c = rep(c("a", "b"), c(30, 10)))
  X_train <- data.frame(c = rep(c("a", "b"), 20))
  expect_identical(flags(drift(X, X_train, validation_config(categorical_drift_threshold = 0.25))), "OK")
  expect_identical(flags(drift(X, X_train, validation_config(categorical_drift_threshold = 0.24))), "DRIFT_RISK")
})

test_that("factor, character and logical columns are all treated as categories", {
  chr <- drift(data.frame(c = rep(c("a", "b"), c(30, 10))), data.frame(c = rep(c("a", "b"), 20)))
  fac <- drift(data.frame(c = factor(rep(c("a", "b"), c(30, 10)))), data.frame(c = factor(rep(c("a", "b"), 20))))
  lgl <- drift(data.frame(c = rep(c(TRUE, FALSE), c(30, 10))), data.frame(c = rep(c(TRUE, FALSE), 20)))
  expect_identical(fac[[1]]$metadata$shift, chr[[1]]$metadata$shift)
  expect_identical(lgl[[1]]$metadata$shift, chr[[1]]$metadata$shift)
})

test_that("integer and double columns are both numeric; a number and a string never match", {
  r <- drift(data.frame(x = as.double(1:40) + 10.5), data.frame(x = 1:40))
  expect_identical(r[[1]]$metadata$measure, "standardised mean shift")
  # Upstream reports 0.75 here (pandas looks the levels up by position); the
  # levels have nothing in common, so the distance is 1. See README.
  r <- drift(data.frame(code = rep(c("1", "2"), 15)), data.frame(code = rep(1:2, 15)))
  expect_identical(r[[1]]$metadata$measure, "total variation distance")
  expect_identical(r[[1]]$metadata$shift, 1)
  r <- drift(data.frame(code = rep(c("1", "2", "3"), 10)), data.frame(code = rep(1:3, 10)))
  expect_identical(r[[1]]$metadata$shift, 1)
})

test_that("one result per drifted feature, largest shift first", {
  # Shifts: b = 0.9 / sd_base = 0.877, c = TVD 0.5, a = 0.4 / sd_base = 0.390.
  X_train <- data.frame(a = base, b = base, c = rep(c("p", "q"), 10))
  X <- data.frame(c = rep("p", 20), a = base + 0.4, b = base + 0.9)
  r <- drift(X, X_train)
  expect_identical(vapply(r, function(x) x$metadata$feature, character(1)), c("b", "c", "a"))
  expect_equal(vapply(r, function(x) x$metadata$shift, numeric(1)),
               round(c(0.9 / sd_base, 0.5, 0.4 / sd_base), 4))
  expect_true(all(vapply(r, function(x) x$metadata$n_features_scored, integer(1)) == 3L))
})

test_that("a training column with one repeated value is skipped, never divided by ~0", {
  # Upstream flags 0.1 here with a shift in the trillions; see README.
  for (v in c(1, 0.1, 0.7, 3.3)) {
    r <- drift(data.frame(k = rep(v + 0.001, 30), x = base[1:20][rep(1:20, length.out = 30)]),
               data.frame(k = rep(v, 30), x = base[1:20][rep(1:20, length.out = 30)]))
    expect_identical(flags(r), "OK", label = paste("constant", v))
    expect_identical(r[[1]]$metadata$n_features_scored, 1L)
  }
  r <- drift(data.frame(k = rep(0.2, 30)), data.frame(k = rep(0.1, 30)))
  expect_identical(flags(r), "NOT_APPLICABLE")
})

test_that("a feature needs 20 usable values in both frames", {
  expect_identical(flags(drift(data.frame(x = base[1:19] + 5), data.frame(x = base[1:19]))), "NOT_APPLICABLE")
  expect_identical(flags(drift(data.frame(x = base + 5), data.frame(x = base))), "DRIFT_RISK")
  expect_identical(flags(drift(data.frame(x = base[1:19] + 5), data.frame(x = rep(base, 5)))), "NOT_APPLICABLE")
  r <- drift(data.frame(x = base[1:19] + 5), data.frame(x = base[1:19]))
  expect_identical(r[[1]]$detail, "no shared feature had at least 20 usable rows in both frames")
})

test_that("missing values are dropped before counting and measuring", {
  # 20 real values plus 10 NA in training: still scored, and the NAs do not move the mean.
  with_na <- data.frame(x = c(base, rep(NA, 10)))
  r <- drift(data.frame(x = base + 0.5), with_na)
  expect_equal(r[[1]]$metadata$shift, round(0.5 / sd_base, 4))
  # 19 real values: not scored.
  expect_identical(flags(drift(data.frame(x = base + 5), data.frame(x = c(base[1:19], rep(NA, 30))))),
                   "NOT_APPLICABLE")
})

test_that("row order and the training frame's column order do not matter", {
  X_train <- data.frame(a = base * 3 + 1, c = rep(c("p", "q", "r", "s"), 5))
  X <- data.frame(a = base * 3 + 2.5, c = rep(c("p", "p", "q", "r"), 5))
  ref <- drift(X, X_train)
  shuffled <- drift(X[c(20:1), ], X_train[sample(20), rev(names(X_train))])
  expect_identical(flags(shuffled), flags(ref))
  expect_equal(lapply(shuffled, function(r) r$metadata), lapply(ref, function(r) r$metadata))
})

test_that("drift is non-blocking: a finding means NEEDS_REVIEW, not BLOCKED", {
  expect_false(feature_drift_check()$blocking)
  rep <- run_gate_strict(gate_context(data.frame(x = base + 5), X_train = data.frame(x = base)),
                         list(feature_drift_check()))
  expect_false(rep$results[[1]]$blocking)
  expect_identical(gate_status(rep), "NEEDS_REVIEW")
  expect_identical(gate_exit_code(rep), 2L)
})

test_that("skips say why", {
  r <- drift(data.frame(x = base), NULL)
  expect_identical(flags(r), "NOT_APPLICABLE")
  expect_match(r[[1]]$detail, "no X_train supplied", fixed = TRUE)
  expect_identical(flags(drift(data.frame(x = base), data.frame(x = numeric(0)))), "NOT_APPLICABLE")
  r <- drift(data.frame(x = base), data.frame(y = base))
  expect_match(r[[1]]$detail, "share no column names", fixed = TRUE)
})

test_that("thresholds are configurable and printed the way upstream prints them", {
  cfg <- validation_config(drift_threshold = 1, categorical_drift_threshold = 0.3)
  r <- drift(data.frame(x = base + 2), data.frame(x = base), cfg)
  expect_match(r[[1]]$detail, "(max 1.0)", fixed = TRUE)
  expect_identical(flags(drift(data.frame(x = base + 0.5), data.frame(x = base), cfg)), "OK")
  expect_identical(flags(drift(data.frame(c = rep(c("a", "b"), c(30, 10))),
                               data.frame(c = rep(c("a", "b"), 20)), cfg)), "OK")
})

test_that("it runs by default", {
  names <- vapply(default_checks(), function(chk) chk$name, character(1))
  expect_true("feature_drift" %in% names)
})
