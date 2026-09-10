(module asl-agent/test-intent-ux
  :d "Unit tests for holistic intent taxonomy, focus guard, and proactive nudge engine"
  :x [test-intent-classification
      test-focus-guard-disruption
      test-nudge-streak-and-interval
      test-nudge-guard-hold-and-release
      run-all-ux-tests]
  :i [(intent_ux :a ux)
      (nudge_guard :a ng)])

(df test-intent-classification [] -> Bool
  (let [(i-fast (ux/classify-intent "стоп"))
        (i-intel (ux/classify-intent "где находится символ VadConfig"))
        (i-meta (ux/classify-intent "почему упало тестирование"))
        (i-res (ux/classify-intent "найди в документации api"))
        (i-dev (ux/classify-intent "исправь ошибку в парсере"))
        (i-mesh (ux/classify-intent "распредели на claude и antigravity"))]
    (assert (= (.-intent-id i-fast) "fast-path") "fast-path intent classified")
    (assert (= (.-intent-id i-intel) "intel") "intel intent classified")
    (assert (= (.-intent-id i-meta) "meta") "meta intent classified")
    (assert (= (.-intent-id i-res) "research") "research intent classified")
    (assert (= (.-intent-id i-dev) "dev") "dev intent classified")
    (assert (.-requires-worktree i-dev) "dev intent requires worktree isolation")
    (assert (.-requires-gate i-dev) "dev intent requires failing gate")
    (assert (= (.-intent-id i-mesh) "mesh") "mesh intent classified")
    true))

(df test-focus-guard-disruption [] -> Bool
  (let [(i-fast (ux/classify-intent "stop"))
        (i-dev (ux/classify-intent "добавь фичу"))]
    (assert (not (ux/is-disruptive-to-user? i-fast true)) "fast-path is never disruptive even during active speech")
    (assert (ux/is-disruptive-to-user? i-dev true) "dev intent is held while user is actively speaking")
    (assert (not (ux/is-disruptive-to-user? i-dev false)) "dev intent is not disruptive when user is idle")
    true))

(df test-nudge-streak-and-interval [] -> Bool
  (let [(g0 (ng/make-initial-nudge-guard))
        (g1 (ng/record-task-outcome g0 "asex" false))
        (g2 (ng/record-task-outcome g1 "asex" false))
        (n-early (ng/evaluate-proactive-nudge g2 10000))
        (g3 (ng/record-task-outcome g2 "asex" false))
        (n-streak (ng/evaluate-proactive-nudge g3 70000))]
    (assert (not (option-is-some? n-early)) "streak of 2 should not fire nudge")
    (assert (option-is-some? n-streak) "streak of 3 with >60s elapsed should fire nudge")
    (let [(ev (option-unwrap n-streak))]
      (assert (= (.-reason ev) "failure-run") "nudge reason is failure-run")
      (assert (string-contains? (.-text ev) "failed 3 times") "nudge text reports 3 failures"))
    true))

(df test-nudge-guard-hold-and-release [] -> Bool
  (let [(g0 (ng/make-initial-nudge-guard))
        (g1 (ng/hold-disruptive-intent g0 "intent-01"))
        (g2 (ng/hold-disruptive-intent g1 "intent-02"))
        (drained-pair (ng/release-held-intents-on-idle g2))
        (g-cleared (pair-first drained-pair))
        (intents (pair-second drained-pair))]
    (assert (= (list-length (.-held-intent-ids g2)) 2) "two intents held")
    (assert (= (list-length intents) 2) "two intents drained on idle")
    (assert (= (list-length (.-held-intent-ids g-cleared)) 0) "guard queue empty after idle release")
    true))

(df run-all-ux-tests [] -> Bool
  (do
    (test-intent-classification)
    (test-focus-guard-disruption)
    (test-nudge-streak-and-interval)
    (test-nudge-guard-hold-and-release)
    true))

(run-all-ux-tests)
