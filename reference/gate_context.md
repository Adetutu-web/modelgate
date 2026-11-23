# Everything a check may look at

Everything a check may look at

## Usage

``` r
gate_context(
  X,
  y_true = NULL,
  y_pred = NULL,
  X_train = NULL,
  protected_df = NULL,
  model_card = NULL,
  expected_features = NULL,
  task = "auto"
)
```

## Arguments

- X:

  data.frame of validation features.

- y_true, y_pred:

  Optional vectors with one element per row of `X`.

- X_train:

  Optional data.frame of training features.

- protected_df:

  Optional data.frame of protected attributes, one row per row of `X`.
  Used only to measure fairness, never to fit.

- model_card:

  Optional named list describing the model.

- expected_features:

  Optional character vector: the columns the model was fitted on, in the
  order it expects them. Used by
  [`feature_contract_check()`](https://adetutu-web.github.io/modelgate/reference/feature_contract_check.md);
  without it that check falls back to the columns of `X_train`.

- task:

  What the model predicts: `"binary"`, `"multiclass"`, `"regression"`,
  or `"auto"` (the default) to infer it from `y_true`. Inference cannot
  tell a count target such as claims frequency from a set of classes, so
  state it for anything you gate on.

## Value

An object of class `gate_context`.

## Examples

``` r
# A validation set, the training set and a short model card.
X_train <- data.frame(age = c(25, 32, 47, 51, 38, 29), income = c(30, 42, 55, 61, 47, 33))
X_val <- data.frame(age = c(41, 36, 58), income = c(50, 44, 66))
ctx <- gate_context(X_val, X_train = X_train,
                    model_card = list(use_case = "pricing", validation_strategy = "out_of_time"))
names(ctx)
#> [1] "X"                 "y_true"            "y_pred"           
#> [4] "X_train"           "protected_df"      "model_card"       
#> [7] "expected_features" "task"             
```
