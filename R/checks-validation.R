# One string per row, built from the row's *content* so a reset row name cannot
# hide an overlap and a shuffled frame cannot invent one. Numbers are compared
# exactly (17 significant digits) and by value, so integer 1L and double 1.0
# match; strings never match numbers. Missing values match each other.
row_keys <- function(df) {
  if (ncol(df) == 0L) return(rep("", nrow(df)))
  parts <- lapply(df, function(col) {
    out <- if (is.numeric(col)) {
      paste0("n:", sprintf("%.17g", col))
    } else if (is.logical(col)) {
      paste0("b:", as.character(col))
    } else {
      paste0("s:", as.character(col))
    }
    out[is.na(col)] <- "<NA>"
    out
  })
  do.call(paste, c(parts, sep = "\037"))
}

pct <- function(x, digits) sprintf(paste0("%.", digits, "f%%"), 100 * x)

#' Has the model already seen the rows it is graded on?
#'
#' Reports two findings with different causes and fixes: validation rows that
#' also appear in `X_train` (a broken split), and exact duplicates within `X`
#' (which weight one observation twice in every metric). Blocking.
#'
#' Matching is by row content, over the columns `X` and `X_train` share.
#' Port of `SplitOverlapCheck` in bdp-model-gate 0.7.0. One deliberate
#' difference: numbers match by value, so an integer column in one frame and a
#' double column in the other do not hide an overlap.
#'
#' @param config A [validation_config()].
#' @return A `gate_check`.
#' @examples
#' X_train <- data.frame(age = c(25, 32, 47, 51), region = c("n", "s", "e", "w"))
#' X_val <- X_train[1:2, ]            # validation rows the model has already seen
#' report <- run_gate(gate_context(X_val, X_train = X_train), list(split_overlap_check()))
#' as.data.frame(report)[, c("flag", "detail")]
#' @export
split_overlap_check <- function(config = validation_config()) {
  chk <- new_check("split_overlap", "validation", TRUE, function(context) {
    validation <- context$X
    n <- nrow(validation)
    if (n == 0L) {
      stop("validation set `X` has no rows, so overlap fractions are undefined", call. = FALSE)
    }

    val_keys <- row_keys(validation)
    n_dup <- sum(duplicated(val_keys))
    dup_fraction <- n_dup / n
    results <- list(check_result(
      "split_overlap", "validation",
      if (dup_fraction <= config$max_duplicate_fraction) "OK" else "DUPLICATE_ROWS_RISK",
      detail = sprintf(
        paste0("%d duplicate row(s) within the validation set (%s, max %s) - ",
               "duplicates weight the same observation more than once in every metric"),
        n_dup, pct(dup_fraction, 1), pct(config$max_duplicate_fraction, 0)),
      blocking = TRUE,
      metadata = list(check = "duplicates_within_validation",
                      n_duplicates = n_dup,
                      duplicate_fraction = round(dup_fraction, 4),
                      threshold = config$max_duplicate_fraction)
    ))

    train <- context$X_train
    na <- function(reason) {
      c(results, list(check_result(
        "split_overlap", "validation", "NOT_APPLICABLE", reason, TRUE,
        list(check = "overlap_with_training"))))
    }
    if (is.null(train) || nrow(train) == 0L || ncol(train) == 0L) {
      return(na(paste0("no X_train supplied - supply the training frame and this check ",
                       "reports how many validation rows the model has already seen")))
    }
    shared <- intersect(names(validation), names(train))
    if (length(shared) == 0L) {
      return(na(paste0("X and X_train share no column names, so rows cannot be compared ",
                       "- see the feature_contract check")))
    }

    overlapping <- sum(row_keys(validation[shared]) %in%
                         row_keys(train[shared]))
    fraction <- overlapping / n
    note <- if (n_dup > 0L && overlapping > 0L) {
      paste0(" - the validation set also contains duplicates, so some of this may be ",
             "coincidental repetition rather than a broken split")
    } else ""
    c(results, list(check_result(
      "split_overlap", "validation",
      if (fraction <= config$max_split_overlap) "OK" else "SPLIT_OVERLAP_RISK",
      detail = sprintf(
        "%d of %d validation rows (%s, max %s) also appear in X_train, compared over %d shared column(s)%s",
        overlapping, n, pct(fraction, 1), pct(config$max_split_overlap, 0),
        length(shared), note),
      blocking = TRUE,
      metadata = list(check = "overlap_with_training",
                      n_overlapping = overlapping,
                      overlap_fraction = round(fraction, 4),
                      threshold = config$max_split_overlap,
                      n_columns_compared = length(shared))
    )))
  })
  chk
}

