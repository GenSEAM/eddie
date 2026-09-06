(module asl-eddie/snapshot-test
  :d "Unit tests for git-mergeable textual snapshot engine."
  :x [test-snapshot-entity-formatting
      test-snapshot-sorting-serialization
      test-snapshot-diffing
      run-tests]
  :i [(snapshot :a snap)])

"run: (run-tests)"

(df test-snapshot-entity-formatting [] -> Bool
  (let [(e (snap/make-entity "req:001" (snap/kind-req) "Autonomous ReAct loop" "src/agent.asl:42"))
        (formatted (snap/format-entity e))]
    (and (>= (len formatted) 20)
         (== (snap/parse-kind "req") (snap/kind-req)))))

(df test-snapshot-sorting-serialization [] -> Bool
  (let [(e1 (snap/make-entity "req:002" (snap/kind-req) "TUI status bar" "src/tui.asl:10"))
        (e2 (snap/make-entity "dec:001" (snap/kind-decision) "ASL Native" "docs/ADR-001.md:1"))
        (g (snap/make-graph (list e1 e2) "v1.0"))
        (s (snap/serialize-graph g))]
    (>= (len s) 40)))

(df test-snapshot-diffing [] -> Bool
  (let [(e1 (snap/make-entity "req:001" (snap/kind-req) "Spec 1" "src/a.asl:1"))
        (e2 (snap/make-entity "req:002" (snap/kind-req) "Spec 2" "src/b.asl:1"))
        (g1 (snap/make-graph (list e1) "v1.0"))
        (g2 (snap/make-graph (list e1 e2) "v1.0"))
        (d (snap/diff-graphs g1 g2))]
    (== d 1)))

(df run-tests [] -> Bool
  (and (test-snapshot-entity-formatting)
       (and (test-snapshot-sorting-serialization)
            (test-snapshot-diffing))))
