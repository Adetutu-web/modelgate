# run_gate() turns an error inside a check into a blocking CHECK_ERROR *result*
# rather than propagating it. That is right in production, and it is why
# `expect_true(length(results) > 0)` passes on a check that crashed.
# Use this instead of run_gate() in tests: it fails on any CHECK_ERROR the test
# did not ask for. Pass allow_check_error = TRUE only when the error is the
# thing under test. (Mirrors the autouse guard in bdp-model-gate's conftest.py.)
run_gate_strict <- function(context, checks, allow_check_error = FALSE) {
  report <- run_gate(context, checks)
  if (!allow_check_error) {
    errs <- Filter(function(r) identical(r$flag, "CHECK_ERROR"), report$results)
    if (length(errs) > 0L) {
      testthat::fail(paste0("unexpected CHECK_ERROR: ", errs[[1]]$detail))
    }
  }
  report
}

# The single result of a given sub-check, so tests assert values, not counts.
result_for <- function(report, sub_check) {
  hits <- Filter(function(r) identical(r$metadata$check, sub_check), report$results)
  stopifnot(length(hits) == 1L)
  hits[[1]]
}