# One model-card field as text, the way upstream reads it: missing, NULL, NA or
# empty all become "". A vector is joined so it is reported, not silently cut.
card_text <- function(card, field) {
  v <- card[[field]]
  if (is.null(v) || length(v) == 0L || all(is.na(v))) return("")
  paste(as.character(unlist(v)), collapse = ", ")
}

# Python's repr() of a string, so messages read the same as upstream's.
py_repr <- function(x) {
  if (grepl("'", x, fixed = TRUE) && !grepl("\"", x, fixed = TRUE)) {
    return(paste0("\"", x, "\""))
  }
  paste0("'", gsub("'", "\\'", x, fixed = TRUE), "'")
}

#' Was the holdout separated in time, or at random?
#'
#' A random split asks whether the model can predict a row it has not seen. An
#' out-of-time split asks whether it can predict *next period*, which is what a
#' deployed model will be asked to do. Seasonality, inflation and portfolio mix
#' all leak backwards through a random split.
#'
#' So `model_card$validation_strategy` is required, must be one of
#' `accepted_validation_strategies`, and for a high-risk use case (any of
#' [compliance_config()]'s `high_risk_use_cases` appearing in
#' `model_card$use_case`) must be out of time. Blocking.
#'
#' This is the one validation check that cannot be verified from the data. It
#' records a claim, which is what a model card is for. Port of
#' `ValidationStrategyCheck` in bdp-model-gate 0.7.0.
#'
#' @param config A [validation_config()].
#' @param compliance A [compliance_config()].
#' @return A `gate_check`.
#' @examples
#' card <- list(use_case = "credit_scoring", validation_strategy = "random_split")
#' report <- run_gate(gate_context(data.frame(x = 1:3), model_card = card),
#'                    list(validation_strategy_check()))
#' report$results[[1]]$detail
#' @export
validation_strategy_check <- function(config = validation_config(),
                                      compliance = compliance_config()) {
  new_check("validation_strategy", "validation", TRUE, function(context) {
    result <- function(flag, detail, metadata) {
      list(check_result("validation_strategy", "validation", flag, detail, TRUE, metadata))
    }
    card <- context$model_card
    if (length(card) == 0L) {
      return(result("NOT_APPLICABLE", paste0(
        "no model_card supplied - the validation strategy is a claim the card ",
        "records, not something measurable from the data"), list()))
    }

    declared <- tolower(trimws(card_text(card, "validation_strategy")))
    use_case <- tolower(card_text(card, "use_case"))
    high_risk <- any(vapply(compliance$high_risk_use_cases,
                            function(hr) grepl(hr, use_case, fixed = TRUE), logical(1)))
    options <- paste(config$accepted_validation_strategies, collapse = ", ")

    if (!nzchar(declared)) {
      return(result("VALIDATION_STRATEGY_RISK",
        paste0("model_card.validation_strategy missing - state how the holdout ",
               "was produced, one of: ", options),
        list(check = "declared", is_high_risk = high_risk)))
    }
    if (!declared %in% config$accepted_validation_strategies) {
      return(result("VALIDATION_STRATEGY_RISK",
        paste0("model_card.validation_strategy=", py_repr(declared), " is not a ",
               "recognised strategy - use one of: ", options, ". 'holdout' and ",
               "'out_of_time' are different claims and only one of them is checkable"),
        list(check = "recognised", declared = declared)))
    }

    out_of_time <- declared %in% config$out_of_time_strategies
    needs_out_of_time <- high_risk && config$require_out_of_time_for_high_risk && !out_of_time
    detail <- if (needs_out_of_time) {
      paste0(if (nzchar(use_case)) use_case else "this use case",
             " is high-risk and was validated with a ", py_repr(declared),
             " split - a random split cannot tell you whether the model holds up on ",
             "next period's business, which is what it will be applied to")
    } else {
      paste0("validated with a ", py_repr(declared), " split",
             if (out_of_time) " (out-of-time)" else "")
    }
    result(if (needs_out_of_time) "VALIDATION_STRATEGY_RISK" else "OK", detail,
           list(check = "out_of_time_for_high_risk", declared = declared,
                is_out_of_time = out_of_time, is_high_risk = high_risk))
  })
}

