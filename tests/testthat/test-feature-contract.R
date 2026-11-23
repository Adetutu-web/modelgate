# Known answers for feature_contract. Parity with the Python library is a second
# layer, in test-parity.R.
contract <- function(X, X_train = NULL, expected_features = NULL) {
  rep <- run_gate_strict(gate_context(X, X_train = X_train, expected_features = expected_features),
                         list(feature_contract_check()))
  expect_length(rep$results, 1L)
  rep$results[[1]]
}
cols <- function(...) {
  nm <- c(...)
  as.data.frame(setNames(rep(list(c(1, 2, 3)), length(nm)), nm))
}
abc <- c("age", "income", "tenure")

test_that("the right columns in the right order pass", {
  r <- contract(cols(abc), expected_features = abc)
  expect_identical(r$flag, "OK")
  expect_identical(r$detail, "X matches the 3 feature(s) recorded in context.expected_features, in order")
  expect_null(r$metadata$expected_order)
  expect_null(r$metadata$actual_order)
  expect_identical(r$metadata$n_features, 3L)
})

test_that("the right columns in a different order are flagged, with both orders shown", {
  r <- contract(cols("tenure", "income", "age"), expected_features = abc)
  expect_identical(r$flag, "FEATURE_ORDER_RISK")
  expect_true(r$blocking)
  expect_identical(r$metadata$expected_order, abc)
  expect_identical(r$metadata$actual_order, c("tenure", "income", "age"))
  expect_match(r$detail, "silently wrong for anything handed a positional array", fixed = TRUE)
})

test_that("any reordering is caught, including a single swap", {
  for (perm in list(c(2, 1, 3), c(1, 3, 2), c(3, 2, 1), c(2, 3, 1), c(3, 1, 2))) {
    r <- contract(cols(abc[perm]), expected_features = abc)
    expect_identical(r$flag, "FEATURE_ORDER_RISK", label = paste(abc[perm], collapse = ","))
  }
})

test_that("missing and unexpected columns are named, in a stable order", {
  r <- contract(cols("applicant_age", "income", "tenure"), expected_features = abc)
  expect_identical(r$flag, "FEATURE_CONTRACT_RISK")
  expect_identical(r$metadata$missing, "age")
  expect_identical(r$metadata$unexpected, "applicant_age")
  expect_identical(r$detail, paste0(
    "X does not match the 3 feature(s) recorded in context.expected_features - ",
    "missing from X: age; not seen in training: applicant_age"))

  r <- contract(cols("z"), expected_features = c("c", "a", "b"))
  expect_identical(r$metadata$missing, c("c", "a", "b"))     # in expected order
  expect_identical(r$metadata$unexpected, "z")
})

test_that("only-missing and only-unexpected each report just their own part", {
  r <- contract(cols("age"), expected_features = abc)
  expect_identical(r$metadata$unexpected, character(0))
  expect_match(r$detail, "missing from X: income, tenure$")
  r <- contract(cols(abc, "postcode"), expected_features = abc)
  expect_identical(r$metadata$missing, character(0))
  expect_match(r$detail, "not seen in training: postcode$")
})

test_that("a set mismatch is reported instead of an order problem", {
  r <- contract(cols("tenure", "age"), expected_features = abc)
  expect_identical(r$flag, "FEATURE_CONTRACT_RISK")
  expect_identical(r$metadata$check, "feature_set")
})

test_that("X_train's columns are the fallback, and expected_features wins over them", {
  r <- contract(cols("a", "b"), X_train = cols("a", "b"))
  expect_identical(r$metadata$source, "X_train.columns")
  expect_identical(r$flag, "OK")
  r <- contract(cols("b", "a"), X_train = cols("a", "b"))
  expect_identical(r$flag, "FEATURE_ORDER_RISK")
  r <- contract(cols("a", "b"), X_train = cols("b", "a"), expected_features = c("a", "b"))
  expect_identical(r$metadata$source, "context.expected_features")
  expect_identical(r$flag, "OK")
})

test_that("an empty expected list is a mismatch, not a pass", {
  r <- contract(cols("a", "b"), expected_features = character(0))
  expect_identical(r$flag, "FEATURE_CONTRACT_RISK")
  expect_identical(r$metadata$n_expected, 0L)
  expect_identical(r$metadata$unexpected, c("a", "b"))
})

test_that("with no way to know the schema it skips with a reason", {
  for (train in list(NULL, cols("a", "b")[0, , drop = FALSE])) {
    r <- contract(cols("a", "b"), X_train = train)
    expect_identical(r$flag, "NOT_APPLICABLE")
    expect_match(r$detail, "expected_features", fixed = TRUE)
  }
})

test_that("column values and row order play no part", {
  X <- data.frame(a = c(5, 6, 7), b = c("x", "y", "z"))
  same <- contract(X[c(3, 1, 2), ], expected_features = c("a", "b"))
  other <- contract(data.frame(a = c("q", "r"), b = c(TRUE, FALSE)), expected_features = c("a", "b"))
  expect_identical(same$flag, "OK")
  expect_identical(other$flag, "OK")
})

test_that("it blocks, and runs by default", {
  expect_true(feature_contract_check()$blocking)
  rep <- run_gate_strict(gate_context(cols("b", "a"), expected_features = c("a", "b")),
                         list(feature_contract_check()))
  expect_identical(gate_status(rep), "BLOCKED")
  names <- vapply(default_checks(), function(chk) chk$name, character(1))
  expect_true("feature_contract" %in% names)
})

test_that("expected_features must be a character vector", {
  expect_error(gate_context(cols("a"), expected_features = 1), "character vector")
  expect_error(gate_context(cols("a"), expected_features = c("a", NA)), "character vector")
})
