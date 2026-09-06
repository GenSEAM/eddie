(module asl-eddie/agent-test
  :d "Unit tests for Core Agent loop, autonomy levels, and eddie-run entrypoint."
  :x [test-agent-autonomy-levels
      test-agent-tui-folding-history
      test-eddie-run-clarification
      test-eddie-run-direct
      run-tests]
  :i [(policy :a pol) (agent :a ag) (eddie :a ed)])

"run: (run-tests)"

(df test-agent-autonomy-levels [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        ;; L0 Ask
        (s0 (ag/make-autonomy-session "inspect" m (pol/level-ask)))
        (r0 (ag/step-agent s0 "write" "/workspace/src/test.asl" "dummy"))
        ;; L1 Guarded
        (s1 (ag/make-autonomy-session "inspect" m (pol/level-guarded)))
        (r1-read (ag/step-agent s1 "read" "/workspace/src/test.asl" ""))
        (r1-write (ag/step-agent (.-session r1-read) "write" "/workspace/src/test.asl" "dummy"))
        ;; L2 FullAuto
        (s2 (ag/make-autonomy-session "inspect" m (pol/level-auto)))
        (r2-write (ag/step-agent s2 "write" "/workspace/src/test.asl" "dummy"))]
    (and (string-starts-with? (.-action-taken r0) "prompt:write")
         (and (string-starts-with? (.-action-taken r1-read) "executed:read")
              (and (string-starts-with? (.-action-taken r1-write) "prompt:write")
                   (string-starts-with? (.-action-taken r2-write) "executed:write"))))))

(df test-agent-tui-folding-history [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (s (ag/make-autonomy-session "read main" m (pol/level-auto)))
        (res (ag/step-agent s "read" "/workspace/src/main.asl" ""))
        (hist (.-history (.-session res)))]
    (let [(has-folded (not (list-empty? (filter (fn [(x Str)] -> Bool (string-contains? x "▶ [read]")) hist))))]
      has-folded)))

(df test-eddie-run-clarification [] -> Bool
  (let [(out (eddie/eddie-run "help" "/workspace" (pol/level-guarded)))]
    (and (string-contains? out "Need clarification")
         (string-contains? out "[1]"))))

(df test-eddie-run-direct [] -> Bool
  (let [(out (eddie/eddie-run "Audit dependencies in /workspace/src/main.asl" "/workspace" (pol/level-auto)))]
    (and (string-contains? out "Eddie TUI")
         (and (string-contains? out "Goal:")
              (string-contains? out "Session complete")))))

(df run-tests [] -> Bool
  (and (and (test-agent-autonomy-levels)
            (test-agent-tui-folding-history))
       (and (test-eddie-run-clarification)
            (test-eddie-run-direct))))
