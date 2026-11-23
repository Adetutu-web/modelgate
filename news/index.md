# Changelog

## modelgate 0.0.0.9000

- Framework:
  [`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md),
  [`new_check()`](https://adetutu-web.github.io/modelgate/reference/new_check.md),
  [`run_gate()`](https://adetutu-web.github.io/modelgate/reference/run_gate.md),
  `gate_report`, verdict logic and exit codes, matching bdp-model-gate
  0.7.0.
- First check:
  [`split_overlap_check()`](https://adetutu-web.github.io/modelgate/reference/split_overlap_check.md)
  (category `validation`, blocking).
- Second check:
  [`validation_strategy_check()`](https://adetutu-web.github.io/modelgate/reference/validation_strategy_check.md)
  (category `validation`, blocking), with
  [`compliance_config()`](https://adetutu-web.github.io/modelgate/reference/compliance_config.md)
  for the high-risk use cases. Runs by default and skips with a reason
  when there is no model card.
- Third check:
  [`feature_drift_check()`](https://adetutu-web.github.io/modelgate/reference/feature_drift_check.md)
  (category `validation`, non-blocking): standardised mean shift for
  numeric features, total variation distance for the rest. Runs by
  default. Two deliberate differences from upstream, listed in the
  README.
- Fourth check:
  [`feature_contract_check()`](https://adetutu-web.github.io/modelgate/reference/feature_contract_check.md)
  (category `validation`, blocking): columns missing from `X`, columns
  not seen in training, and the right columns in the wrong order.
  [`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)
  gains `expected_features`. Runs by default.
- Fifth check:
  [`target_leakage_check()`](https://adetutu-web.github.io/modelgate/reference/target_leakage_check.md)
  (category `validation`, blocking): a feature whose solo predictive
  power rivals the model’s. Binary and continuous targets.
  [`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)
  gains `task`. Runs first by default. Deliberate differences from
  upstream are listed in the README.
- Every exported function has a runnable example, and the package has a
  documentation website (pkgdown).
