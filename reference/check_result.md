# The outcome of one check

`flag` is `"OK"`, `"NOT_APPLICABLE"` (skipped, with the reason in
`detail`), `"CHECK_ERROR"` (the check raised an error), or a
check-specific risk string such as `"SPLIT_OVERLAP_RISK"`. Anything
other than the first two counts as a finding.

## Usage

``` r
check_result(
  check_name,
  category,
  flag,
  detail = "",
  blocking = TRUE,
  metadata = list(),
  duration_ms = NA_real_
)
```

## Arguments

- check_name, category, flag, detail:

  Strings.

- blocking:

  `TRUE` if a finding must stop the deploy, `FALSE` if it only routes to
  human review.

- metadata:

  Named list of values behind the finding.

- duration_ms:

  Filled in by
  [`run_gate()`](https://adetutu-web.github.io/modelgate/reference/run_gate.md).

## Value

An object of class `check_result`.

## Examples

``` r
r <- check_result("my_check", "validation", "OK", detail = "nothing to report")
r$flag
#> [1] "OK"
```