# A feature needs this many non-missing values in *both* frames to be scored
# for drift; below it a mean or a share is noise. Upstream's `_MIN_ROWS`.
min_usable_rows <- 20L

# Python's str() of a float, so a threshold reads as upstream prints it:
# the shortest form that round-trips, with ".0" on a whole number.
py_float <- function(x) {
  if (is.integer(x)) return(as.character(x))
  out <- NULL
  for (d in 15:17) {
    out <- sprintf(paste0("%.", d, "g"), x)
    if (as.numeric(out) == x) break
  }
  if (!grepl("[.eEn]", out)) out <- paste0(out, ".0")
  out
}

# Sample standard deviation (n - 1), written out so the package needs no
# imports.
sample_sd <- function(x) sqrt(sum((x - mean(x))^2) / (length(x) - 1L))

# Values as category labels that keep their type, as pandas does: the number 1
# and the string "1" are different levels; integer 1 and double 1 are the same.
category_keys <- function(x) {
  if (is.numeric(x)) paste0("n:", sprintf("%.17g", x))
  else if (is.logical(x)) paste0("b:", as.character(x))
  else paste0("s:", as.character(x))
}

# Total variation distance between two samples' category shares, on 0-1.
total_variation <- function(reference, live) {
  p <- table(category_keys(reference)) / length(reference)
  q <- table(category_keys(live)) / length(live)
  levels <- union(names(p), names(q))
  share <- function(tab) { s <- as.numeric(tab[levels]); s[is.na(s)] <- 0; s }
  0.5 * sum(abs(share(q) - share(p)))
}

