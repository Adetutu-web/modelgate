# Parity with bdp-model-gate 0.7.0, from fixtures made by tools/make_parity_fixtures.py.
# Parity is a second layer: the Python library has shipped wrong-but-plausible
# numbers before, so hand-derived known answers (test-split-overlap.R) come first.
skip_if_not_installed("jsonlite")
fx <- jsonlite::fromJSON(testthat::test_path("fixtures", "split_overlap_parity.json"),
                         simplifyVector = FALSE)

col_from_json <- function(x) {
  if (length(x) == 0L) return(logical(0))
  unlist(lapply(x, function(v) if (is.null(v)) NA else v))
}
frame_from_json <- function(cols) {
  if (is.null(cols)) return(NULL)
  as.data.frame(lapply(cols, col_from_json), stringsAsFactors = FALSE, check.names = FALSE)
}

test_that("fixtures were generated from the pinned upstream version", {
  expect_equal(fx$upstream_version, "0.7.0")
  expect_gt(length(fx$cases), 8L)
})

for (case in fx$cases) {
  local({
    case <- case
    test_that(paste("parity:", case$name), {
      cfg <- do.call(validation_config, case$config)
      expect_error_expected <- identical(case$expected[[1]]$flag, "CHECK_ERROR")
      rep <- run_gate_strict(
        gate_context(frame_from_json(case$X), X_train = frame_from_json(case$X_train)),
        list(split_overlap_check(cfg)),
        allow_check_error = expect_error_expected
      )
      expect_equal(length(rep$results), length(case$expected))
      for (i in seq_along(case$expected)) {
        got <- rep$results[[i]]; want <- case$expected[[i]]
        expect_equal(got$flag, want$flag, info = case$name)
        expect_equal(got$blocking, want$blocking, info = case$name)
        for (key in names(want$metadata)) {
          w <- want$metadata[[key]]
          if (is.numeric(w)) expect_equal(got$metadata[[key]], w, tolerance = 1e-4, info = paste(case$name, key))
          else expect_equal(got$metadata[[key]], w, info = paste(case$name, key))
        }
      }
    })
  })
}
