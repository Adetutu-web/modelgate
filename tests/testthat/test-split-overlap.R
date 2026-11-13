# Known answers: every expected value below is derivable on paper.
cfg <- validation_config()
run1 <- function(X, X_train = NULL, config = cfg, ...) {
  run_gate_strict(gate_context(X, X_train = X_train), list(split_overlap_check(config)), ...)
}

test_that("one of ten rows seen in training is 10% overlap -> SPLIT_OVERLAP_RISK", {
  r <- result_for(run1(data.frame(a = 1:10), data.frame(a = 1L)), "overlap_with_training")
  expect_equal(r$flag, "SPLIT_OVERLAP_RISK")
  expect_equal(r$metadata$n_overlapping, 1L)
  expect_equal(r$metadata$overlap_fraction, 0.1)
  expect_true(r$blocking)
})

test_that("the threshold is inclusive: exactly 1% overlap passes, 2% does not", {
  X <- data.frame(a = 1:100)
  at <- result_for(run1(X, data.frame(a = c(1000:1099, 1L))), "overlap_with_training")
  expect_equal(at$metadata$overlap_fraction, 0.01)
  expect_equal(at$flag, "OK")
  over <- result_for(run1(X, data.frame(a = c(1000:1099, 1L, 2L))), "overlap_with_training")
  expect_equal(over$flag, "SPLIT_OVERLAP_RISK")
})

test_that("two repeated rows in twenty is 10% duplicates -> DUPLICATE_ROWS_RISK", {
  X <- data.frame(a = c(1:18, 1L, 2L))
  r <- result_for(run1(X), "duplicates_within_validation")
  expect_equal(r$metadata$n_duplicates, 2L)
  expect_equal(r$metadata$duplicate_fraction, 0.1)
  expect_equal(r$flag, "DUPLICATE_ROWS_RISK")
})

test_that("a duplicate is counted once per extra copy, not per member", {
  r <- result_for(run1(data.frame(a = c(1, 1, 1, 2))), "duplicates_within_validation")
  expect_equal(r$metadata$n_duplicates, 2L)          # three copies of 1 -> 2 extras
})

test_that("a clean split is OK on both findings", {
  rep <- run1(data.frame(a = 1:50), data.frame(a = 101:300))
  expect_equal(gate_status(rep), "PASS")
  expect_equal(result_for(rep, "overlap_with_training")$metadata$n_overlapping, 0L)
})

test_that("a custom threshold is honoured", {
  X <- data.frame(a = 1:10); tr <- data.frame(a = 1:3)   # 30% overlap
  expect_equal(result_for(run1(X, tr), "overlap_with_training")$flag, "SPLIT_OVERLAP_RISK")
  loose <- validation_config(max_split_overlap = 0.5)
  expect_equal(result_for(run1(X, tr, loose), "overlap_with_training")$flag, "OK")
})

# Every skip path, asserted on its reason string.
test_that("no X_train -> NOT_APPLICABLE, saying what to supply", {
  r <- result_for(run1(data.frame(a = 1:5)), "overlap_with_training")
  expect_equal(r$flag, "NOT_APPLICABLE")
  expect_match(r$detail, "no X_train supplied")
  expect_match(r$detail, "supply the training frame")
})

test_that("an empty X_train is treated as no X_train", {
  r <- result_for(run1(data.frame(a = 1:5), data.frame(a = integer(0))), "overlap_with_training")
  expect_equal(r$flag, "NOT_APPLICABLE")
  expect_match(r$detail, "no X_train supplied")
})

test_that("no shared columns -> NOT_APPLICABLE, pointing at feature_contract", {
  r <- result_for(run1(data.frame(a = 1:5), data.frame(b = 1:5)), "overlap_with_training")
  expect_equal(r$flag, "NOT_APPLICABLE")
  expect_match(r$detail, "share no column names")
  expect_match(r$detail, "feature_contract")
})

