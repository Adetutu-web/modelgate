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
#' @param drift_threshold Largest tolerated standardised mean shift for a
#'   numeric feature (difference in means over the training standard
#'   deviation). Used by [feature_drift_check()].
#' @param categorical_drift_threshold Largest tolerated total variation
#'   distance, on 0-1, for any other feature. Used by [feature_drift_check()].
#' @param out_of_time_strategies Values of `model_card$validation_strategy`
#'   that count as a holdout separated in time rather than at random.
#' @param accepted_validation_strategies Every value that field may take. An
#'   unrecognised value is flagged rather than accepted, because "holdout" and
#'   "out_of_time" are different claims and only one of them is checkable.
#' @param require_out_of_time_for_high_risk `TRUE` to flag a high-risk use case
#'   (see [compliance_config()]) that was not validated out of time.
#' @return A list of class `validation_config`.
#' @export
validation_config <- function(leakage_ratio = 0.95,
                              leakage_min_power = 0.80,
                              max_split_overlap = 0.01,
                              max_duplicate_fraction = 0.05,
                              drift_threshold = 0.25,
                              categorical_drift_threshold = 0.15,
                              out_of_time_strategies = c("out_of_time", "temporal",
                                                         "forward_chaining", "walk_forward"),
                              accepted_validation_strategies = c("out_of_time", "temporal",
                                                                 "forward_chaining", "walk_forward",
                                                                 "random_split", "stratified_split",
                                                                 "cross_validation", "grouped_split"),
                              require_out_of_time_for_high_risk = TRUE) {
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
  check_strings(out_of_time_strategies, "out_of_time_strategies")
  check_strings(accepted_validation_strategies, "accepted_validation_strategies")
  if (!is.logical(require_out_of_time_for_high_risk) ||
      length(require_out_of_time_for_high_risk) != 1L ||
      is.na(require_out_of_time_for_high_risk)) {
    stop("`require_out_of_time_for_high_risk` must be TRUE or FALSE.", call. = FALSE)
  }
  structure(
    c(fractions, list(drift_threshold = drift_threshold,
                      out_of_time_strategies = out_of_time_strategies,
                      accepted_validation_strategies = accepted_validation_strategies,
                      require_out_of_time_for_high_risk = require_out_of_time_for_high_risk)),
    class = "validation_config"
  )
}

#' Settings for the compliance checks
#'
#' Defaults mirror `ComplianceConfig` in bdp-model-gate 0.7.0. Only the part the
#' ported checks use is here so far.
#'
#' @param high_risk_use_cases Use cases that must meet the stricter rules, such
#'   as an out-of-time validation. Matched as substrings of
#'   `model_card$use_case`, ignoring case, so `"pricing"` also covers
#'   `"motor_pricing_v2"`.
#' @return A list of class `compliance_config`.
#' @export
compliance_config <- function(high_risk_use_cases = c("pricing", "claims_decisioning",
                                                      "credit_scoring", "underwriting")) {
  check_strings(high_risk_use_cases, "high_risk_use_cases")
  structure(list(high_risk_use_cases = high_risk_use_cases), class = "compliance_config")
}

# A character vector with no missing values; empty is allowed.
check_strings <- function(x, name) {
  if (!is.character(x) || anyNA(x)) {
    stop("`", name, "` must be a character vector with no missing values.", call. = FALSE)
  }
  invisible(x)
}
