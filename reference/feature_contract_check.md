# Are these the columns the model was fitted on, in the order it expects?

Silent column reordering is a classic production failure: a model handed
a positional matrix scores confidently against the wrong features and
nothing raises. A formula-based R model matches columns by name, but
anything given `as.matrix(X)` - glmnet, xgboost, a scoring endpoint -
does not.

## Usage

``` r
feature_contract_check()
```

## Value

A `gate_check`.

## Details

The expected columns come from `expected_features` in the
[`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)
if given, otherwise from the columns of `X_train`. Blocking:
`FEATURE_CONTRACT_RISK` when a column is missing from `X` or was not
seen in training, `FEATURE_ORDER_RISK` when the columns match but their
order does not.

Port of `FeatureContractCheck` in bdp-model-gate 0.7.0. One difference:
upstream can also read the fitted column names from scikit-learn,
LightGBM and XGBoost model objects. R models record their columns in
different ways, so pass `expected_features` when the training frame is
not to hand.

## Examples

``` r
X_val <- data.frame(income = c(30, 42), age = c(25, 32))    # columns swapped
report <- run_gate(gate_context(X_val, expected_features = c("age", "income")),
                   list(feature_contract_check()))
report$results[[1]]$flag
#> [1] "FEATURE_ORDER_RISK"
```
