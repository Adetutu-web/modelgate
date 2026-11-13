#' Everything a check may look at
#'
#' @param X data.frame of validation features.
#' @param y_true,y_pred Optional vectors with one element per row of `X`.
#' @param X_train Optional data.frame of training features.
#' @param protected_df Optional data.frame of protected attributes, one row per
#'   row of `X`. Used only to measure fairness, never to fit.
#' @param model_card Optional named list describing the model.
#' @return An object of class `gate_context`.
#' @export
gate_context <- function(X, y_true = NULL, y_pred = NULL, X_train = NULL,
                         protected_df = NULL, model_card = NULL) {
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
  structure(
    list(X = X, y_true = y_true, y_pred = y_pred, X_train = X_train,
         protected_df = protected_df, model_card = model_card),
    class = "gate_context"
  )
}
