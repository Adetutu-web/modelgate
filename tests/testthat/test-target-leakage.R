# Known answers for target_leakage and the statistics under it. Parity with the
# Python library is a second layer, in test-parity.R.

test_that("rank_auc matches hand-worked cases", {
  expect_identical(rank_auc(c(FALSE, FALSE, TRUE, TRUE), c(0.1, 0.2, 0.8, 0.9)), 1)
  expect_identical(rank_auc(c(TRUE, TRUE, FALSE, FALSE), c(0.1, 0.2, 0.8, 0.9)), 0)
  expect_identical(rank_auc(c(FALSE, TRUE, FALSE, TRUE), rep(0.5, 4)), 0.5)   # ties share ranks
  expect_identical(rank_auc(c(FALSE, TRUE, FALSE, TRUE), c(0.1, 0.2, 0.3, 0.4)), 0.75)
  expect_true(is.nan(rank_auc(c(TRUE, TRUE), c(0.1, 0.9))))
  expect_true(is.nan(rank_auc(c(FALSE, FALSE), c(0.1, 0.9))))
})

test_that("abs_pearson and eta_squared match hand-worked cases", {
  expect_identical(abs_pearson(c(1, 1, 1), c(1, 2, 3)), 0)
  expect_equal(abs_pearson(1:10, 3 * (1:10) + 7), 1)
  expect_equal(abs_pearson(1:10, -(1:10)), 1)
  expect_equal(abs_pearson(c(1, 2, 3), c(1, 3, 2)), 0.5)
  # x = 1,2 | 3,4: total SS 5, between-group SS 4, so eta squared 0.8.
  expect_equal(eta_squared(c(1, 2, 3, 4), c("a", "a", "b", "b")), 0.8)
  expect_identical(eta_squared(c(1, 2, 1, 2), c("a", "a", "b", "b")), 0)
  expect_identical(eta_squared(c(5, 5, 5), c("a", "b", "c")), 0)
})

test_that("task inference follows upstream's rules", {
  expect_identical(infer_task(c(0, 1, 1)), "binary")
  expect_identical(infer_task(c(TRUE, FALSE)), "binary")
  expect_identical(infer_task(c("yes", "no")), "binary")
  expect_identical(infer_task(c(1, 2, 3)), "multiclass")
  expect_identical(infer_task(letters[1:3]), "multiclass")
  expect_identical(infer_task(0:20), "regression")          # 21 distinct whole numbers
  expect_identical(infer_task(0:19), "multiclass")          # 20
  expect_identical(infer_task(c(0.5, 1.5, 2.25)), "regression")
  expect_identical(resolve_task(gate_context(data.frame(a = 1:3), y_true = c(1, 2, 3), task = "regression")),
                   "regression")
  expect_error(gate_context(data.frame(a = 1), task = "classification"), "must be one of")
})

# 20 negatives then 20 positives.
y <- rep(c(0, 1), each = 20)
perfect <- 1:40
# Positives take values 3..22, negatives 1, 2 and 23..40: AUC = 40/400 = 0.1,
# so solo power |2 * 0.1 - 1| = 0.8 exactly.
point_eight <- c(1, 2, 23:40, 3:22)

leak <- function(X, y_true = y, y_pred = perfect, ..., config = validation_config()) {
  rep <- run_gate_strict(gate_context(X, y_true = y_true, y_pred = y_pred, ...),
                         list(target_leakage_check(config)))
  rep$results
}
flags <- function(results) vapply(results, function(r) r$flag, character(1))

test_that("a copy of the target is flagged, with the exact message", {
  r <- leak(data.frame(settled = y * 1000, age = rep(c(30, 40), 20)))
  expect_identical(flags(r), "LEAKAGE_RISK")
  expect_identical(r[[1]]$metadata$feature, "settled")
  expect_identical(r[[1]]$metadata$feature_power, 1)
  expect_identical(r[[1]]$metadata$power_ratio, 1)
  expect_identical(r[[1]]$detail, paste0(
    "settled alone reaches 1.000 of the target on its own, 100% of the whole model's ",
    "1.000 - check it is populated before the outcome is known, and is available at ",
    "scoring time"))
})

