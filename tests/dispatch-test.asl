(module asl-agent/dispatch-test
  :d "Unit tests for canonical native tool dispatcher parity."
  :x [test-canonical-tool-enumeration
      test-dispatch-preload-and-health
      test-dispatch-knowledge-and-intent
      test-dispatch-exec-and-deref
      test-dispatch-blocked-traversal
      run-tests]
  :i [(dispatch :a disp) (policy :a pol)])

(df test-canonical-tool-enumeration [] -> Bool
  (do
    (assert (disp/is-canonical-tool? "eddie-preload") "eddie-preload canonical")
    (assert (disp/is-canonical-tool? "ast-patch") "ast-patch canonical")
    (assert (disp/is-canonical-tool? "eddie-health") "eddie-health canonical")
    (assert (disp/is-canonical-tool? "exec-cmd") "exec-cmd canonical")
    true))

(df test-dispatch-preload-and-health [] -> Bool
  (let [(r-pre (disp/dispatch-canonical-tool "eddie-preload" "src/app.asl" "" (pol/level-auto)))
        (r-hlth (disp/dispatch-canonical-tool "eddie-health" "src/app.asl" "" (pol/level-auto)))]
    (assert (.-success r-pre) "preload success")
    (assert (.-success r-hlth) "health success")
    true))

(df test-dispatch-knowledge-and-intent [] -> Bool
  (let [(r-kn (disp/dispatch-canonical-tool "knowledge-load" "zod@3" "export class Zod" (pol/level-auto)))
        (r-int (disp/dispatch-canonical-tool "intent-record" "dec:001" "ASL Native" (pol/level-auto)))]
    (assert (.-success r-kn) "knowledge success")
    (assert (.-success r-int) "intent success")
    true))

(df test-dispatch-exec-and-deref [] -> Bool
  (let [(r-exec (disp/dispatch-canonical-tool "exec-cmd" "echo ok" "" (pol/level-auto)))
        (r-ptr (disp/dispatch-canonical-tool "ptr-deref" "b3-dom-01" "is_visible" (pol/level-auto)))]
    (assert (.-success r-exec) "exec success")
    (assert (.-success r-ptr) "deref success")
    true))

(df test-dispatch-blocked-traversal [] -> Bool
  (let [(r-block (disp/dispatch-canonical-tool "ast-patch" "../etc/shadow" "" (pol/level-auto)))]
    (assert (not (.-success r-block)) "blocked traversal")
    (assert (= (.-status r-block) "DENIED") "status DENIED")
    true))

(df run-tests [] -> Bool
  (do
    (assert (test-canonical-tool-enumeration) "test-canonical-tool-enumeration must pass")
    (assert (test-dispatch-preload-and-health) "test-dispatch-preload-and-health must pass")
    (assert (test-dispatch-knowledge-and-intent) "test-dispatch-knowledge-and-intent must pass")
    (assert (test-dispatch-exec-and-deref) "test-dispatch-exec-and-deref must pass")
    (assert (test-dispatch-blocked-traversal) "test-dispatch-blocked-traversal must pass")
    true))
