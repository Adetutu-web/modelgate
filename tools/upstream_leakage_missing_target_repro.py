"""Repro: bdp-model-gate 0.7.0 LeakageCheck misses a leak when y_true has
missing values.

Expected: `paid` is exactly twice the target, so it is flagged LEAKAGE_RISK
(as it is when y_true is complete).
Observed on 0.7.0: regression target -> OK, "no single feature approaches the
model's own predictive power (nan)". Binary target -> the missing labels are
counted as positives (NaN is truthy), so the reported powers shift.
Cause (likely): y_true is used as-is; NaN makes every Pearson r NaN, and NaN
fails both `>=` tests and the `model_power <= 0` guard.
"""
import numpy as np
import pandas as pd
from bdp_model_gate import StructuredGateContext
from bdp_model_gate.structured.validation_checks import LeakageCheck

y = np.arange(0.5, 20.5, 0.5)
y_pred = y + np.tile([1.0, -1.0], 20)
X = pd.DataFrame({"paid": y * 2})
for label, y_true in [("complete y_true", y), ("5 missing", np.where(np.arange(40) < 5, np.nan, y))]:
    ctx = StructuredGateContext(X=X, y_true=y_true, y_pred=y_pred, task="regression")
    for r in LeakageCheck().run(ctx):
        print(f"{label:16s}", r.flag, "|", r.detail[:80])