test_that("both conditions must hold, and both thresholds are inclusive", {
  # Feature power 0.8 against a perfect model: passes min_power, fails the ratio.
  r <- leak(data.frame(f = point_eight))
  expect_identical(flags(r), "OK")
  expect_identical(r[[1]]$metadata$model_power, 1)
  r <- leak(data.frame(f = point_eight), config = validation_config(leakage_ratio = 0.8))
  expect_identical(flags(r), "LEAKAGE_RISK")                  # 0.8 >= 0.8 * 1
  # The same 0.8 against a model of 0.8: ratio 1, and 0.8 >= min_power 0.8.
  r <- leak(data.frame(f = point_eight), y_pred = point_eight)
  expect_identical(flags(r), "LEAKAGE_RISK")
  r <- leak(data.frame(f = point_eight), y_pred = point_eight,
            config = validation_config(leakage_min_power = 0.81))
  expect_identical(flags(r), "OK")
})

test_that("a feature that predicts the target backwards is as much a leak", {
  r <- leak(data.frame(still_open = 1 - y))
  expect_identical(flags(r), "LEAKAGE_RISK")
  expect_identical(r[[1]]$metadata$feature_power, 1)
})

test_that("non-numeric columns are scored by correlation ratio; identifiers are skipped", {
  r <- leak(data.frame(status = ifelse(y == 1, "closed", "open")))
  expect_identical(flags(r), "LEAKAGE_RISK")
  r <- leak(data.frame(flagged = y == 1))
  expect_identical(flags(r), "LEAKAGE_RISK")
  r <- leak(data.frame(status = factor(ifelse(y == 1, "closed", "open"))))
  expect_identical(flags(r), "LEAKAGE_RISK")
  # 40 distinct values out of 40 rows: an identifier, so not scored even though
  # it is ordered by outcome.
  r <- leak(data.frame(row_id = sprintf("id%02d", 1:40)))
  expect_identical(flags(r), "OK")
})

test_that("a category is scored by eta, not eta squared", {
  # Group A holds 18 positives and 2 negatives, group B the reverse: between-group
  # SS 6.4 of a total 10, so eta squared 0.64 and eta 0.8.
  status <- ifelse(y == 1, "A", "B")
  status[1:2] <- "A"
  status[21:22] <- "B"
  cfg <- validation_config(leakage_min_power = 0.75, leakage_ratio = 0.5)
  r <- leak(data.frame(status = status), config = cfg)
  expect_identical(flags(r), "LEAKAGE_RISK")
  expect_equal(r[[1]]$metadata$feature_power, 0.8)
  expect_match(r[[1]]$detail, "^status alone reaches 0.800 of the target")
})

test_that("a continuous target uses |r|, sign ignored", {
  yr <- c(3.1, 1.2, 4.8, 2.2, 5.9, 0.4, 3.3, 2.8, 4.1, 1.7)
  yr <- c(yr, yr + 0.05, yr - 0.05)
  pred <- yr + rep(c(0.5, -0.5), 15)
  r <- leak(data.frame(paid = 3 * yr + 7, remaining = -yr), y_true = yr, y_pred = pred,
            task = "regression")
  expect_identical(flags(r), c("LEAKAGE_RISK", "LEAKAGE_RISK"))
  expect_equal(r[[1]]$metadata$feature_power, 1)
  expect_equal(r[[1]]$metadata$model_power, round(abs_pearson(pred, yr), 4))
})

test_that("suspects are listed strongest first", {
  # Negatives take 0.1, 0.5, 1.0, 1.5, 2.5 and positives 2.1, 2.5, 3.0, 3.5, 4.5,
  # four of each: 16 pairs reversed and 16 tied, so AUC = (400 - 16 - 8) / 400
  # = 0.94 and solo power 0.88. Listed after `a`, whose power is 1.
  noisy <- y * 2 + rep(c(0.1, 0.5, 1.0, 1.5, 2.5), 8)
  r <- leak(data.frame(b = noisy, a = y * 3), config = validation_config(leakage_ratio = 0.5))
  expect_identical(vapply(r, function(x) x$metadata$feature, character(1)), c("a", "b"))
  expect_equal(vapply(r, function(x) x$metadata$feature_power, numeric(1)), c(1, 0.88))
})

