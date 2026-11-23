#' Run a set of checks and collect the verdict
#'
#' An error inside a check does not stop the gate: it becomes a blocking
#' `CHECK_ERROR` result, as in bdp-model-gate. That is right in production and
#' is also why tests must assert values rather than that a check "ran" - see
#' the `run_gate_strict()` helper in `tests/testthat/helper-guard.R`.
#'
#' A check that returns nothing, or anything other than a list of
#' [check_result()]s, is also a `CHECK_ERROR`: a check that says nothing must
#' not read as a check that found nothing.
#'
#' @param context A [gate_context()].
#' @param checks List of [new_check()] objects. Defaults to [default_checks()].
#' @return An object of class `gate_report`.
#' @export
run_gate <- function(context, checks = default_checks()) {
  if (!inherits(context, "gate_context")) stop("`context` must come from gate_context().", call. = FALSE)
  results <- list()
  for (chk in checks) {
    if (!inherits(chk, "gate_check")) stop("`checks` must be a list of gate_check objects.", call. = FALSE)
    start <- proc.time()[["elapsed"]]
    out <- tryCatch({
      res <- chk$run(context)
      if (!is.list(res) || length(res) == 0L ||
          !all(vapply(res, inherits, logical(1), what = "check_result"))) {
        stop("a check must return a non-empty list of check_result objects", call. = FALSE)
      }
      res
    }, error = function(e) list(check_error(chk, conditionMessage(e))))
    ms <- round((proc.time()[["elapsed"]] - start) * 1000, 2)
    out <- lapply(out, function(r) { r$duration_ms <- ms; r })
    results <- c(results, out)
  }
  structure(list(results = results), class = "gate_report")
}

#' Verdict for a report
#'
#' `BLOCKED` if any blocking check has a finding, `NEEDS_REVIEW` if only
#' non-blocking checks do, `PASS` otherwise. `NOT_APPLICABLE` is not a finding.
#'
#' @param report A `gate_report`.
#' @return `"PASS"`, `"NEEDS_REVIEW"` or `"BLOCKED"`.
#' @export
gate_status <- function(report) {
  failing <- Filter(function(r) !result_is_ok(r), report$results)
  if (any(vapply(failing, function(r) r$blocking, logical(1)))) return("BLOCKED")
  if (length(failing) > 0L) return("NEEDS_REVIEW")
  "PASS"
}

#' Process exit code for a report
#'
#' 0 = PASS, 1 = BLOCKED, 2 = NEEDS_REVIEW, as in the Python CLI, so a pipeline
#' can auto-deploy, hard-stop, or hand to a human.
#'
#' @inheritParams gate_status
#' @return An integer.
#' @export
gate_exit_code <- function(report) {
  switch(gate_status(report), PASS = 0L, BLOCKED = 1L, NEEDS_REVIEW = 2L)
}

#' The checks run by default
#' @return A list of `gate_check` objects.
#' @export
default_checks <- function() {
  list(split_overlap_check(), validation_strategy_check(), feature_contract_check(),
       feature_drift_check())
}

#' @export
print.gate_report <- function(x, ...) {
  df <- as.data.frame(x)
  findings <- df[!df$flag %in% c("OK", "NOT_APPLICABLE"), , drop = FALSE]
  cat("<gate_report> status: ", gate_status(x), " (", nrow(findings),
      " finding(s) in ", nrow(df), " result(s))\n", sep = "")
  for (i in seq_len(nrow(findings))) {
    cat("  [", if (findings$blocking[i]) "blocking" else "review", "] ",
        findings$check_name[i], ": ", findings$flag[i], "\n", sep = "")
  }
  invisible(x)
}

#' @export
as.data.frame.gate_report <- function(x, row.names = NULL, optional = FALSE, ...) {
  col <- function(f, type) vapply(x$results, function(r) r[[f]], type)
  data.frame(
    check_name = col("check_name", character(1)),
    category = col("category", character(1)),
    flag = col("flag", character(1)),
    blocking = col("blocking", logical(1)),
    detail = col("detail", character(1)),
    duration_ms = col("duration_ms", numeric(1)),
    stringsAsFactors = FALSE
  )
}
