# Settings for the compliance checks

Defaults mirror `ComplianceConfig` in bdp-model-gate 0.7.0. Only the
part the ported checks use is here so far.

## Usage

``` r
compliance_config(
  high_risk_use_cases = c("pricing", "claims_decisioning", "credit_scoring",
    "underwriting")
)
```

## Arguments

- high_risk_use_cases:

  Use cases that must meet the stricter rules, such as an out-of-time
  validation. Matched as substrings of `model_card$use_case`, ignoring
  case, so `"pricing"` also covers `"motor_pricing_v2"`.

## Value

A list of class `compliance_config`.

## Examples

``` r
churn_is_high_risk <- compliance_config(high_risk_use_cases = c("pricing", "churn"))
card <- list(use_case = "churn_model", validation_strategy = "random_split")
report <- run_gate(gate_context(data.frame(x = 1:3), model_card = card),
                   list(validation_strategy_check(compliance = churn_is_high_risk)))
report$results[[1]]$flag
#> [1] "VALIDATION_STRATEGY_RISK"
```
