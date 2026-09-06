(module asl-agent/ablation-metrics-test
  :d "Empirical ablation suite measuring WITH vs WITHOUT deltas across Eddie TUI improvements."
  :x [test-feedback-token-ablation
      test-autonomy-friction-ablation
      test-tui-folding-ablation
      run-tests]
  :i [(feedback :a fb) (policy :a pol) (tui :a tui)])

"run: (run-tests)"

(df test-feedback-token-ablation [] -> Bool
  :d "Verifies token compaction of zero-fluff feedback engine vs verbose conversational response."
  (let [(verbose-msg "Certainly! I'd be happy to help with that. Please let me know if you need anything else. We will now update src/app.asl.")
        (clean-msg (fb/strip-polite-fluff verbose-msg))
        (verbose-toks (/ (string-length verbose-msg) 4))
        (clean-toks (/ (string-length clean-msg) 4))]
    (and (< clean-toks verbose-toks)
         (> verbose-toks 25))))

(df test-autonomy-friction-ablation [] -> Bool
  :d "Verifies that L1:Guarded eliminates prompt friction on read-only operations while preserving mutation safety."
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-guarded)))]
    (and (.-silent r-read)
         (not (.-silent r-write)))))

(df test-tui-folding-ablation [] -> Bool
  :d "Verifies that tool call folding reduces terminal output clutter from multi-line dump to 1 line."
  (let [(folding (tui/format-tool-call "patch" "src/app.asl:42" "applied (<50us)"))]
    (and (string-contains? folding "▶ [patch]")
         (not (string-contains? folding "\n")))))

(df run-tests [] -> Bool
  (and (and (test-feedback-token-ablation)
            (test-autonomy-friction-ablation))
       (test-tui-folding-ablation)))
