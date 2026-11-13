# Known answers for validation_strategy, derived from the rules rather than from
# the Python library (parity with it is a second layer, in test-parity.R).
# The check reads only the model card, so one X serves every test.
X <- data.frame(a = c(1, 2, 3))
run_card <- function(card, config = validation_config(), compliance = compliance_config()) {
  rep <- run_gate_strict(gate_context(X, model_card = card),
                         list(validation_strategy_check(config, compliance)))
  expect_length(rep$results, 1L)
  rep$results[[1]]
}

oot <- c("out_of_time", "temporal", "forward_chaining", "walk_forward")
random <- c("random_split", "stratified_split", "cross_validation", "grouped_split")
high_risk <- c("pricing", "claims_decisioning", "credit_scoring", "underwriting")

test_that("a random split is flagged for a high-risk use case", {
  r <- run_card(list(use_case = "credit_scoring", validation_strategy = "random_split"))
  expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
  expect_true(r$blocking)
  expect_identical(r$metadata$check, "out_of_time_for_high_risk")
  expect_true(r$metadata$is_high_risk)
  expect_false(r$metadata$is_out_of_time)
  expect_identical(r$detail, paste0(
    "credit_scoring is high-risk and was validated with a 'random_split' split - a random ",
    "split cannot tell you whether the model holds up on next period's business, which ",
    "is what it will be applied to"))
})

test_that("every out-of-time strategy passes for every high-risk use case", {
  for (s in oot) for (u in high_risk) {
    r <- run_card(list(use_case = u, validation_strategy = s))
    expect_identical(r$flag, "OK", label = paste(u, s))
    expect_true(r$metadata$is_out_of_time)
    expect_identical(r$detail, paste0("validated with a '", s, "' split (out-of-time)"))
  }
})

test_that("every other accepted strategy is flagged for every high-risk use case", {
  for (s in random) for (u in high_risk) {
    r <- run_card(list(use_case = u, validation_strategy = s))
    expect_identical(r$flag, "VALIDATION_STRATEGY_RISK", label = paste(u, s))
  }
})

test_that("a random split is fine when the use case is not high-risk, or not stated", {
  for (card in list(list(use_case = "marketing_propensity", validation_strategy = "random_split"),
                    list(validation_strategy = "random_split"))) {
    r <- run_card(card)
    expect_identical(r$flag, "OK")
    expect_false(r$metadata$is_high_risk)
    expect_identical(r$detail, "validated with a 'random_split' split")
  }
})

test_that("a missing strategy is flagged and lists every accepted option", {
  for (s in list(NULL, NA, NA_character_, "", "   ", character(0))) {
    card <- list(use_case = "pricing")
    card["validation_strategy"] <- list(s)
    r <- run_card(card)
    expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
    expect_identical(r$metadata$check, "declared")
    expect_true(r$metadata$is_high_risk)
    for (opt in c(oot, random)) expect_match(r$detail, opt, fixed = TRUE)
  }
})

test_that("an unrecognised strategy is refused rather than accepted", {
  r <- run_card(list(use_case = "credit_scoring", validation_strategy = "holdout"))
  expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
  expect_identical(r$metadata$check, "recognised")
  expect_identical(r$metadata$declared, "holdout")
  expect_match(r$detail, "model_card.validation_strategy='holdout' is not a recognised", fixed = TRUE)
})

test_that("strategy and use case are matched ignoring case and surrounding spaces", {
  r <- run_card(list(use_case = "PRICING", validation_strategy = "  Out_Of_Time "))
  expect_identical(r$flag, "OK")
  expect_identical(r$metadata$declared, "out_of_time")
  expect_true(r$metadata$is_high_risk)
})

test_that("a high-risk use case is recognised inside a longer name", {
  r <- run_card(list(use_case = "motor_pricing_v2", validation_strategy = "random_split"))
  expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
  expect_match(r$detail, "^motor_pricing_v2 is high-risk")
})

test_that("the out-of-time requirement can be switched off", {
  r <- run_card(list(use_case = "credit_scoring", validation_strategy = "random_split"),
                config = validation_config(require_out_of_time_for_high_risk = FALSE))
  expect_identical(r$flag, "OK")
  expect_true(r$metadata$is_high_risk)
})

test_that("the high-risk list and the accepted strategies are configurable", {
  r <- run_card(list(use_case = "churn_model", validation_strategy = "random_split"),
                compliance = compliance_config(high_risk_use_cases = "churn"))
  expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
  r <- run_card(list(use_case = "credit_scoring", validation_strategy = "random_split"),
                compliance = compliance_config(high_risk_use_cases = character(0)))
  expect_identical(r$flag, "OK")
  r <- run_card(list(use_case = "pricing", validation_strategy = "holdout"),
                config = validation_config(accepted_validation_strategies = c("holdout", "out_of_time")))
  expect_identical(r$metadata$check, "out_of_time_for_high_risk")
  expect_identical(r$flag, "VALIDATION_STRATEGY_RISK")
})

test_that("no model card skips with a reason, never a verdict", {
  for (card in list(NULL, list())) {
    r <- run_card(card)
    expect_identical(r$flag, "NOT_APPLICABLE")
    expect_match(r$detail, "no model_card supplied", fixed = TRUE)
  }
})

test_that("the data is not read: the same card gives the same result for any X", {
  card <- list(use_case = "pricing", validation_strategy = "random_split")
  a <- run_gate_strict(gate_context(X, model_card = card), list(validation_strategy_check()))
  other <- data.frame(z = letters[1:5], w = 5:1)[sample(5), ]
  b <- run_gate_strict(gate_context(other, model_card = card), list(validation_strategy_check()))
  expect_identical(a$results[[1]][c("flag", "detail", "metadata")],
                   b$results[[1]][c("flag", "detail", "metadata")])
})

test_that("it runs by default and a missing card does not change the verdict", {
  names <- vapply(default_checks(), function(chk) chk$name, character(1))
  expect_true("validation_strategy" %in% names)
  rep <- run_gate_strict(gate_context(X), default_checks())
  expect_identical(gate_status(rep), "PASS")
})

test_that("bad settings are refused loudly", {
  expect_error(validation_config(require_out_of_time_for_high_risk = NA), "TRUE or FALSE")
  expect_error(validation_config(accepted_validation_strategies = 1), "character vector")
  expect_error(validation_config(out_of_time_strategies = c("temporal", NA)), "no missing")
  expect_error(compliance_config(high_risk_use_cases = NULL), "character vector")
})
