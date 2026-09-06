(module asl-eddie/onion-test
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
    (and (== (.-status res) "PROCEED")
         (== (.-payload res) "hello world"))))

(df test-onion-firewall-block [] -> Bool
  (let [(ctx (on/make-context "read-file" "../etc/passwd" "" 100 1000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))]
    (and (== (.-status res) "BLOCKED")
         (== (.-payload res) "ERROR: Blocked by mw-firewall"))))

(df test-onion-cost-guard-block [] -> Bool
  (let [(ctx (on/make-context "read-file" "src/app.asl" "" 2500 1000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))]
    (and (== (.-status res) "BLOCKED")
         (== (.-payload res) "ERROR: Blocked by mw-cost-guard (token budget exceeded)"))))

(df test-onion-sanitizer-truncate [] -> Bool
  (let [(long-trace (str "Trace: line 1\n"
                         "Trace: line 2\n"
                         "Trace: line 3\n"
                         "Error details: memory dump stack frame 0x42424242\n"
                         "Extra log information repeating over multiple lines to test the sanitizer boundary condition.\n"))
        (sanitized (on/run-sanitizer long-trace))]
    (<= (len sanitized) 1300)))

(df run-tests [] -> Bool
  (and (and (test-onion-pipeline-normal)
            (test-onion-firewall-block))
       (and (test-onion-cost-guard-block)
            (test-onion-sanitizer-truncate))))
