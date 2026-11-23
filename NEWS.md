# modelgate 0.0.0.9000

* Framework: `gate_context()`, `new_check()`, `run_gate()`, `gate_report`,
  verdict logic and exit codes, matching bdp-model-gate 0.7.0.
* First check: `split_overlap_check()` (category `validation`, blocking).
* Second check: `validation_strategy_check()` (category `validation`, blocking),
  with `compliance_config()` for the high-risk use cases. Runs by default and
  skips with a reason when there is no model card.
* Third check: `feature_drift_check()` (category `validation`, non-blocking):
  standardised mean shift for numeric features, total variation distance for
  the rest. Runs by default. Two deliberate differences from upstream, listed
  in the README.
* Fourth check: `feature_contract_check()` (category `validation`, blocking):
  columns missing from `X`, columns not seen in training, and the right columns
  in the wrong order. `gate_context()` gains `expected_features`. Runs by default.
* Fifth check: `target_leakage_check()` (category `validation`, blocking): a
  feature whose solo predictive power rivals the model's. Binary and continuous
  targets. `gate_context()` gains `task`. Runs first by default. Deliberate
  differences from upstream are listed in the README.
