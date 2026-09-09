(module asl-agent/horizon-test
  :d "Unit tests for graph-horizon preloading and architectural health matrix."
  :x [test-horizon-depth-expansion
      test-horizon-budget-bounding
      test-health-matrix-cycle-detection
      test-health-summary-formatting
      run-tests]
  :i [(horizon :a hor)])

"run: (run-tests)"

(df test-horizon-depth-expansion [] -> Bool
  (let [(req0 (hor/make-horizon-request "policy/check" 0 500))
        (res0 (hor/expand-horizon req0))
        (req1 (hor/make-horizon-request "policy/check" 1 500))
        (res1 (hor/expand-horizon req1))]
    (assert (= (list-length (.-interface-stubs res0)) 0) "depth 0 has 0 stubs")
    (assert (= (list-length (.-interface-stubs res1)) 2) "depth 1 has 2 stubs")
    true))

(df test-horizon-budget-bounding [] -> Bool
  (let [(req (hor/make-horizon-request "agent/step" 2 1000))
        (res (hor/expand-horizon req))]
    (assert (<= (.-tokens-used res) 1000) "tokens used within budget")
    (assert (> (.-tokens-used res) 0) "tokens used is positive")
    true))

(df test-health-matrix-cycle-detection [] -> Bool
  (let [(m-ok (hor/compute-health-matrix (list "a" "b") false))
        (m-cyc (hor/compute-health-matrix (list "a" "b") true))]
    (assert (.-is-healthy m-ok) "matrix without cycles is healthy")
    (assert (not (.-is-healthy m-cyc)) "matrix with cycles is unhealthy")
    (assert (= (list-length (.-cycles m-cyc)) 1) "matrix has 1 cycle")
    true))

(df test-health-summary-formatting [] -> Bool
  (let [(m (hor/compute-health-matrix (list "a") false))
        (summary (hor/format-health-summary m))]
    (assert (>= (string-length summary) 15) "health summary length >= 15")
    (assert (not (string-contains? summary "unhealthy")) "healthy summary does not contain unhealthy")
    true))

(df run-tests [] -> Bool
  (do
    (test-horizon-depth-expansion)
    (test-horizon-budget-bounding)
    (test-health-matrix-cycle-detection)
    (test-health-summary-formatting)
    true))
