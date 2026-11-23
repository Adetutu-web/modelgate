# Run a set of checks and collect the verdict

An error inside a check does not stop the gate: it becomes a blocking
`CHECK_ERROR` result, as in bdp-model-gate. That is right in production
and is also why tests must assert values rather than that a check
"ran" - see the `run_gate_strict()` helper in
`tests/testthat/helper-guard.R`.

## Usage

``` r
run_gate(context, checks = default_checks())
```

## Arguments

- context:

  A
  [`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md).

- checks:

  List of
  [`new_check()`](https://adetutu-web.github.io/modelgate/reference/new_check.md)
  objects. Defaults to
  [`default_checks()`](https://adetutu-web.github.io/modelgate/reference/default_checks.md).

## Value

An object of class `gate_report`.

## Details

A check that returns nothing, or anything other than a list of
[`check_result()`](https://adetutu-web.github.io/modelgate/reference/check_result.md)s,
is also a `CHECK_ERROR`: a check that says nothing must not read as a
check that found nothing.

## Examples

``` r
set.seed(1)
X_train <- data.frame(age = rnorm(200, 40, 10), income = rlnorm(200, 10, 0.5))
X_val <- data.frame(age = rnorm(100, 40, 10), income = rlnorm(100, 10, 0.5))
report <- run_gate(gate_context(X_val, X_train = X_train,
                                model_card = list(use_case = "marketing",
                                                  validation_strategy = "random_split")))
report
#> <gate_report> status: PASS (0 finding(s) in 6 result(s))
as.data.frame(report)[, c("check_name", "flag")]
#>            check_name           flag
#> 1      target_leakage NOT_APPLICABLE
#> 2       split_overlap             OK
#> 3       split_overlap             OK
#> 4 validation_strategy             OK
#> 5    feature_contract             OK
#> 6       feature_drift             OK
```
