# modelgate

Native R port of the Python library
[bdp-model-gate](https://github.com/vanjy-eng/model-gate): run automated
governance checks on a model before it ships and get one verdict a pipeline can
branch on.

| Verdict | Meaning | Exit code |
|---|---|---|
| `PASS` | nothing found | 0 |
| `BLOCKED` | a blocking check found a problem | 1 |
| `NEEDS_REVIEW` | only non-blocking checks found something; a person decides | 2 |

```r
library(modelgate)
ctx <- gate_context(X = X_val, X_train = X_train)
report <- run_gate(ctx)
report                    # prints the verdict and findings
gate_exit_code(report)    # for CI
```

**Status: pre-alpha.** One check is ported (`split_overlap`) plus the framework.
Targets bdp-model-gate **0.7.0**. See the roadmap below.

## How "correct" is defined here

The upstream project exists to avoid one failure: *a gate that returns a
confident, wrong, green number.* So the bar for every check is "a test would
have noticed if this were wrong", not "the tests pass":

1. **Known-answer tests first** - inputs whose answer is derivable on paper,
   asserted exactly (`tests/testthat/test-split-overlap.R`).
2. **Invariance tests** - permute rows, scramble row names, reorder columns.
3. **Every skip path asserted on its reason string.** A check that cannot answer
   returns `NOT_APPLICABLE` *with a reason*, never a plausible number.
4. **Parity with the Python library** (`test-parity.R`) as a second layer, from
   fixtures made by `tools/make_parity_fixtures.py`. The oracle has been wrong
   before, so a disagreement is a question, not automatically an R bug.
5. **Use `run_gate_strict()`** (in `tests/testthat/helper-guard.R`) in tests, not
   `run_gate()`. The gate turns an error inside a check into a blocking
   `CHECK_ERROR` *result*, so `length(results) > 0` passes on a crashed check.

## Deliberate differences from upstream

- Numbers match **by value**: an integer column in one frame and a double column
  in the other still overlap. Upstream 0.7.0 hashes by dtype, so
  `X = data.frame(a = 1:5)` against `X_train` holding `1.0 ... 5.0` reports
  *0 of 5 overlapping* there. That looks like an upstream bug; it should be
  reported with the repro in `tools/` before assuming either way.
- ASCII hyphens instead of em dashes in message text.

## Development

```r
devtools::document(); devtools::test(); devtools::check()
```

Regenerate parity fixtures after changing the pinned upstream version:

```bash
pip install "bdp-model-gate==0.7.0" pandas numpy
python tools/make_parity_fixtures.py
```

## Roadmap (what upstream has; ported = [x])

- [x] framework: context, check, run, verdict, exit codes
- [ ] validation: `split_overlap` [x], `feature_contract`, `target_leakage`, `validation_strategy`, `feature_drift`
- [ ] performance: `performance_thresholds`, `calibration`, `actual_vs_expected`, `risk_discrimination`
- [ ] HTML report
- [ ] fairness (10 checks), compliance (3), comparison (7), security (4)

## Before publishing - decisions that are not mine to make

- Real maintainer email in `DESCRIPTION` (currently a placeholder)
- Copyright holder in `LICENSE` / `LICENSE.md` (you or Bluechip?)
- Tell the upstream maintainer (open an issue on the Python repo, per its
  CONTRIBUTING.md) and agree how he is credited in `DESCRIPTION`
- Check the name is free on CRAN: `available::available("modelgate")`

## Licence and attribution

MIT. Portions derive from bdp-model-gate (c) 2026 Vangelis Oden, MIT; see
`inst/COPYRIGHTS`.
