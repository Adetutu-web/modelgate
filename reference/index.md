# Package index

## Running the gate

Build a context, run the checks, and read the verdict.

- [`gate_context()`](https://adetutu-web.github.io/modelgate/reference/gate_context.md)
  : Everything a check may look at
- [`run_gate()`](https://adetutu-web.github.io/modelgate/reference/run_gate.md)
  : Run a set of checks and collect the verdict
- [`gate_status()`](https://adetutu-web.github.io/modelgate/reference/gate_status.md)
  : Verdict for a report
- [`gate_exit_code()`](https://adetutu-web.github.io/modelgate/reference/gate_exit_code.md)
  : Process exit code for a report
- [`default_checks()`](https://adetutu-web.github.io/modelgate/reference/default_checks.md)
  : The checks run by default

## Validation checks

Is the evaluation itself sound? These run first and block.

- [`target_leakage_check()`](https://adetutu-web.github.io/modelgate/reference/target_leakage_check.md)
  : Does a single column do what the whole model does?
- [`split_overlap_check()`](https://adetutu-web.github.io/modelgate/reference/split_overlap_check.md)
  : Has the model already seen the rows it is graded on?
- [`validation_strategy_check()`](https://adetutu-web.github.io/modelgate/reference/validation_strategy_check.md)
  : Was the holdout separated in time, or at random?
- [`feature_contract_check()`](https://adetutu-web.github.io/modelgate/reference/feature_contract_check.md)
  : Are these the columns the model was fitted on, in the order it
  expects?
- [`feature_drift_check()`](https://adetutu-web.github.io/modelgate/reference/feature_drift_check.md)
  : Does the validation set still look like the training set?

## Settings

- [`validation_config()`](https://adetutu-web.github.io/modelgate/reference/validation_config.md)
  : Thresholds for the validation checks
- [`compliance_config()`](https://adetutu-web.github.io/modelgate/reference/compliance_config.md)
  : Settings for the compliance checks

## Writing your own check

- [`new_check()`](https://adetutu-web.github.io/modelgate/reference/new_check.md)
  : Define a check
- [`check_result()`](https://adetutu-web.github.io/modelgate/reference/check_result.md)
  : The outcome of one check
