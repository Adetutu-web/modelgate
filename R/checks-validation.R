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
