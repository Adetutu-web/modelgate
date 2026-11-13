"""Generate parity fixtures for split_overlap from the Python reference.

    pip install "bdp-model-gate==0.7.0" pandas numpy
    python tools/make_parity_fixtures.py

Writes tests/testthat/fixtures/split_overlap_parity.json. Re-run, and review the
diff, whenever the pinned upstream version changes. The oracle is not infallible
(see the int-vs-float note in README.md), so treat a disagreement as a question,
not automatically as an R bug.
"""
import inspect
import json
import pathlib

import numpy as np
import pandas as pd
from bdp_model_gate import StructuredGateContext
from bdp_model_gate import __version__ as upstream_version
from bdp_model_gate.config import ValidationConfig
from bdp_model_gate.structured import default_structured_checks

assert upstream_version == "0.7.0", f"fixtures are pinned to 0.7.0, found {upstream_version}"
CHECK = next(
    (c() if inspect.isclass(c) else c).__class__
    for c in default_structured_checks()
    if (c() if inspect.isclass(c) else c).name == "split_overlap"
)

rng = np.random.default_rng(0)


def frame(n):
    return pd.DataFrame(
        {
            "age": np.round(rng.normal(40, 10, n), 2),
            "income": np.round(rng.lognormal(10, 0.5, n), 2),
            "region": rng.choice(["north", "south", "east", "west"], n),
        }
    )


def to_cols(df):
    if df is None:
        return None
    return {c: [None if pd.isna(v) else (v.item() if hasattr(v, "item") else v) for v in df[c]] for c in df.columns}


def expected(val, train, cfg):
    ctx = StructuredGateContext(X=val, X_train=train)
    try:
        results = CHECK(ValidationConfig(**cfg)).run(ctx)
    except Exception:  # the gate turns this into a blocking CHECK_ERROR
        return [{"flag": "CHECK_ERROR", "blocking": True, "metadata": {}}]
    return [{"flag": r.flag, "blocking": bool(r.blocking), "metadata": json.loads(json.dumps(r.metadata, default=float))} for r in results]


cases = []


def add(name, val, train, cfg=None):
    cfg = cfg or {}
    cases.append({"name": name, "X": to_cols(val), "X_train": to_cols(train), "config": cfg,
                  "expected": expected(val, train, cfg)})


val, train = frame(100), frame(200)
add("clean_split", val, train)
add("full_leak", train.head(50).copy(), train)
dup = pd.concat([frame(90), frame(10).iloc[:0]]); dup = pd.concat([dup, dup.iloc[:10]], ignore_index=True)
add("ten_percent_duplicates", dup, train)
add("overlap_exactly_at_threshold", val, pd.concat([train, val.iloc[:1]], ignore_index=True))
add("overlap_just_over_threshold", val, pd.concat([train, val.iloc[:2]], ignore_index=True))
add("no_training_frame", val, None)
add("no_shared_columns", val, train.rename(columns=lambda c: c + "_t"))
add("reversed_rows_reordered_columns", val, val.iloc[::-1][["region", "income", "age"]].reset_index(drop=True))
cat = pd.DataFrame({"a": rng.choice(["p", "q", "r"], 50), "b": rng.choice(["u", "v", "w"], 50)})
add("categorical_only_coincidental_repeats", cat, cat.iloc[:5].copy())
nanv = pd.DataFrame({"x": [1.0, None, 3.0, 4.0], "y": ["a", "b", None, "d"]})
add("missing_values_overlap", nanv, nanv.iloc[[1, 2]].copy())
add("empty_validation", val.iloc[:0], train)
add("custom_loose_threshold", val, pd.concat([train, val.iloc[:30]], ignore_index=True), {"max_split_overlap": 0.5})

out = pathlib.Path(__file__).resolve().parent.parent / "tests/testthat/fixtures/split_overlap_parity.json"
out.write_text(json.dumps({"upstream_version": upstream_version, "cases": cases}, allow_nan=False, indent=1))
print(f"wrote {len(cases)} cases to {out}")
