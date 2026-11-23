# The checks run by default

The checks run by default

## Usage

``` r
default_checks()
```

## Value

A list of `gate_check` objects.

## Examples

``` r
vapply(default_checks(), function(chk) chk$name, character(1))
#> [1] "target_leakage"      "split_overlap"       "validation_strategy"
#> [4] "feature_contract"    "feature_drift"      
```