#' Does the validation set still look like the training set?
#'
#' Train-serve skew: a feature whose distribution has moved between `X_train`
#' and `X`, so the model is graded on a population it was not fitted to. That
#' is not necessarily wrong - an out-of-time holdout *should* differ a little -
#' but a reviewer has to see it rather than infer it. **Non-blocking**: a
#' finding routes to `NEEDS_REVIEW`, because a gate that hard-fails on every
#' seasonal shift gets switched off.
#'
#' Numeric features (in both frames) are compared by standardised mean shift:
#' the difference in means over the training standard deviation, so the
#' threshold is unitless. Anything else is compared by total variation distance
#' between the two frequency tables, on 0-1. Missing values are dropped first,
#' and a feature with fewer than 20 usable values in either frame, or constant
#' in training, is not scored. One `DRIFT_RISK` result per drifted feature,
#' largest shift first.
#'
#' Port of `FeatureDriftCheck` in bdp-model-gate 0.7.0. One deliberate
#' difference: a training column whose values are all identical is always
#' treated as constant. Upstream tests its standard deviation against zero,
#' which rounding defeats for values such as 0.1, and then reports shifts in
#' the trillions.
#'
#' @param config A [validation_config()]; uses `drift_threshold` and
#'   `categorical_drift_threshold`.
#' @return A `gate_check`.
#' @examples
#' set.seed(1)
#' X_train <- data.frame(age = rnorm(200, 40, 10))
#' X_val <- data.frame(age = rnorm(100, 46, 10))   # six years older on average
#' report <- run_gate(gate_context(X_val, X_train = X_train), list(feature_drift_check()))
#' gate_status(report)                              # NEEDS_REVIEW: drift is not blocking
#' report$results[[1]]$detail
#' @export
feature_drift_check <- function(config = validation_config()) {
  new_check("feature_drift", "validation", FALSE, function(context) {
    result <- function(flag, detail, metadata = list()) {
      check_result("feature_drift", "validation", flag, detail, FALSE, metadata)
    }
    train <- context$X_train
    if (is.null(train) || nrow(train) == 0L || ncol(train) == 0L) {
      return(list(result("NOT_APPLICABLE", paste0(
        "no X_train supplied - train-serve skew needs the training frame to ",
        "compare against"))))
    }
    shared <- intersect(names(context$X), names(train))
    if (length(shared) == 0L) {
      return(list(result("NOT_APPLICABLE",
        "X and X_train share no column names - see the feature_contract check")))
    }

    drifted <- list()
    scored <- 0L
    for (feature in shared) {
      reference <- train[[feature]]
      live <- context$X[[feature]]
      reference <- reference[!is.na(reference)]
      live <- live[!is.na(live)]
      if (length(reference) < min_usable_rows || length(live) < min_usable_rows) next

      if (is.numeric(reference) && is.numeric(live)) {
        if (all(reference == reference[1])) next  # constant: no scale to measure against
        spread <- sample_sd(reference)
        if (!is.finite(spread) || spread == 0) next
        shift <- abs(mean(live) - mean(reference)) / spread
        limit <- config$drift_threshold
        unit <- "standardised mean shift"
      } else {
        shift <- total_variation(reference, live)
        limit <- config$categorical_drift_threshold
        unit <- "total variation distance"
      }
      scored <- scored + 1L
      if (isTRUE(shift > limit)) {
        drifted[[length(drifted) + 1L]] <- list(feature = feature, shift = shift,
                                                limit = limit, unit = unit)
      }
    }

    if (scored == 0L) {
      return(list(result("NOT_APPLICABLE", sprintf(
        "no shared feature had at least %d usable rows in both frames", min_usable_rows))))
    }
    if (length(drifted) == 0L) {
      return(list(result("OK", sprintf(
        "no drift above threshold across %d shared feature(s)", scored),
        list(n_features_scored = scored))))
    }

    shifts <- vapply(drifted, function(d) d$shift, numeric(1))
    lapply(drifted[order(-shifts)], function(d) {
      result("DRIFT_RISK",
        sprintf(paste0("%s: %s %.3f between training and validation (max %s) - the ",
                       "model is being graded on a different population from the one ",
                       "it was fitted to"),
                d$feature, d$unit, d$shift, py_float(d$limit)),
        list(feature = d$feature, shift = round(d$shift, 4), threshold = d$limit,
             measure = d$unit, n_features_scored = scored))
    })
  })
}

