ctx <- gate_context(data.frame(a = 1:3))
fake <- function(flag, blocking, name = "fake") {
  new_check(name, "validation", blocking, function(context) {
    list(check_result(name, "validation", flag, "", blocking))
  })
}

test_that("verdict is BLOCKED / NEEDS_REVIEW / PASS by blocking-ness", {
  expect_equal(gate_status(run_gate_strict(ctx, list(fake("OK", TRUE)))), "PASS")
  expect_equal(gate_status(run_gate_strict(ctx, list(fake("X_RISK", FALSE)))), "NEEDS_REVIEW")
  expect_equal(gate_status(run_gate_strict(ctx, list(fake("X_RISK", TRUE)))), "BLOCKED")
  both <- list(fake("X_RISK", FALSE, "a"), fake("Y_RISK", TRUE, "b"))
  expect_equal(gate_status(run_gate_strict(ctx, both)), "BLOCKED")
})

test_that("NOT_APPLICABLE is not a finding, even for a blocking check", {
  expect_equal(gate_status(run_gate_strict(ctx, list(fake("NOT_APPLICABLE", TRUE)))), "PASS")
})

test_that("exit codes match the Python CLI: 0 PASS, 1 BLOCKED, 2 NEEDS_REVIEW", {
  expect_equal(gate_exit_code(run_gate_strict(ctx, list(fake("OK", TRUE)))), 0L)
  expect_equal(gate_exit_code(run_gate_strict(ctx, list(fake("X", TRUE)))), 1L)
  expect_equal(gate_exit_code(run_gate_strict(ctx, list(fake("X", FALSE)))), 2L)
})

test_that("an error inside a check becomes a blocking CHECK_ERROR, not a crash", {
  boom <- new_check("boom", "validation", FALSE, function(context) stop("kaboom"))
  report <- run_gate(ctx, list(boom))
  r <- report$results[[1]]
  expect_equal(r$flag, "CHECK_ERROR")
  expect_true(r$blocking)                 # blocking even though the check is not
  expect_match(r$detail, "kaboom")
  expect_equal(gate_status(report), "BLOCKED")
})

test_that("a check that returns nothing, or garbage, is a CHECK_ERROR", {
  silent <- new_check("silent", "validation", TRUE, function(context) list())
  garbage <- new_check("garbage", "validation", TRUE, function(context) "all good")
  for (chk in list(silent, garbage)) {
    report <- run_gate(ctx, list(chk))
    expect_equal(report$results[[1]]$flag, "CHECK_ERROR")
    expect_equal(gate_status(report), "BLOCKED")
  }
})

test_that("the suite-wide guard itself fires on an unexpected CHECK_ERROR", {
  boom <- new_check("boom", "validation", TRUE, function(context) stop("kaboom"))
  expect_failure(run_gate_strict(ctx, list(boom)), "unexpected CHECK_ERROR")
  expect_no_failure <- run_gate_strict(ctx, list(boom), allow_check_error = TRUE)
  expect_s3_class(expect_no_failure, "gate_report")
})

test_that("constructors reject nonsense loudly", {
  expect_error(gate_context(list(a = 1)), "data.frame")
  expect_error(gate_context(data.frame(a = 1:3), y_true = 1:2), "length 2")
  expect_error(new_check("x", "nonsense", TRUE, identity), "category")
  expect_error(new_check("x", "validation", NA, identity), "blocking")
  expect_error(check_result("x", "validation", "", "", TRUE), "flag")
  expect_error(validation_config(max_split_overlap = 1.5), "between 0 and 1")
})

test_that("as.data.frame and print work on an empty and a full report", {
  empty <- run_gate(ctx, list())
  expect_equal(nrow(as.data.frame(empty)), 0L)
  expect_equal(gate_status(empty), "PASS")
  full <- run_gate_strict(ctx, list(fake("X_RISK", TRUE)))
  expect_equal(as.data.frame(full)$flag, "X_RISK")
  expect_output(print(full), "BLOCKED")
})
