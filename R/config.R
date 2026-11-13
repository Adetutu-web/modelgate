#' Thresholds for the validation checks
#'
#' Defaults mirror `ValidationConfig` in bdp-model-gate 0.7.0.
#'
#' @param leakage_ratio,leakage_min_power Both in (0, 1]; used by the
#'   target-leakage check (not yet ported).
#' @param max_split_overlap Largest tolerated fraction of validation rows that
#'   also appear in the training frame.
#' @param max_duplicate_fraction Largest tolerated fraction of exact duplicate
#'   rows within the validation set.
#' @param drift_threshold,categorical_drift_threshold Used by the drift check
#'   (not yet ported).
#' @return A list of class `validation_config`.
#' @export
validation_config <- function(leakage_ratio = 0.95,
                              leakage_min_power = 0.80,
                              max_split_overlap = 0.01,
                              max_duplicate_fraction = 0.05,
                              drift_threshold = 0.25,
                              categorical_drift_threshold = 0.15) {
  fractions <- list(
    leakage_ratio = leakage_ratio, leakage_min_power = leakage_min_power,
    max_split_overlap = max_split_overlap,
    max_duplicate_fraction = max_duplicate_fraction,
    categorical_drift_threshold = categorical_drift_threshold
  )
  for (nm in names(fractions)) {
    v <- fractions[[nm]]
    if (!is.numeric(v) || length(v) != 1L || is.na(v) || v < 0 || v > 1) {
      stop("`", nm, "` must be a single number between 0 and 1.", call. = FALSE)
    }
  }
  if (!is.numeric(drift_threshold) || length(drift_threshold) != 1L ||
      is.na(drift_threshold) || drift_threshold < 0) {
    stop("`drift_threshold` must be a single non-negative number.", call. = FALSE)
  }
  structure(
    c(fractions, list(drift_threshold = drift_threshold)),
    class = "validation_config"
  )
}