#' Are these the columns the model was fitted on, in the order it expects?
#'
#' Silent column reordering is a classic production failure: a model handed a
#' positional matrix scores confidently against the wrong features and nothing
#' raises. A formula-based R model matches columns by name, but anything given
#' `as.matrix(X)` - glmnet, xgboost, a scoring endpoint - does not.
#'
#' The expected columns come from `expected_features` in the [gate_context()]
#' if given, otherwise from the columns of `X_train`. Blocking:
#' `FEATURE_CONTRACT_RISK` when a column is missing from `X` or was not seen in
#' training, `FEATURE_ORDER_RISK` when the columns match but their order does
#' not.
#'
#' Port of `FeatureContractCheck` in bdp-model-gate 0.7.0. One difference:
#' upstream can also read the fitted column names from scikit-learn, LightGBM
#' and XGBoost model objects. R models record their columns in different ways,
#' so pass `expected_features` when the training frame is not to hand.
#'
#' @return A `gate_check`.
#' @examples
#' X_val <- data.frame(income = c(30, 42), age = c(25, 32))    # columns swapped
#' report <- run_gate(gate_context(X_val, expected_features = c("age", "income")),
#'                    list(feature_contract_check()))
#' report$results[[1]]$flag
#' @export
feature_contract_check <- function() {
  new_check("feature_contract", "validation", TRUE, function(context) {
    result <- function(flag, detail, metadata = list()) {
      list(check_result("feature_contract", "validation", flag, detail, TRUE, metadata))
    }
    train <- context$X_train
    if (!is.null(context$expected_features)) {
      expected <- context$expected_features
      source <- "context.expected_features"
    } else if (!is.null(train) && nrow(train) > 0L && ncol(train) > 0L) {
      expected <- names(train)
      source <- "X_train.columns"
    } else {
      return(result("NOT_APPLICABLE", paste0(
        "cannot tell what the model was fitted on - supply context.X_train, or ",
        "context.expected_features for a model whose schema this library cannot ",
        "read (a remote endpoint, say)")))
    }

    actual <- names(context$X)
    n <- length(expected)
    missing <- expected[!expected %in% actual]
    extra <- actual[!actual %in% expected]

    if (length(missing) > 0L || length(extra) > 0L) {
      problems <- c(
        if (length(missing) > 0L) paste0("missing from X: ", paste(missing, collapse = ", ")),
        if (length(extra) > 0L) paste0("not seen in training: ", paste(extra, collapse = ", "))
      )
      return(result("FEATURE_CONTRACT_RISK",
        paste0("X does not match the ", n, " feature(s) recorded in ", source, " - ",
               paste(problems, collapse = "; ")),
        list(check = "feature_set", source = source, missing = missing,
             unexpected = extra, n_expected = n)))
    }

    order_differs <- !identical(actual[actual %in% expected], expected[expected %in% actual])
    detail <- if (order_differs) {
      paste0("X has the right ", n, " features but in a different order from ", source,
             " - harmless for an estimator that reads column names, silently wrong for ",
             "anything handed a positional array")
    } else {
      paste0("X matches the ", n, " feature(s) recorded in ", source, ", in order")
    }
    result(if (order_differs) "FEATURE_ORDER_RISK" else "OK", detail,
           list(check = "feature_order", source = source, n_features = n,
                expected_order = if (order_differs) expected else NULL,
                actual_order = if (order_differs) actual else NULL))
  })
}

# How much of the target one column explains on its own, on a 0-1 scale that
# is the same for a feature and for the model's predictions: |2 AUC - 1| for a
# binary target, |r| for a continuous one, and for a non-numeric column the
# square root of its correlation ratio with the target. NULL when there is
# nothing to measure: fewer than 20 values, an undefined AUC, or so many
# distinct levels that the column is effectively an identifier.
solo_power <- function(column, target, binary) {
  usable <- !is.na(column)
  if (sum(usable) < min_usable_rows) return(NULL)
  values <- column[usable]
  y <- target[usable]

  if (!is.numeric(values)) {
    levels <- as.character(values)
    if (length(unique(levels)) > max(20L, length(values) %/% 10L)) return(NULL)
    return(sqrt(eta_squared(y, levels)))
  }
  values <- as.numeric(values)
  if (all(values == values[1])) return(0)
  if (binary) {
    auc <- rank_auc(y != 0, values)
    return(if (is.nan(auc)) NULL else abs(2 * auc - 1))
  }
  abs_pearson(values, y)
}

