#' The outcome of one check
#'
#' `flag` is `"OK"`, `"NOT_APPLICABLE"` (skipped, with the reason in
#' `detail`), `"CHECK_ERROR"` (the check raised an error), or a check-specific
#' risk string such as `"SPLIT_OVERLAP_RISK"`. Anything other than the first
#' two counts as a finding.
#'
#' @param check_name,category,flag,detail Strings.
#' @param blocking `TRUE` if a finding must stop the deploy, `FALSE` if it only
#'   routes to human review.
#' @param metadata Named list of values behind the finding.
#' @param duration_ms Filled in by [run_gate()].
#' @return An object of class `check_result`.
#' @export
check_result <- function(check_name, category, flag, detail = "",
                         blocking = TRUE, metadata = list(),
                         duration_ms = NA_real_) {
  one_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  if (!one_string(check_name)) stop("`check_name` must be a non-empty string.", call. = FALSE)
  if (!one_string(category)) stop("`category` must be a non-empty string.", call. = FALSE)
  if (!one_string(flag)) stop("`flag` must be a non-empty string.", call. = FALSE)
  if (!is.character(detail) || length(detail) != 1L) stop("`detail` must be a string.", call. = FALSE)
  if (!is.logical(blocking) || length(blocking) != 1L || is.na(blocking)) {
    stop("`blocking` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.list(metadata)) stop("`metadata` must be a list.", call. = FALSE)
  structure(
    list(check_name = check_name, category = category, flag = flag,
         detail = detail, blocking = blocking, metadata = metadata,
         duration_ms = duration_ms),
    class = "check_result"
  )
}

result_is_ok <- function(r) r$flag %in% c("OK", "NOT_APPLICABLE")

# A skipped check must say why, in words the reader can act on.
not_applicable <- function(check, reason, metadata = list()) {
  check_result(check$name, check$category, "NOT_APPLICABLE", reason,
               check$blocking, metadata)
}

check_error <- function(check, message) {
  check_result(check$name, check$category, "CHECK_ERROR",
               paste0("check raised an error: ", message), blocking = TRUE)
}
