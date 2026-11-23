# Does a single column do what the whole model does?

The signature of a leaked target: a field filled in *after* the outcome
was known and joined back into the data - a settlement amount on a
claims model, a closure reason on a churn model, an ID ordered by
outcome. The model learns it, scores beautifully offline, and collapses
in production where the column is empty at scoring time.

## Usage

``` r
target_leakage_check(config = validation_config())
```

## Arguments

- config:

  A
  [`validation_config()`](https://adetutu-web.github.io/modelgate/reference/validation_config.md);
  uses `leakage_ratio` and `leakage_min_power`.

## Value

A `gate_check`.

## Details

Each column's solo power is compared with the power of `y_pred`, on the
same 0-1 scale: \|2 AUC - 1\| for a binary target, \|r\| for a
continuous one, and the square root of the correlation ratio for a
non-numeric column. A column is flagged (`LEAKAGE_RISK`, blocking) only
when its power reaches both `leakage_min_power` and `leakage_ratio`
times the model's: on a model scoring 0.55, a feature scoring 0.54 is
98% of it and means nothing.

Needs `y_true` and `y_pred`. The task comes from
[`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)'s
`task`, inferred from `y_true` when `"auto"`.

Port of `LeakageCheck` in bdp-model-gate 0.7.0, for binary and
regression targets. Differences: a multiclass target is skipped with a
reason (not yet ported); rows with a missing `y_true` are left out and
counted, where upstream counts them as positives (binary) or returns
`OK` with a model power of NaN (regression); and a model power that is
not finite is skipped rather than reported.

## Examples

``` r
set.seed(1)
y <- rbinom(200, 1, 0.3)
score <- plogis(-1 + 2 * y + rnorm(200))        # a reasonable model's scores
X <- data.frame(age = rnorm(200, 40, 10),
                settled_amount = y * runif(200, 1000, 5000))   # only known after the outcome
report <- run_gate(gate_context(X, y_true = y, y_pred = score), list(target_leakage_check()))
report$results[[1]]$detail
#> [1] "settled_amount alone reaches 1.000 of the target on its own, 116% of the whole model's 0.860 - check it is populated before the outcome is known, and is available at scoring time"
```
