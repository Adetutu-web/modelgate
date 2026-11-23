# Thresholds for the validation checks

Defaults mirror `ValidationConfig` in bdp-model-gate 0.7.0.

## Usage

``` r
validation_config(
  leakage_ratio = 0.95,
  leakage_min_power = 0.8,
  max_split_overlap = 0.01,
  max_duplicate_fraction = 0.05,
  drift_threshold = 0.25,
  categorical_drift_threshold = 0.15,
  out_of_time_strategies = c("out_of_time", "temporal", "forward_chaining",
    "walk_forward"),
  accepted_validation_strategies = c("out_of_time", "temporal", "forward_chaining",
    "walk_forward", "random_split", "stratified_split", "cross_validation",
    "grouped_split"),
  require_out_of_time_for_high_risk = TRUE
)
```

## Arguments

- leakage_ratio:

  A feature is a suspected leak when its solo power reaches this
  fraction of the model's own. Used by
  [`target_leakage_check()`](https://adetutu-web.github.io/modelgate/reference/target_leakage_check.md).

- leakage_min_power:

  ...and only when that power is at least this, on 0-1: one ordinary
  feature should not explain the target this well.

- max_split_overlap:

  Largest tolerated fraction of validation rows that also appear in the
  training frame.

- max_duplicate_fraction:

  Largest tolerated fraction of exact duplicate rows within the
  validation set.

- drift_threshold:

  Largest tolerated standardised mean shift for a numeric feature
  (difference in means over the training standard deviation). Used by
  [`feature_drift_check()`](https://adetutu-web.github.io/modelgate/reference/feature_drift_check.md).

- categorical_drift_threshold:

  Largest tolerated total variation distance, on 0-1, for any other
  feature. Used by
  [`feature_drift_check()`](https://adetutu-web.github.io/modelgate/reference/feature_drift_check.md).

- out_of_time_strategies:

  Values of `model_card$validation_strategy` that count as a holdout
  separated in time rather than at random.

- accepted_validation_strategies:

  Every value that field may take. An unrecognised value is flagged
  rather than accepted, because "holdout" and "out_of_time" are
  different claims and only one of them is checkable.

- require_out_of_time_for_high_risk:

  `TRUE` to flag a high-risk use case (see
  [`compliance_config()`](https://adetutu-web.github.io/modelgate/reference/compliance_config.md))
  that was not validated out of time.

## Value

A list of class `validation_config`.

## Examples

``` r
strict <- validation_config(max_split_overlap = 0, drift_threshold = 0.1)
X <- data.frame(age = c(25, 32, 47, 51))
report <- run_gate(gate_context(X, X_train = X[1, , drop = FALSE]),
                   list(split_overlap_check(strict)))
report$results[[2]]$flag
#> [1] "SPLIT_OVERLAP_RISK"
```
