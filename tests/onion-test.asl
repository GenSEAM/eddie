(module asl-agent/onion-test
  :d "Unit tests for composable onion middleware pipeline and filters."
  :x [test-onion-pipeline-normal
      test-onion-firewall-block
      test-onion-cost-guard-block
      test-onion-sanitizer-truncate
      run-tests]
  :i [(onion :a on) (policy :a pol)])

"run: (run-tests)"

(df test-onion-pipeline-normal [] -> Bool
  (let [(ctx (on/make-context "read-file" "src/app.asl" "hello world" 100 1000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))]
    (assert (= (.-status res) "PROCEED") "normal pipeline status is PROCEED")
    (assert (= (.-payload res) "hello world") "payload matches")
    true))

(df test-onion-firewall-block [] -> Bool
  (let [(ctx (on/make-context "read-file" "../etc/passwd" "" 100 1000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))]
    (assert (= (.-status res) "BLOCKED") "firewall status is BLOCKED")
    (assert (= (.-payload res) "ERROR: Blocked by mw-firewall") "firewall payload matches")
    true))

(df test-onion-cost-guard-block [] -> Bool
  (let [(ctx (on/make-context "read-file" "src/app.asl" "" 2500 1000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))]
    (assert (= (.-status res) "BLOCKED") "cost guard status is BLOCKED")
    (assert (= (.-payload res) "ERROR: Blocked by mw-cost-guard (token budget exceeded)") "cost guard payload matches")
    true))

(df test-onion-sanitizer-truncate [] -> Bool
  (let [(long-trace (str "Trace: line 1\n"
                         "Trace: line 2\n"
                         "Trace: line 3\n"
                         "Error details: memory dump stack frame 0x42424242\n"
                         "Extra log information repeating over multiple lines to test the sanitizer boundary condition.\n"))
        (sanitized (on/run-sanitizer long-trace))]
    (assert (<= (string-length sanitized) 1300) "sanitizer length <= 1300")
    true))

(df run-tests [] -> Bool
  (do
    (test-onion-pipeline-normal)
    (test-onion-firewall-block)
    (test-onion-cost-guard-block)
    (test-onion-sanitizer-truncate)
    true))
