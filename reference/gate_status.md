# Verdict for a report

`BLOCKED` if any blocking check has a finding, `NEEDS_REVIEW` if only
non-blocking checks do, `PASS` otherwise. `NOT_APPLICABLE` is not a
finding.

## Usage

``` r
gate_status(report)
```

## Arguments

- report:

  A `gate_report`.

## Value

`"PASS"`, `"NEEDS_REVIEW"` or `"BLOCKED"`.

## Examples

``` r
X <- data.frame(age = c(25, 32, 47))
gate_status(run_gate(gate_context(X, X_train = X)))   # the same rows: BLOCKED
#> [1] "BLOCKED"
```