test_that("a column needs 20 usable values; constants score 0", {
  short <- c(y[1:19] * 5, rep(NA, 21))
  expect_identical(flags(leak(data.frame(s = short), y_pred = point_eight)), "OK")
  enough <- c(rep(NA, 10), (y * 5)[11:40])
  expect_identical(flags(leak(data.frame(s = enough))), "LEAKAGE_RISK")
  expect_identical(flags(leak(data.frame(k = rep(0.1, 40)), y_pred = point_eight)), "OK")
})

test_that("rows with no y_true are left out and counted, so a leak is still found", {
  y_na <- y; y_na[c(1, 2, 39, 40)] <- NA
  r <- leak(data.frame(settled = y * 1000), y_true = y_na)
  expect_identical(flags(r), "LEAKAGE_RISK")
  expect_true(endsWith(r[[1]]$detail, " (4 row(s) with no y_true were left out)"))
  # Upstream returns OK with a model power of NaN here (see README).
  yr <- seq(0.5, 20, by = 0.5); yr_na <- yr; yr_na[1:5] <- NA
  r <- leak(data.frame(paid = yr * 2), y_true = yr_na, y_pred = yr + rep(c(1, -1), 20),
            task = "regression")
  expect_identical(flags(r), "LEAKAGE_RISK")
})

test_that("rows, units and an extra column do not change the answer", {
  X <- data.frame(settled = y * 1000, f = point_eight)
  ref <- leak(X)
  idx <- c(40:21, 1:20)
  shuffled <- leak(X[idx, ], y_true = y[idx], y_pred = perfect[idx])
  rescaled <- leak(transform(X, settled = settled / 1000 + 5, f = f * 2))
  extra <- leak(cbind(X, other = rep(c(1, 2), 20)))
  meta <- function(r) lapply(r, function(x) x$metadata)
  expect_identical(meta(shuffled), meta(ref))
  expect_identical(meta(rescaled), meta(ref))
  expect_identical(meta(extra)[[1]][c("feature", "feature_power")], meta(ref)[[1]][c("feature", "feature_power")])
})

test_that("skips say why", {
  rep <- run_gate_strict(gate_context(data.frame(a = 1:40), y_true = y), list(target_leakage_check()))
  expect_identical(rep$results[[1]]$flag, "NOT_APPLICABLE")
  expect_match(rep$results[[1]]$detail, "no y_true/y_pred", fixed = TRUE)
  r <- leak(data.frame(a = 1:40), y_pred = rep(0.3, 40))
  expect_identical(flags(r), "NOT_APPLICABLE")
  expect_match(r[[1]]$detail, "carry no signal", fixed = TRUE)
  yc <- rep(0:3, 10)
  r <- leak(data.frame(a = yc * 2), y_true = yc, y_pred = yc + 0.5)
  expect_identical(flags(r), "NOT_APPLICABLE")
  expect_match(r[[1]]$detail, "set task = \"regression\"", fixed = TRUE)
  r <- leak(data.frame(a = yc * 2), y_true = yc, y_pred = yc + rep(c(0.5, -0.5), 20), task = "regression")
  expect_identical(flags(r), "LEAKAGE_RISK")
})

test_that("text labels and text predictions stop with a message saying what to do", {
  rep <- run_gate_strict(gate_context(data.frame(a = 1:40), y_true = ifelse(y == 1, "yes", "no"),
                                      y_pred = perfect),
                         list(target_leakage_check()), allow_check_error = TRUE)
  expect_identical(rep$results[[1]]$flag, "CHECK_ERROR")
  expect_match(rep$results[[1]]$detail, "recode the outcome", fixed = TRUE)
  rep <- run_gate_strict(gate_context(data.frame(a = 1:40), y_true = y, y_pred = as.character(perfect)),
                         list(target_leakage_check()), allow_check_error = TRUE)
  expect_match(rep$results[[1]]$detail, "y_pred must be a numeric score", fixed = TRUE)
})

test_that("it blocks, and runs first by default", {
  expect_true(target_leakage_check()$blocking)
  expect_identical(gate_status(run_gate_strict(gate_context(data.frame(s = y), y_true = y, y_pred = perfect),
                                               list(target_leakage_check()))), "BLOCKED")
  expect_identical(default_checks()[[1]]$name, "target_leakage")
})
