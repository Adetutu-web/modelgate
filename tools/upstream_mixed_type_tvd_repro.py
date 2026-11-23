"""Repro: bdp-model-gate 0.7.0 FeatureDriftCheck reports the wrong total
variation distance when a column holds numbers in one frame and text in the
other.

Expected: the levels 1, 2 and "9", "8" have nothing in common, so the distance
is 1.0.
Observed on 0.7.0 with pandas 2.x: 0.750, with a pandas FutureWarning.
Cause (likely): `live_share.get(level, 0.0)` with an integer `level` on a
string-indexed Series falls back to *positional* lookup in pandas 2.x, so
shares are read from the wrong rows. pandas 3 treats the key as a label, so the
reported number also depends on the pandas version.
"""
import pandas as pd
from bdp_model_gate import StructuredGateContext
from bdp_model_gate.structured.validation_checks import FeatureDriftCheck

X_train = pd.DataFrame({"code": [1, 2] * 15})
X_val = pd.DataFrame({"code": ["9", "8"] * 15})
print("pandas", pd.__version__)
for r in FeatureDriftCheck().run(StructuredGateContext(X=X_val, X_train=X_train)):
    print(r.flag, "|", r.detail)
