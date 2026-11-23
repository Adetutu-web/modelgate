# Has the model already seen the rows it is graded on?

Reports two findings with different causes and fixes: validation rows
that also appear in `X_train` (a broken split), and exact duplicates
within `X` (which weight one observation twice in every metric).
Blocking.

## Usage

``` r
split_overlap_check(config = validation_config())
```

## Arguments

- config:

  A
  [`validation_config()`](https://adetutu-web.github.io/modelgate/reference/validation_config.md).

## Value

A `gate_check`.

## Details

Matching is by row content, over the columns `X` and `X_train` share.
Port of `SplitOverlapCheck` in bdp-model-gate 0.7.0. One deliberate
difference: numbers match by value, so an integer column in one frame
and a double column in the other do not hide an overlap.

## Examples

``` r
X_train <- data.frame(age = c(25, 32, 47, 51), region = c("n", "s", "e", "w"))
X_val <- X_train[1:2, ]            # validation rows the model has already seen
report <- run_gate(gate_context(X_val, X_train = X_train), list(split_overlap_check()))
as.data.frame(report)[, c("flag", "detail")]
#>                 flag
#> 1                 OK
#> 2 SPLIT_OVERLAP_RISK
#>                                                                                                                                detail
#> 1 0 duplicate row(s) within the validation set (0.0%, max 5%) - duplicates weight the same observation more than once in every metric
#> 2                                    2 of 2 validation rows (100.0%, max 1%) also appear in X_train, compared over 2 shared column(s)
```
