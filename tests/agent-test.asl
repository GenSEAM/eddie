(module asl-agent/agent-test
  :d "Unit tests for Core Agent loop, autonomy levels, and eddie-run entrypoint."
  :x [test-agent-autonomy-levels
      test-agent-tui-folding-history
      test-eddie-run-clarification
      test-eddie-run-direct
      test-empty-goal-edge
      run-tests]
  :i [(policy :a pol) (agent :a ag) (eddie :a eddie)])

(df test-agent-autonomy-levels [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (s0 (ag/make-autonomy-session "inspect" m (pol/level-ask)))
        (r0 (ag/step-agent s0 "write" "/workspace/src/test.asl" "dummy"))
        (s1 (ag/make-autonomy-session "inspect" m (pol/level-guarded)))
        (r1-read (ag/step-agent s1 "read" "/workspace/src/test.asl" ""))
        (r1-write (ag/step-agent (.-session r1-read) "write" "/workspace/src/test.asl" "dummy"))
        (s2 (ag/make-autonomy-session "inspect" m (pol/level-auto)))
        (r2-write (ag/step-agent s2 "write" "/workspace/src/test.asl" "dummy"))]
    (do
      (assert (string-starts-with? (.-action-taken r0) "prompt:write") "c-agent-neg-001: L0 prompts for write")
      (assert (string-starts-with? (.-action-taken r1-read) "executed:read") "c-agent-pos-002: L1 reads ok")
      (assert (string-starts-with? (.-action-taken r2-write) "executed:write") "c-agent-pos-002: L2 auto write")
      (assert (not (string-starts-with? (.-action-taken r0) "executed:write")) "c-agent-neg-001: L0 never auto writes")
      true)))

(df test-agent-tui-folding-history [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (s (ag/make-autonomy-session "read main" m (pol/level-auto)))
        (res (ag/step-agent s "read" "/workspace/src/main.asl" ""))
        (hist (.-history (.-session res)))]
    (let [(has-folded (not (list-empty? (filter (fn [(x Str)] -> Bool (string-contains? x "[>] [read]")) hist))))]
      (do
        (assert has-folded "c-agent-edge-002: folding history present")
        (assert (not (list-empty? hist)) "c-agent-edge-002: history not empty")
        true))))

(df test-eddie-run-clarification [] -> Bool
  (let [(out (eddie/eddie-run "help" "/workspace" (pol/level-guarded)))]
    (do
      (assert (string-contains? out "Need clarification") "c-agent-pos-001: clarification requested")
      (assert (string-contains? out "[1]") "c-agent-pos-001: option 1 rendered")
      (assert (not (string-contains? out "Fatal error")) "c-agent-neg-002: no fatal crash")
      true)))

(df test-eddie-run-direct [] -> Bool
  (let [(out (eddie/eddie-run "Audit dependencies in /workspace/src/main.asl" "/workspace" (pol/level-auto)))]
    (do
      (assert (string-contains? out "Goal:") "c-agent-pos-001: goal displayed")
      (assert (string-contains? out "Session complete") "c-agent-pos-001: session completed")
      (assert (not (string-contains? out "panic")) "c-agent-neg-002: no panic")
      true)))

(df test-addie-run-direct [] -> Bool
  (let [(out (eddie/addie-run "Audit dependencies in /workspace/src/main.asl" "/workspace" (pol/level-auto)))]
    (do
      (assert (string-contains? out "Goal:") "c-agent-pos-001: goal displayed")
      (assert (string-contains? out "Session complete") "c-agent-pos-001: session completed")
      (assert (not (string-contains? out "unhandled exception")) "c-agent-neg-002: no exception")
      true)))

(df test-addie-version [] -> Bool
  (do
    (assert (= (eddie/addie-version) "0.1.0") "c-agent-pos-003: addie version is 0.1.0")
    (assert (= (eddie/eddie-version) "0.1.0") "c-agent-pos-003: eddie version is 0.1.0")
    (assert (not (= (eddie/addie-version) "0.0.0")) "c-agent-neg-001: version not 0.0.0")
    true))

(df test-empty-goal-edge [] -> Bool
  (let [(manifest (pol/make-manifest "/tmp" (list) "/tmp" false))
        (sess (ag/make-autonomy-session "" manifest (pol/level-auto)))]
    (assert (= (.-goal (.-state sess)) "") "c-agent-edge-001: handles empty goal")
    (assert (not (.-is-terminal (.-state sess))) "c-agent-edge-001: not terminal")
    true))

(df run-tests [] -> Bool
  (do
    (assert (test-agent-autonomy-levels) "autonomy levels pass")
    (assert (test-agent-tui-folding-history) "tui folding history pass")
    (assert (test-eddie-run-clarification) "clarification pass")
    (assert (test-eddie-run-direct) "eddie direct pass")
    (assert (test-addie-run-direct) "addie direct pass")
    (assert (test-addie-version) "version pass")
    (assert (test-empty-goal-edge) "empty goal edge pass")
    true))
