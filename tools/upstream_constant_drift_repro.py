"""Repro: bdp-model-gate 0.7.0 FeatureDriftCheck reports an enormous drift for a
training column that is constant, when the constant is not exactly
representable in binary (0.1, 0.7, ...).

Expected: the column is constant in training, so it is skipped ("a shift has no
scale to be measured against"), as it is for 1.0.
Observed on 0.7.0: DRIFT_RISK with a standardised mean shift of ~7e13.
Cause (likely): `train.std()` returns ~1e-17 rather than 0 because the mean is
not exact, so the `spread == 0` test does not fire.
"""
import pandas as pd
from bdp_model_gate import StructuredGateContext
from bdp_model_gate.structured.validation_checks import FeatureDriftCheck

for value in (1.0, 0.1):
    X_train = pd.DataFrame({"x": [value] * 20})
    X_val = pd.DataFrame({"x": [value + 0.001] * 20})
    for r in FeatureDriftCheck().run(StructuredGateContext(X=X_val, X_train=X_train)):
        print(value, r.flag, "|", r.detail)
