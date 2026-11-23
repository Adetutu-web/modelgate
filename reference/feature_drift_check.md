# Does the validation set still look like the training set?

Train-serve skew: a feature whose distribution has moved between
`X_train` and `X`, so the model is graded on a population it was not
fitted to. That is not necessarily wrong - an out-of-time holdout
*should* differ a little - but a reviewer has to see it rather than
infer it. **Non-blocking**: a finding routes to `NEEDS_REVIEW`, because
a gate that hard-fails on every seasonal shift gets switched off.

## Usage

``` r
feature_drift_check(config = validation_config())
```

## Arguments

- config:

  A
  [`validation_config()`](https://adetutu-web.github.io/modelgate/reference/validation_config.md);
  uses `drift_threshold` and `categorical_drift_threshold`.

## Value

A `gate_check`.

## Details

Numeric features (in both frames) are compared by standardised mean
shift: the difference in means over the training standard deviation, so
the threshold is unitless. Anything else is compared by total variation
distance between the two frequency tables, on 0-1. Missing values are
dropped first, and a feature with fewer than 20 usable values in either
frame, or constant in training, is not scored. One `DRIFT_RISK` result
per drifted feature, largest shift first.

Port of `FeatureDriftCheck` in bdp-model-gate 0.7.0. One deliberate
difference: a training column whose values are all identical is always
treated as constant. Upstream tests its standard deviation against zero,
which rounding defeats for values such as 0.1, and then reports shifts
in the trillions.

## Examples

``` r
set.seed(1)
X_train <- data.frame(age = rnorm(200, 40, 10))
X_val <- data.frame(age = rnorm(100, 46, 10))   # six years older on average
report <- run_gate(gate_context(X_val, X_train = X_train), list(feature_drift_check()))
gate_status(report)                              # NEEDS_REVIEW: drift is not blocking
#> [1] "NEEDS_REVIEW"
report$results[[1]]$detail
#> [1] "age: standardised mean shift 0.639 between training and validation (max 0.25) - the model is being graded on a different population from the one it was fitted to"
```
