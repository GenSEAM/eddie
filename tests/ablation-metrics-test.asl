(module asl-agent/ablation-metrics-test
  :d "Empirical ablation suite measuring WITH vs WITHOUT deltas across Eddie TUI improvements."
  :x [test-feedback-token-ablation
      test-autonomy-friction-ablation
      test-tui-folding-ablation
      run-tests]
  :i [(feedback :a fb) (policy :a pol) (tui :a tui)])

(df test-feedback-token-ablation [] -> Bool
  :d "Verifies token compaction of zero-fluff feedback engine vs verbose conversational response."
  (let [(verbose-msg "Certainly! I'd be happy to help with that. Please let me know if you need anything else. We will now update src/app.asl.")
        (clean-msg (fb/strip-polite-fluff verbose-msg))
        (verbose-toks (/ (string-length verbose-msg) 4))
        (clean-toks (/ (string-length clean-msg) 4))]
    (assert (< clean-toks verbose-toks) "clean tokens < verbose tokens")
    (assert (> verbose-toks 25) "verbose tokens > 25")
    true))

(df test-autonomy-friction-ablation [] -> Bool
  :d "Verifies that L1:Guarded eliminates prompt friction on read-only operations while preserving mutation safety."
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-guarded)))]
    (assert (.-silent r-read) "read must be silent")
    (assert (not (.-silent r-write)) "write must not be silent")
    true))

(df test-tui-folding-ablation [] -> Bool
  :d "Verifies that tool call folding reduces terminal output clutter from multi-line dump to 1 line."
  (let [(folding (tui/format-tool-call "patch" "src/app.asl:42" "applied (<50us)"))]
    (assert (string-contains? folding "▶ [patch]") "folding contains marker")
    (assert (not (string-contains? folding "\n")) "folding single line")
    true))

(df run-tests [] -> Bool
  (do
    (assert (test-feedback-token-ablation) "test-feedback-token-ablation must pass")
    (assert (test-autonomy-friction-ablation) "test-autonomy-friction-ablation must pass")
    (assert (test-tui-folding-ablation) "test-tui-folding-ablation must pass")
    true))
