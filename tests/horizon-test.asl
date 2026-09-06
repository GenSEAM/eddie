(module asl-eddie/horizon-test
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
    (and (== (len (.-interface-stubs res0)) 0)
         (== (len (.-interface-stubs res1)) 2))))

(df test-horizon-budget-bounding [] -> Bool
  (let [(req (hor/make-horizon-request "agent/step" 2 1000))
        (res (hor/expand-horizon req))]
    (<= (.-tokens-used res) 1000)))

(df test-health-matrix-cycle-detection [] -> Bool
  (let [(m-ok (hor/compute-health-matrix (list "a" "b") false))
        (m-cyc (hor/compute-health-matrix (list "a" "b") true))]
    (and (.-is-healthy m-ok)
         (and (not (.-is-healthy m-cyc))
              (== (len (.-cycles m-cyc)) 1)))))

(df test-health-summary-formatting [] -> Bool
  (let [(m (hor/compute-health-matrix (list "a") false))
        (summary (hor/format-health-summary m))]
    (>= (len summary) 15)))

(df run-tests [] -> Bool
  (and (and (test-horizon-depth-expansion)
            (test-horizon-budget-bounding))
       (and (test-health-matrix-cycle-detection)
            (test-health-summary-formatting))))
