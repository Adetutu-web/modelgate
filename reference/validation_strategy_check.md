# Was the holdout separated in time, or at random?

A random split asks whether the model can predict a row it has not seen.
An out-of-time split asks whether it can predict *next period*, which is
what a deployed model will be asked to do. Seasonality, inflation and
portfolio mix all leak backwards through a random split.

## Usage

``` r
validation_strategy_check(
  config = validation_config(),
  compliance = compliance_config()
)
```

## Arguments

- config:

  A
  [`validation_config()`](https://adetutu-web.github.io/modelgate/reference/validation_config.md).

- compliance:

  A
  [`compliance_config()`](https://adetutu-web.github.io/modelgate/reference/compliance_config.md).

## Value

A `gate_check`.

## Details

So `model_card$validation_strategy` is required, must be one of
`accepted_validation_strategies`, and for a high-risk use case (any of
[`compliance_config()`](https://adetutu-web.github.io/modelgate/reference/compliance_config.md)'s
`high_risk_use_cases` appearing in `model_card$use_case`) must be out of
time. Blocking.

This is the one validation check that cannot be verified from the data.
It records a claim, which is what a model card is for. Port of
`ValidationStrategyCheck` in bdp-model-gate 0.7.0.

## Examples

``` r
card <- list(use_case = "credit_scoring", validation_strategy = "random_split")
report <- run_gate(gate_context(data.frame(x = 1:3), model_card = card),
                   list(validation_strategy_check()))
report$results[[1]]$detail
#> [1] "credit_scoring is high-risk and was validated with a 'random_split' split - a random split cannot tell you whether the model holds up on next period's business, which is what it will be applied to"
```
