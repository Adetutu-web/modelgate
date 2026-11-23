#' Everything a check may look at
#'
#' @param X data.frame of validation features.
#' @param y_true,y_pred Optional vectors with one element per row of `X`.
#' @param X_train Optional data.frame of training features.
#' @param protected_df Optional data.frame of protected attributes, one row per
#'   row of `X`. Used only to measure fairness, never to fit.
#' @param model_card Optional named list describing the model.
#' @param expected_features Optional character vector: the columns the model
#'   was fitted on, in the order it expects them. Used by
#'   [feature_contract_check()]; without it that check falls back to the
#'   columns of `X_train`.
#' @param task What the model predicts: `"binary"`, `"multiclass"`,
#'   `"regression"`, or `"auto"` (the default) to infer it from `y_true`.
#'   Inference cannot tell a count target such as claims frequency from a
#'   set of classes, so state it for anything you gate on.
#' @return An object of class `gate_context`.
#' @export
gate_context <- function(X, y_true = NULL, y_pred = NULL, X_train = NULL,
                         protected_df = NULL, model_card = NULL,
                         expected_features = NULL, task = "auto") {
  if (!is.data.frame(X)) {
    stop("`X` must be a data.frame, not ", class(X)[1], ".", call. = FALSE)
  }
  if (!is.null(X_train) && !is.data.frame(X_train)) {
    stop("`X_train` must be a data.frame or NULL, not ", class(X_train)[1], ".", call. = FALSE)
  }
  if (!is.null(protected_df)) {
    if (!is.data.frame(protected_df)) stop("`protected_df` must be a data.frame or NULL.", call. = FALSE)
    if (nrow(protected_df) != nrow(X)) {
      stop("`protected_df` has ", nrow(protected_df), " rows but `X` has ", nrow(X), ".", call. = FALSE)
    }
  }
  for (nm in c("y_true", "y_pred")) {
    v <- get(nm)
    if (!is.null(v) && length(v) != nrow(X)) {
      stop("`", nm, "` has length ", length(v), " but `X` has ", nrow(X), " rows.", call. = FALSE)
    }
  }
  if (!is.null(model_card) && !is.list(model_card)) stop("`model_card` must be a list or NULL.", call. = FALSE)
  if (!is.null(expected_features) && (!is.character(expected_features) || anyNA(expected_features))) {
    stop("`expected_features` must be a character vector with no missing values, or NULL.", call. = FALSE)
  }
  task_options <- c("auto", "binary", "multiclass", "regression")
  if (!is.character(task) || length(task) != 1L || is.na(task) || !task %in% task_options) {
    stop("`task` must be one of: ", paste(task_options, collapse = ", "), ".", call. = FALSE)
  }
  structure(
    list(X = X, y_true = y_true, y_pred = y_pred, X_train = X_train,
         protected_df = protected_df, model_card = model_card,
         expected_features = expected_features, task = task),
    class = "gate_context"
  )
}
