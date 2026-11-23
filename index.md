# modelgate

Native R port of the Python library
[bdp-model-gate](https://github.com/vanjy-eng/model-gate), which is its
reference implementation: run automated governance checks on a model
before it ships and get one verdict a pipeline can branch on.

| Verdict | Meaning | Exit code |
|----|----|----|
| `PASS` | nothing found | 0 |
| `BLOCKED` | a blocking check found a problem | 1 |
| `NEEDS_REVIEW` | only non-blocking checks found something; a person decides | 2 |

``` r

library(modelgate)
ctx <- gate_context(X = X_val, X_train = X_train)
report <- run_gate(ctx)
report                    # prints the verdict and findings
gate_exit_code(report)    # for CI
```

**Status: pre-alpha.** All five validation checks are ported
(`target_leakage`, `split_overlap`, `validation_strategy`,
`feature_contract`, `feature_drift`) plus the framework. Targets
bdp-model-gate **0.7.0**. See the roadmap below.

Releases take the version number of the bdp-model-gate release whose
behaviour they match, so the first release will be 0.7.0.

## How “correct” is defined here

The upstream project exists to avoid one failure: *a gate that returns a
confident, wrong, green number.* So the bar for every check is “a test
would have noticed if this were wrong”, not “the tests pass”:

1.  **Known-answer tests first** - inputs whose answer is derivable on
    paper, asserted exactly (`tests/testthat/test-split-overlap.R`).
2.  **Invariance tests** - permute rows, scramble row names, reorder
    columns.
3.  **Every skip path asserted on its reason string.** A check that
    cannot answer returns `NOT_APPLICABLE` *with a reason*, never a
    plausible number.
4.  **Parity with the Python library** (`test-parity.R`) as a second
    layer, from fixtures made by `tools/make_parity_fixtures.py`. The
    oracle has been wrong before, so a disagreement is a question, not
    automatically an R bug.
5.  **Use `run_gate_strict()`** (in `tests/testthat/helper-guard.R`) in
    tests, not
    [`run_gate()`](https://adetutu-web.github.io/modelgate/reference/run_gate.md).
    The gate turns an error inside a check into a blocking `CHECK_ERROR`
    *result*, so `length(results) > 0` passes on a crashed check.

## Deliberate differences from upstream

- Numbers match **by value**: an integer column in one frame and a
  double column in the other still overlap. Upstream 0.7.0 hashes by
  dtype, so `X = data.frame(a = 1:5)` against `X_train` holding
  `1.0 ... 5.0` reports *0 of 5 overlapping* there. Reported upstream as
  [vanjy-eng/model-gate#31](https://github.com/vanjy-eng/model-gate/issues/31);
  the repro is in `tools/`.
- `feature_drift` treats a training column whose values are all
  identical as constant and skips it. Upstream tests the standard
  deviation against zero, which rounding defeats for values such as 0.1:
  a 0.001 change then reports a standardised mean shift of about 7e13.
  Repro in `tools/upstream_constant_drift_repro.py`.
- `feature_drift` matches category levels by label. When a column holds
  numbers in one frame and text in the other, upstream (on pandas 2.x)
  looks levels up by position and reports a wrong distance, such as 0.75
  where it should be 1. Repro in
  `tools/upstream_mixed_type_tvd_repro.py`.
- `feature_contract` takes the expected columns from
  `expected_features`, then from `X_train`. Upstream can also read them
  from scikit-learn, LightGBM and XGBoost model objects; R models record
  their columns in different ways, so pass `expected_features` when the
  training frame is not to hand.
- `target_leakage` covers binary and continuous targets; a multiclass
  target is skipped with a reason for now. Rows with a missing `y_true`
  are left out and counted in the message. Upstream counts them as
  positives on a binary target, and on a continuous one returns `OK`
  with a model power of NaN, missing the leak. Repro in
  `tools/upstream_leakage_missing_target_repro.py`.
- ASCII hyphens instead of em dashes in message text.

## Development

``` r

devtools::document(); devtools::test(); devtools::check()
```

Regenerate parity fixtures after changing the pinned upstream version:

``` bash
pip install "bdp-model-gate==0.7.0" pandas numpy
python tools/make_parity_fixtures.py
```

## Roadmap (what upstream has; ported = \[x\])

framework: context, check, run, verdict, exit codes

validation: `target_leakage`, `split_overlap`, `validation_strategy`,
`feature_contract`, `feature_drift` (multiclass leakage still to come)

performance: `performance_thresholds`, `calibration`,
`actual_vs_expected`, `risk_discrimination`

HTML report

fairness (10 checks), compliance (3), comparison (7), security (4)

## Licence and attribution

MIT, copyright Vangelis Oden, author of bdp-model-gate. Check logic,
thresholds, verdict semantics and test cases derive from bdp-model-gate;
see `LICENSE`, `inst/COPYRIGHTS` and the authors listed in
`DESCRIPTION`.
