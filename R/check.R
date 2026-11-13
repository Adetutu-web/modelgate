valid_categories <- c("validation", "fairness", "performance", "compliance",
                      "security", "comparison")

#' Define a check
#'
#' A check is a name, a category, a `blocking` flag and a function that takes a
#' [gate_context()] and returns a non-empty list of [check_result()]s.
#'
#' `blocking = TRUE` means a finding stops the deploy; `FALSE` routes it to a
#' human as `NEEDS_REVIEW`. That is a judgement, not a default.
#'
#' @param name Snake_case name shown in the report.
#' @param category One of validation, fairness, performance, compliance,
#'   security, comparison.
#' @param blocking `TRUE` or `FALSE`.
#' @param run Function of one argument (the context).
#' @return An object of class `gate_check`.
#' @export
new_check <- function(name, category, blocking, run) {
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a non-empty string.", call. = FALSE)
  }
  if (!category %in% valid_categories) {
    stop("`category` must be one of: ", paste(valid_categories, collapse = ", "), ".", call. = FALSE)
  }
  if (!is.logical(blocking) || length(blocking) != 1L || is.na(blocking)) {
    stop("`blocking` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.function(run)) stop("`run` must be a function.", call. = FALSE)
  structure(list(name = name, category = category, blocking = blocking, run = run),
            class = "gate_check")
}
