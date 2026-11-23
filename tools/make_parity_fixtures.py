"""Generate parity fixtures from the Python reference.

    pip install "bdp-model-gate==0.7.0" pandas numpy
    python tools/make_parity_fixtures.py

Writes tests/testthat/fixtures/split_overlap_parity.json,
validation_strategy_parity.json, feature_drift_parity.json and
feature_contract_parity.json. Re-run, and review the diff, whenever the
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


# --------------------------------------------------------------------------
# feature_drift. Its own random stream, so adding cases here never changes the
# fixtures above. Constant training columns use 1.0, the value upstream skips;
# for values like 0.1 its zero-spread test fails (see README), so those are
# covered by known-answer tests in R instead. So is a column holding numbers in
# one frame and text in the other: pandas 2.x looks those levels up by
# position, and upstream's distance comes out wrong (see README).
# --------------------------------------------------------------------------
from bdp_model_gate.structured.validation_checks import FeatureDriftCheck

rng2 = np.random.default_rng(1)
drift_cases = []


def add_drift(name, X, train, cfg=None):
    cfg = cfg or {}
    results = FeatureDriftCheck(ValidationConfig(**cfg)).run(StructuredGateContext(X=X, X_train=train))
    drift_cases.append({
        "name": name, "X": to_cols(X), "X_train": to_cols(train), "config": cfg,
        "expected": [{"flag": r.flag, "blocking": bool(r.blocking), "detail": r.detail,
                      "metadata": json.loads(json.dumps(r.metadata, default=float))} for r in results],
    })


n = 400
base = pd.DataFrame({
    "age": np.round(rng2.normal(40, 10, n), 2),
    "income": np.round(rng2.lognormal(10, 0.5, n), 2),
    "region": rng2.choice(["north", "south", "east", "west"], n),
    "member": rng2.choice([True, False], n),
})
first, second = base.iloc[:200].reset_index(drop=True), base.iloc[200:].reset_index(drop=True)

add_drift("two_halves_of_one_sample", second, first)
add_drift("shifted_numeric", second.assign(age=second["age"] + 5), first)
add_drift("several_drifted_sorted_by_shift",
          second.assign(age=second["age"] + 8, income=second["income"] * 1.5, region="north"), first)
add_drift("categorical_disjoint", pd.DataFrame({"region": ["Kano"] * 100}), pd.DataFrame({"region": ["Lagos"] * 100}))
add_drift("categorical_partial", pd.DataFrame({"c": ["a"] * 30 + ["b"] * 10}), pd.DataFrame({"c": ["a"] * 20 + ["b"] * 20}))
add_drift("boolean_is_categorical", pd.DataFrame({"m": [True] * 35 + [False] * 5}), pd.DataFrame({"m": [True] * 20 + [False] * 20}))
add_drift("constant_one_in_training_skipped", second.assign(flag=2.0), first.assign(flag=1.0))
add_drift("only_feature_constant", pd.DataFrame({"flag": [2.0] * 50}), pd.DataFrame({"flag": [1.0] * 50}))
add_drift("nineteen_rows_not_scored", second.iloc[:19], first.iloc[:19])
add_drift("exactly_twenty_rows_scored", second.iloc[:20].assign(age=second["age"].iloc[:20] + 10), first.iloc[:20])
add_drift("live_too_short", second.iloc[:19], first)
miss = first.copy(); miss.loc[:174, "age"] = np.nan
add_drift("missing_values_dropped_25_left", second, miss)
miss2 = first.iloc[:30].copy(); miss2.loc[:11, "age"] = np.nan
add_drift("missing_values_leave_18", second.iloc[:30], miss2[["age"]])
add_drift("no_training_frame", second, None)
add_drift("empty_training_frame", second, first.iloc[:0])
add_drift("no_shared_columns", second, first.rename(columns=lambda c: c + "_t"))
add_drift("custom_thresholds", second.assign(age=second["age"] + 4, region=["north"] * 120 + list(second["region"].iloc[120:])),
          first, {"drift_threshold": 0.5, "categorical_drift_threshold": 0.3})
ints = pd.DataFrame({"age": rng2.integers(20, 60, 60)})
add_drift("int_train_float_live_is_numeric", pd.DataFrame({"age": ints["age"] + 6.5}), ints)
add_drift("units_do_not_matter", second.assign(income=second["income"] * 1.2 * 1000), first.assign(income=first["income"] * 1000))
add_drift("x_column_order_kept", second[["region", "income", "age"]].assign(age=second["age"] + 9, income=second["income"] * 2), first)

out = pathlib.Path(__file__).resolve().parent.parent / "tests/testthat/fixtures/feature_drift_parity.json"
out.write_text(json.dumps({"upstream_version": upstream_version, "cases": drift_cases},
                          allow_nan=False, indent=1, ensure_ascii=True))
print(f"wrote {len(drift_cases)} cases to {out}")


# --------------------------------------------------------------------------
# feature_contract. Reads only column names, so frames are a few rows each.
# Upstream can also read names from scikit-learn/LightGBM/XGBoost model
# objects; the R port does not (see README), so no case passes a model.
# --------------------------------------------------------------------------
from bdp_model_gate.structured.validation_checks import FeatureContractCheck

contract_cases = []


def cols(*names):
    return pd.DataFrame({c: [1.0, 2.0, 3.0] for c in names})


def add_contract(name, X, X_train=None, expected_features=None):
    kwargs = {"X": X, "X_train": X_train}
    if expected_features is not None:
        kwargs["expected_features"] = expected_features
    results = FeatureContractCheck().run(StructuredGateContext(**kwargs))
    contract_cases.append({
        "name": name, "X": to_cols(X), "X_train": to_cols(X_train),
        "expected_features": expected_features,
        "expected": [{"flag": r.flag, "blocking": bool(r.blocking), "detail": r.detail,
                      "metadata": r.metadata} for r in results],
    })


add_contract("match_in_order", cols("age", "income", "tenure"), expected_features=["age", "income", "tenure"])
add_contract("reordered", cols("tenure", "income", "age"), expected_features=["age", "income", "tenure"])
add_contract("one_renamed", cols("applicant_age", "income", "tenure"), expected_features=["age", "income", "tenure"])
add_contract("only_missing", cols("age"), expected_features=["age", "income", "tenure"])
add_contract("only_unexpected", cols("age", "income", "tenure", "postcode"), expected_features=["age", "income", "tenure"])
add_contract("missing_and_reordered_reports_the_set_only", cols("tenure", "age"), expected_features=["age", "income", "tenure"])
add_contract("several_missing_kept_in_expected_order", cols("z"), expected_features=["c", "a", "b"])
add_contract("x_train_fallback_match", cols("a", "b"), X_train=cols("a", "b"))
add_contract("x_train_fallback_reordered", cols("b", "a"), X_train=cols("a", "b"))
add_contract("x_train_fallback_mismatch", cols("a", "c"), X_train=cols("a", "b"))
add_contract("expected_features_beat_x_train", cols("a", "b"), X_train=cols("b", "a"), expected_features=["a", "b"])
add_contract("empty_expected_list", cols("a", "b"), expected_features=[])
add_contract("zero_row_x_train_is_not_used", cols("a", "b"), X_train=cols("a", "b").iloc[:0])
add_contract("nothing_to_compare_with", cols("a", "b"))
add_contract("single_feature", cols("only"), expected_features=["only"])
add_contract("swap_in_the_middle", cols("a", "c", "b", "d"), expected_features=["a", "b", "c", "d"])

out = pathlib.Path(__file__).resolve().parent.parent / "tests/testthat/fixtures/feature_contract_parity.json"
out.write_text(json.dumps({"upstream_version": upstream_version, "cases": contract_cases},
                          allow_nan=False, indent=1, ensure_ascii=True))
print(f"wrote {len(contract_cases)} cases to {out}")