#' Does a single column do what the whole model does?
#'
#' The signature of a leaked target: a field filled in *after* the outcome was
#' known and joined back into the data - a settlement amount on a claims model,
#' a closure reason on a churn model, an ID ordered by outcome. The model learns
#' it, scores beautifully offline, and collapses in production where the column
#' is empty at scoring time.
#'
#' Each column's solo power is compared with the power of `y_pred`, on the same
#' 0-1 scale: |2 AUC - 1| for a binary target, |r| for a continuous one, and the
#' square root of the correlation ratio for a non-numeric column. A column is
#' flagged (`LEAKAGE_RISK`, blocking) only when its power reaches both
#' `leakage_min_power` and `leakage_ratio` times the model's: on a model scoring
#' 0.55, a feature scoring 0.54 is 98% of it and means nothing.
#'
#' Needs `y_true` and `y_pred`. The task comes from [gate_context()]'s `task`,
#' inferred from `y_true` when `"auto"`.
#'
#' Port of `LeakageCheck` in bdp-model-gate 0.7.0, for binary and regression
#' targets. Differences: a multiclass target is skipped with a reason (not yet
#' ported); rows with a missing `y_true` are left out and counted, where
#' upstream counts them as positives (binary) or returns `OK` with a model power
#' of NaN (regression); and a model power that is not finite is skipped rather
#' than reported.
#'
#' @param config A [validation_config()]; uses `leakage_ratio` and
#'   `leakage_min_power`.
#' @return A `gate_check`.
#' @examples
#' set.seed(1)
#' y <- rbinom(200, 1, 0.3)
#' score <- plogis(-1 + 2 * y + rnorm(200))        # a reasonable model's scores
#' X <- data.frame(age = rnorm(200, 40, 10),
#'                 settled_amount = y * runif(200, 1000, 5000))   # only known after the outcome
#' report <- run_gate(gate_context(X, y_true = y, y_pred = score), list(target_leakage_check()))
#' report$results[[1]]$detail
#' @export
target_leakage_check <- function(config = validation_config()) {
  new_check("target_leakage", "validation", TRUE, function(context) {
    result <- function(flag, detail, metadata = list()) {
      check_result("target_leakage", "validation", flag, detail, TRUE, metadata)
    }
    skip <- function(reason) list(result("NOT_APPLICABLE", reason))

    if (is.null(context$y_true) || is.null(context$y_pred)) {
      return(skip(paste0("no y_true/y_pred - leakage is measured by comparing each ",
                         "feature's solo predictive power against the model's own")))
    }
    task <- resolve_task(context)
    if (task == "multiclass") {
      return(skip(paste0(
        "multiclass targets are not ported yet - leakage needs the target reduced to ",
        "the one outcome a feature might be leaking. If y_true is a count or a score ",
        "rather than a set of classes, set task = \"regression\"")))
    }
    binary <- task == "binary"

    y <- context$y_true
    if (!is.numeric(y) && !is.logical(y)) {
      stop(task, " y_true must be numeric or logical, not ", class(y)[1],
           " - recode the outcome a feature might be leaking as 1 and every other as 0",
           call. = FALSE)
    }
    if (!is.numeric(context$y_pred) && !is.logical(context$y_pred)) {
      stop("y_pred must be a numeric score or a 0/1 prediction, not ",
           class(context$y_pred)[1], call. = FALSE)
    }

    known <- !is.na(y)
    n_left_out <- sum(!known)
    target <- as.numeric(y[known])
    scores <- as.numeric(context$y_pred[known])
    X <- context$X[known, , drop = FALSE]
    note <- if (n_left_out > 0L) {
      sprintf(" (%d row(s) with no y_true were left out)", n_left_out)
    } else ""

    model_power <- solo_power(scores, target, binary)
    if (is.null(model_power) || !is.finite(model_power) || model_power <= 0) {
      return(skip(paste0("the model's predictions carry no signal against y_true, so ",
                         "there is nothing for a feature to be suspiciously close to", note)))
    }

    suspects <- list()
    for (feature in names(X)) {
      power <- solo_power(X[[feature]], target, binary)
      if (is.null(power)) next
      if (isTRUE(power >= config$leakage_min_power) &&
          isTRUE(power >= config$leakage_ratio * model_power)) {
        suspects[[length(suspects) + 1L]] <- list(feature = feature, power = power)
      }
    }

    if (length(suspects) == 0L) {
      return(list(result("OK",
        sprintf("no single feature approaches the model's own predictive power (%.3f)%s",
                model_power, note),
        list(model_power = round(model_power, 4),
             threshold_ratio = config$leakage_ratio,
             min_power = config$leakage_min_power,
             n_features_scored = ncol(context$X)))))
    }

    powers <- vapply(suspects, function(s) s$power, numeric(1))
    lapply(suspects[order(-powers)], function(s) {
      result("LEAKAGE_RISK",
        sprintf(paste0("%s alone reaches %.3f of the target on its own, %.0f%% of the ",
                       "whole model's %.3f - check it is populated before the outcome is ",
                       "known, and is available at scoring time%s"),
                s$feature, s$power, 100 * (s$power / model_power), model_power, note),
        list(feature = s$feature,
             feature_power = round(s$power, 4),
             model_power = round(model_power, 4),
             power_ratio = round(s$power / model_power, 4),
             threshold_ratio = config$leakage_ratio,
             min_power = config$leakage_min_power))
    })
  })
}
