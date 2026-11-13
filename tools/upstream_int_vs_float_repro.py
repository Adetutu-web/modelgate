"""Repro: bdp-model-gate 0.7.0 SplitOverlapCheck misses identical rows when one
frame stores a column as int64 and the other as float64.

Expected: 5 of 5 validation rows also appear in X_train (100%, SPLIT_OVERLAP_RISK).
Observed on 0.7.0: 0 of 5, flag OK. Cause (likely): rows are matched by
pandas.util.hash_pandas_object, which hashes int64 and float64 differently.
"""
import pandas as pd
from bdp_model_gate import StructuredGateContext
from bdp_model_gate.structured import default_structured_checks

chk = next(c for c in map(lambda c: c() if isinstance(c, type) else c, default_structured_checks())
           if c.name == "split_overlap")
val = pd.DataFrame({"a": [1, 2, 3, 4, 5]})
train = pd.DataFrame({"a": [1.0, 2.0, 3.0, 4.0, 5.0]})
for r in chk.run(StructuredGateContext(X=val, X_train=train)):
    print(r.flag, r.metadata.get("n_overlapping"))
