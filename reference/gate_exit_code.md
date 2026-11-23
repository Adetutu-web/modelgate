# Process exit code for a report

0 = PASS, 1 = BLOCKED, 2 = NEEDS_REVIEW, as in the Python CLI, so a
pipeline can auto-deploy, hard-stop, or hand to a human.

## Usage

``` r
gate_exit_code(report)
```

## Arguments

- report:

  A `gate_report`.

## Value

An integer.

## Examples

``` r
X <- data.frame(age = c(25, 32, 47))
report <- run_gate(gate_context(X, X_train = X))
gate_exit_code(report)
#> [1] 1
# In a CI script, end with: quit(status = gate_exit_code(report))
```
