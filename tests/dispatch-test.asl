(module asl-eddie/dispatch-test
  :d "Unit tests for canonical native tool dispatcher parity."
  :x [test-canonical-tool-enumeration
      test-dispatch-preload-and-health
      test-dispatch-knowledge-and-intent
      test-dispatch-exec-and-deref
      test-dispatch-blocked-traversal
      run-tests]
  :i [(dispatch :a disp) (policy :a pol)])

"run: (run-tests)"

(df test-canonical-tool-enumeration [] -> Bool
  (and (and (disp/is-canonical-tool? "eddie-preload")
            (disp/is-canonical-tool? "ast-patch"))
       (and (disp/is-canonical-tool? "eddie-health")
            (disp/is-canonical-tool? "exec-cmd"))))

(df test-dispatch-preload-and-health [] -> Bool
  (let [(r-pre (disp/dispatch-canonical-tool "eddie-preload" "src/app.asl" "" (pol/level-auto)))
        (r-hlth (disp/dispatch-canonical-tool "eddie-health" "src/app.asl" "" (pol/level-auto)))]
    (and (.-success r-pre)
         (.-success r-hlth))))

(df test-dispatch-knowledge-and-intent [] -> Bool
  (let [(r-kn (disp/dispatch-canonical-tool "knowledge-load" "zod@3" "export class Zod" (pol/level-auto)))
        (r-int (disp/dispatch-canonical-tool "intent-record" "dec:001" "ASL Native" (pol/level-auto)))]
    (and (.-success r-kn)
         (.-success r-int))))

(df test-dispatch-exec-and-deref [] -> Bool
  (let [(r-exec (disp/dispatch-canonical-tool "exec-cmd" "echo ok" "" (pol/level-auto)))
        (r-ptr (disp/dispatch-canonical-tool "ptr-deref" "b3-dom-01" "is_visible" (pol/level-auto)))]
    (and (.-success r-exec)
         (.-success r-ptr))))

(df test-dispatch-blocked-traversal [] -> Bool
  (let [(r-block (disp/dispatch-canonical-tool "ast-patch" "../etc/shadow" "" (pol/level-auto)))]
    (and (not (.-success r-block))
         (== (.-status r-block) "DENIED"))))

(df run-tests [] -> Bool
  (and (and (test-canonical-tool-enumeration)
            (test-dispatch-preload-and-health))
       (and (test-dispatch-knowledge-and-intent)
            (and (test-dispatch-exec-and-deref)
                 (test-dispatch-blocked-traversal)))))
