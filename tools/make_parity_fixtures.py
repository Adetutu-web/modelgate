"""Generate parity fixtures from the Python reference.

    pip install "bdp-model-gate==0.7.0" pandas numpy
    python tools/make_parity_fixtures.py

Writes tests/testthat/fixtures/split_overlap_parity.json and
validation_strategy_parity.json. Re-run, and review the diff, whenever the
pinned upstream version changes. The oracle is not infallible
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


# --------------------------------------------------------------------------
# validation_strategy: reads only the model card, so every case shares one X.
# Expected results include `detail`, compared after upstream's em dashes are
# turned into the ASCII hyphens the R port uses.
# --------------------------------------------------------------------------
from bdp_model_gate.config import ComplianceConfig
from bdp_model_gate.structured.validation_checks import ValidationStrategyCheck

X_ANY = pd.DataFrame({"a": [1.0, 2.0, 3.0]})
strategy_cases = []


def add_strategy(name, card, cfg=None, compliance=None):
    cfg, compliance = cfg or {}, compliance or {}
    check = ValidationStrategyCheck(ValidationConfig(**cfg), ComplianceConfig(**compliance))
    results = check.run(StructuredGateContext(X=X_ANY, model_card=card))
    strategy_cases.append({
        "name": name, "model_card": card, "config": cfg, "compliance": compliance,
        "expected": [{"flag": r.flag, "blocking": bool(r.blocking), "detail": r.detail,
                      "metadata": r.metadata} for r in results],
    })


add_strategy("no_model_card", None)
add_strategy("empty_model_card", {})
add_strategy("missing_strategy_high_risk", {"use_case": "credit_scoring"})
add_strategy("missing_strategy_low_risk", {"use_case": "marketing_propensity"})
add_strategy("null_strategy", {"use_case": "pricing", "validation_strategy": None})
add_strategy("whitespace_strategy", {"use_case": "pricing", "validation_strategy": "   "})
add_strategy("unrecognised_holdout", {"use_case": "credit_scoring", "validation_strategy": "holdout"})
add_strategy("random_split_high_risk", {"use_case": "credit_scoring", "validation_strategy": "random_split"})
add_strategy("out_of_time_high_risk", {"use_case": "credit_scoring", "validation_strategy": "out_of_time"})
add_strategy("temporal_underwriting", {"use_case": "underwriting", "validation_strategy": "temporal"})
add_strategy("cross_validation_claims", {"use_case": "claims_decisioning", "validation_strategy": "cross_validation"})
add_strategy("random_split_low_risk", {"use_case": "marketing_propensity", "validation_strategy": "random_split"})
add_strategy("no_use_case", {"validation_strategy": "random_split"})
add_strategy("case_and_whitespace_normalised", {"use_case": "PRICING", "validation_strategy": "  Out_Of_Time "})
add_strategy("use_case_substring", {"use_case": "motor_pricing_v2", "validation_strategy": "stratified_split"})
add_strategy("use_case_kept_unstripped", {"use_case": " Credit_Scoring ", "validation_strategy": "grouped_split"})
add_strategy("requirement_switched_off", {"use_case": "credit_scoring", "validation_strategy": "random_split"},
             cfg={"require_out_of_time_for_high_risk": False})
add_strategy("custom_high_risk_list", {"use_case": "churn_model", "validation_strategy": "random_split"},
             compliance={"high_risk_use_cases": ["churn"]})
add_strategy("custom_accepted_list", {"use_case": "pricing", "validation_strategy": "holdout"},
             cfg={"accepted_validation_strategies": ["holdout", "out_of_time"], "out_of_time_strategies": ["out_of_time"]})
add_strategy("extra_fields_ignored", {"use_case": "pricing", "validation_strategy": "walk_forward",
                                      "owner": "risk team", "version": 3})

out = pathlib.Path(__file__).resolve().parent.parent / "tests/testthat/fixtures/validation_strategy_parity.json"
out.write_text(json.dumps({"upstream_version": upstream_version, "cases": strategy_cases},
                          allow_nan=False, indent=1, ensure_ascii=True))
print(f"wrote {len(strategy_cases)} cases to {out}")
