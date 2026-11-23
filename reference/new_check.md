# Define a check

A check is a name, a category, a `blocking` flag and a function that
takes a
[`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)
and returns a non-empty list of
[`check_result()`](https://adetutu-web.github.io/modelgate/reference/check_result.md)s.

## Usage

``` r
new_check(name, category, blocking, run)
```

## Arguments

- name:

  Snake_case name shown in the report.

- category:

  One of validation, fairness, performance, compliance, security,
  comparison.

- blocking:

  `TRUE` or `FALSE`.

- run:

  Function of one argument (the context).

## Value

An object of class `gate_check`.

## Details

`blocking = TRUE` means a finding stops the deploy; `FALSE` routes it to
a human as `NEEDS_REVIEW`. That is a judgement, not a default.

## Examples

``` r
# A check of your own: no feature may be entirely missing.
no_empty_columns <- new_check("no_empty_columns", "validation", TRUE, function(context) {
  empty <- names(context$X)[vapply(context$X, function(col) all(is.na(col)), logical(1))]
  found <- length(empty) > 0
  list(check_result("no_empty_columns", "validation",
                    if (found) "EMPTY_COLUMN_RISK" else "OK",
                    detail = paste("empty columns:", if (found) toString(empty) else "none"),
                    blocking = TRUE))
})
report <- run_gate(gate_context(data.frame(a = 1:3, b = NA)), list(no_empty_columns))
gate_status(report)
#> [1] "BLOCKED"
```
