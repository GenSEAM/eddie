(module asl-agent/test-ide-mesh
  :d "Unit verification test suite for Cross-IDE Mesh Orchestrator, Git Worktree Isolation, and Execution Receipts"
  :x [test-ide-runtime-conversions
      test-worktree-slot-lifecycle-and-collision
      test-ide-task-formatting
      test-ide-execution-receipt-and-aloud-status
      test-mesh-coordinator-state-machine
      run-all-mesh-tests]
  :i [(ide_mesh :a im)])

(df test-ide-runtime-conversions [] -> Bool
  (let [(c-code (im/ide-claude-code))
        (c-str (im/runtime-to-str c-code))
        (a-code (im/ide-antigravity))
        (a-str (im/runtime-to-str a-code))
        (n-code (im/ide-native-ad))
        (n-str (im/runtime-to-str n-code))
        (b-code (im/ide-cursor-bridge))
        (b-str (im/runtime-to-str b-code))]
    (assert (= c-str "claude-code") "claude-code string conversion")
    (assert (= a-str "antigravity") "antigravity string conversion")
    (assert (= n-str "native-ad") "native-ad string conversion")
    (assert (= b-str "cursor-bridge") "cursor-bridge string conversion")
    (let [(c-rt (im/str-to-runtime "claude-code"))
          (a-rt (im/str-to-runtime "antigravity"))
          (n-rt (im/str-to-runtime "native-ad"))
          (b-rt (im/str-to-runtime "other"))]
      (assert (= (im/runtime-to-str c-rt) "claude-code") "roundtrip claude-code")
      (assert (= (im/runtime-to-str a-rt) "antigravity") "roundtrip antigravity")
      (assert (= (im/runtime-to-str n-rt) "native-ad") "roundtrip native-ad")
      (assert (= (im/runtime-to-str b-rt) "cursor-bridge") "fallback cursor-bridge"))
    true))

(df test-worktree-slot-lifecycle-and-collision [] -> Bool
  (let [(slot1 (im/make-worktree-slot "T100" "/Users/dev/repo" 1773900000000))
        (slots (list slot1))
        (add-cmd (im/format-git-worktree-add slot1))
        (rm-cmd (im/format-git-worktree-remove slot1))]
    (assert (= (.-task-id slot1) "T100") "task-id stored correctly")
    (assert (= (.-branch-name slot1) "eddie/T100") "branch name matches eddie prefix")
    (assert (= (.-worktree-path slot1) "/Users/dev/repo/.worktrees/T100") "worktree directory isolated")
    (assert (im/has-worktree-collision? slots "T100") "detects existing active worktree collision")
    (refute (im/has-worktree-collision? slots "T101") "no collision for unallocated task")
    (assert (string-contains? add-cmd "git worktree add -b eddie/T100") "add command formats correctly")
    (assert (string-contains? rm-cmd "git worktree remove --force") "remove command formats correctly")
    true))

(df test-ide-task-formatting [] -> Bool
  (let [(t-claude (im/make-ide-task "T101" (im/ide-claude-code) "dev" "implement auth module" "/tmp/wt1" 1773900000000))
        (t-anti (im/make-ide-task "T102" (im/ide-antigravity) "mesh" "orchestrate test suites" "/tmp/wt2" 1773900000000))
        (cmd-claude (im/format-claude-cli-dispatch t-claude))
        (cmd-anti (im/format-antigravity-cli-dispatch t-anti))
        (asn-frame (im/format-hub-envelope-asn t-claude))]
    (assert (string-contains? cmd-claude "claude -p") "claude cli contains headless switch")
    (assert (string-contains? cmd-claude "/tmp/wt1") "claude cli targets isolated worktree")
    (assert (string-contains? cmd-anti "agy -p") "antigravity cli contains headless switch")
    (assert (string-contains? cmd-anti "orchestrate test suites") "antigravity cli includes prompt")
    (assert (string-contains? asn-frame ":mesh-envelope") "hub packet contains mesh envelope")
    (assert (string-contains? asn-frame ":runtime \"claude-code\"") "hub packet preserves runtime type")
    true))

(df test-ide-execution-receipt-and-aloud-status [] -> Bool
  (let [(r-ok (im/make-execution-receipt "T101" (im/ide-claude-code) 0 14 3 2450 "all tests pass"))
        (r-bad (im/make-execution-receipt "T102" (im/ide-antigravity) 1 0 1 1200 "syntax error in parser"))
        (aloud-ok (im/format-receipt-aloud r-ok))
        (aloud-bad (im/format-receipt-aloud r-bad))]
    (assert (im/is-receipt-falsified-and-green? r-ok) "receipt with 0 exit and >0 asserts is green")
    (refute (im/is-receipt-falsified-and-green? r-bad) "receipt with error code 1 is rejected")
    (assert (string-contains? aloud-ok "Task T101 verified on claude-code") "aloud renders success announcement")
    (assert (string-contains? aloud-ok "14 assertions green") "aloud reports non-vacuous assertion count")
    (assert (string-contains? aloud-bad "Task T102 failed on antigravity with exit code 1") "aloud reports process failure")
    true))

(df test-mesh-coordinator-state-machine [] -> Bool
  (let [(cfg (im/make-default-hub-config))
        (coord0 (im/make-mesh-coordinator cfg))
        (coord1 (im/allocate-task-worktree coord0 "T200" "/Users/dev/repo" 1000))
        (envelope (im/make-ide-task "T200" (im/ide-claude-code) "dev" "implement feature" "/Users/dev/repo/.worktrees/T200" 1000))
        (coord2 (im/dispatch-task-to-mesh coord1 envelope))]
    (assert (= (list-length (.-worktrees coord1)) 1) "worktree allocated")
    (assert (= (list-length (.-dispatched-tasks coord2)) 1) "task enqueued in dispatched queue")
    (let [(receipt (im/make-execution-receipt "T200" (im/ide-claude-code) 0 8 2 1500 "green"))
          (coord3 (im/record-task-settlement coord2 receipt))
          (status-asn (im/render-mesh-status-asn coord3))]
      (assert (= (list-length (.-worktrees coord3)) 0) "worktree freed upon settlement")
      (assert (= (list-length (.-dispatched-tasks coord3)) 0) "dispatched task cleared upon settlement")
      (assert (= (list-length (.-receipts coord3)) 1) "receipt retained in coordinator history")
      (assert (string-contains? status-asn ":settled 1") "status ASN reflects 1 settled task")
      (assert (string-contains? status-asn ":worktrees 0") "status ASN reflects 0 remaining worktrees"))
    true))

(df run-all-mesh-tests [] -> Bool
  (do
    (test-ide-runtime-conversions)
    (test-worktree-slot-lifecycle-and-collision)
    (test-ide-task-formatting)
    (test-ide-execution-receipt-and-aloud-status)
    (test-mesh-coordinator-state-machine)
    true))

(run-all-mesh-tests)
