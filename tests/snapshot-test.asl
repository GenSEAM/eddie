(module asl-agent/snapshot-test
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
    (assert (>= (string-length formatted) 20) "entity formatted length >= 20")
    (assert (= (snap/parse-kind "req") (snap/kind-req)) "parsed kind matches")
    true))

(df test-snapshot-sorting-serialization [] -> Bool
  (let [(e1 (snap/make-entity "req:002" (snap/kind-req) "TUI status bar" "src/tui.asl:10"))
        (e2 (snap/make-entity "dec:001" (snap/kind-decision) "ASL Native" "docs/ADR-001.md:1"))
        (g (snap/make-graph (list e1 e2) "v1.0"))
        (s (snap/serialize-graph g))]
    (assert (>= (string-length s) 40) "serialized graph length >= 40")
    (assert (string-contains? s "req:002") "serialized graph contains req:002")
    true))

(df test-snapshot-diffing [] -> Bool
  (let [(e1 (snap/make-entity "req:001" (snap/kind-req) "Spec 1" "src/a.asl:1"))
        (e2 (snap/make-entity "req:002" (snap/kind-req) "Spec 2" "src/b.asl:1"))
        (g1 (snap/make-graph (list e1) "v1.0"))
        (g2 (snap/make-graph (list e1 e2) "v1.0"))
        (d (snap/diff-graphs g1 g2))]
    (assert (= d 1) "diff count is 1")
    (assert (not (= d 0)) "diff count is not 0")
    true))

(df test-snapshot-deserialization [] -> Bool
  (let [(e1 (snap/make-entity "req:001" (snap/kind-req) "Autonomous ReAct loop" "src/agent.asl:42"))
        (formatted (snap/format-entity e1))
        (g (snap/deserialize-graph formatted))
        (ents (.-entities g))]
    (assert (= (list-length ents) 1) "parsed entities length is 1")
    (let [(p1 (list-head ents))]
      (assert (option-some? p1) "parsed entity exists")
      (assert (= (.-id (option-unwrap p1)) "req:001") "id matches req:001")
      (assert (= (.-payload (option-unwrap p1)) "Autonomous ReAct loop") "payload matches")
      true)))

(df run-tests [] -> Bool
  (do
    (test-snapshot-entity-formatting)
    (test-snapshot-sorting-serialization)
    (test-snapshot-diffing)
    (test-snapshot-deserialization)
    true))
