# Small statistics written out so the package needs no imports.

# Area under the ROC curve via the Mann-Whitney U statistic, with tied scores
# sharing their average rank. NaN when one class is absent.
rank_auc <- function(positive, scores) {
  n_pos <- sum(positive)
  n_neg <- length(positive) - n_pos
  if (n_pos == 0 || n_neg == 0) return(NaN)
  ranks <- rank(scores, ties.method = "average")
  (sum(ranks[positive]) - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

# |Pearson r|, or 0 when either side is constant (it correlates with nothing).
abs_pearson <- function(a, b) {
  if (all(a == a[1]) || all(b == b[1])) return(0)
  da <- a - mean(a)
  db <- b - mean(b)
  abs(sum(da * db) / sqrt(sum(da^2) * sum(db^2)))
}

# eta squared: the share of x's variance explained by group membership.
eta_squared <- function(x, groups) {
  if (length(x) == 0L) return(0)
  overall <- mean(x)
  ss_total <- sum((x - overall)^2)
  if (ss_total <= 0) return(0)
  g <- match(groups, unique(groups))
  counts <- tabulate(g)
  group_means <- as.vector(rowsum(x, g)) / counts
  sum(counts * (group_means - overall)^2) / ss_total
}
