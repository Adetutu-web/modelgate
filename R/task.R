# An integer-valued target with at most this many distinct values is read as
# multiclass; more is regression. Upstream's MAX_INFERRED_CLASSES.
max_inferred_classes <- 20L

# Best-effort task inference from y_true, as upstream: text, factors and
# logicals are classification; two distinct values are binary; whole numbers
# with few distinct values are multiclass; anything else is regression.
infer_task <- function(y) {
  if (is.character(y) || is.factor(y) || is.logical(y)) {
    n <- length(unique(y[!is.na(y)]))
    return(if (n <= 2L) "binary" else "multiclass")
  }
  values <- unique(y[is.finite(y)])
  if (length(values) <= 2L) return("binary")
  if (all(values %% 1 == 0) && length(values) <= max_inferred_classes) return("multiclass")
  "regression"
}

# The task to use for a context: as stated, or inferred from y_true. With no
# y_true there is nothing to infer from, and upstream assumes binary.
resolve_task <- function(context) {
  task <- if (is.null(context$task)) "auto" else context$task
  if (task != "auto") return(task)
  if (is.null(context$y_true)) return("binary")
  infer_task(context$y_true)
}