test_that("an empty validation set is a CHECK_ERROR, never a plausible number", {
  rep <- run1(data.frame(a = numeric(0)), data.frame(a = 1), allow_check_error = TRUE)
  expect_equal(rep$results[[1]]$flag, "CHECK_ERROR")
  expect_match(rep$results[[1]]$detail, "no rows")
  expect_equal(gate_status(rep), "BLOCKED")
})

# Metamorphic: the verdict must not move when the representation does.
base_val <- function() data.frame(a = c(1.5, 2.5, 3.5, 4.5), g = c("x", "y", "x", "z"))
base_tr <- function() data.frame(a = c(1.5, 2.5, 9, 10), g = c("x", "y", "q", "q"))
summarise <- function(rep) {
  r <- result_for(rep, "overlap_with_training")
  list(flag = r$flag, n = r$metadata$n_overlapping, cols = r$metadata$n_columns_compared)
}
test_that("permuting rows of either frame changes nothing", {
  ref <- summarise(run1(base_val(), base_tr()))
  expect_equal(ref$n, 2L)
  v <- base_val(); t <- base_tr()
  expect_equal(summarise(run1(v[4:1, ], t[c(3, 1, 4, 2), ])), ref)
})
test_that("reset or scrambled row names cannot hide or invent an overlap", {
  ref <- summarise(run1(base_val(), base_tr()))
  v <- base_val(); t <- base_tr()
  rownames(v) <- c("w", "x", "y", "z"); rownames(t) <- 100:103
  expect_equal(summarise(run1(v, t)), ref)
})
test_that("column order differences are ignored (matching is by name)", {
  ref <- summarise(run1(base_val(), base_tr()))
  expect_equal(summarise(run1(base_val(), base_tr()[c("g", "a")])), ref)
})
test_that("factor and character columns with the same values match", {
  v <- base_val(); t <- base_tr(); t$g <- factor(t$g)
  expect_equal(summarise(run1(v, t))$n, 2L)
})
test_that("integer and double columns with equal values match (deliberate)", {
  r <- result_for(run1(data.frame(a = 1:5), data.frame(a = as.numeric(1:5))), "overlap_with_training")
  expect_equal(r$metadata$n_overlapping, 5L)
  expect_equal(r$flag, "SPLIT_OVERLAP_RISK")
})
test_that("a string never matches a number", {
  r <- result_for(run1(data.frame(a = 1:3), data.frame(a = c("1", "2", "3"))), "overlap_with_training")
  expect_equal(r$metadata$n_overlapping, 0L)
})
test_that("missing values match each other, so NA rows can overlap", {
  v <- data.frame(a = c(1, NA, 3)); t <- data.frame(a = c(NA, 9))
  expect_equal(result_for(run1(v, t), "overlap_with_training")$metadata$n_overlapping, 1L)
})
test_that("values differing only past 15 digits are different rows", {
  v <- data.frame(a = 0.1 + 0.2); t <- data.frame(a = 0.3)
  expect_equal(result_for(run1(v, t), "overlap_with_training")$metadata$n_overlapping, 0L)
})

# Hostile shapes from bdp-model-gate's conftest.
test_that("only shared columns are compared and the count is reported", {
  v <- data.frame(a = 1:4, only_val = 1:4); t <- data.frame(a = 1:4, only_train = 9)
  r <- result_for(run1(v, t), "overlap_with_training")
  expect_equal(r$metadata$n_columns_compared, 1L)
  expect_equal(r$metadata$n_overlapping, 4L)
})
test_that("all-categorical frames: coincidental repeats are reported with a caveat", {
  v <- data.frame(c = rep(c("a", "b"), 10)); t <- data.frame(c = c("a", "b"))
  r <- result_for(run1(v, t), "overlap_with_training")
  expect_equal(r$metadata$n_overlapping, 20L)
  expect_match(r$detail, "coincidental repetition")
})
