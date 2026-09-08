(module asl-agent-tests/task-dag-test
  :d "Dual-polarity test suite for task DAG orchestration, ready queue, and cycle/deadlock detection."
  :x [test-dag-creation-and-ready-queue
      test-dag-topological-advancement
      test-dag-deadlock-detection
      test-dag-completion
      test-dag-status-strings
      test-dag-boxart-rendering
      test-dag-vdom-rendering
      run-tests]
  :i [(task_dag :a dag)])

(df test-dag-creation-and-ready-queue [] -> Bool
  :d "Verifies initial DAG ready queue unblocks root nodes with zero dependencies."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (t2 (dag/make-task-node "t2" "Child task" "coding" (list "t1")))
        (d (dag/make-task-dag "dag-1" (list t1 t2)))
        (ready (dag/get-ready-nodes d))]
    (assert (= (list-length ready) 1) "c-dag-pos-001: ready has 1 root node")
    (assert (not (list-empty? ready)) "c-dag-pos-001: ready queue not empty")
    true))

(df test-dag-topological-advancement [] -> Bool
  :d "Verifies completing root node unblocks dependent child task in ready queue."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (t2 (dag/make-task-node "t2" "Child task" "coding" (list "t1")))
        (d (dag/make-task-dag "dag-1" (list t1 t2)))
        (d2 (dag/mark-node-completed d "t1" "receipt: ok"))
        (ready (dag/get-ready-nodes d2))]
    (assert (= (list-length ready) 1) "c-dag-pos-002: child task unblocked")
    (assert (not (= (list-length (dag/get-completed-node-ids d2)) 0)) "c-dag-pos-002: completed nodes present")
    true))

(df test-dag-deadlock-detection [] -> Bool
  :d "Verifies circular dependencies or unmet prerequisites are caught as deadlocks."
  (let [(t1 (dag/make-task-node "t1" "Cycle 1" "coding" (list "t2")))
        (t2 (dag/make-task-node "t2" "Cycle 2" "coding" (list "t1")))
        (cyclic-dag (dag/make-task-dag "dag-cyclic" (list t1 t2)))
        (clean-root (dag/make-task-node "root" "Clean root" "triage" (list)))
        (clean-dag (dag/make-task-dag "dag-clean" (list clean-root)))]
    (assert (dag/has-dag-deadlock? cyclic-dag) "c-dag-neg-001: cyclic dag deadlocked")
    (assert (not (dag/has-dag-deadlock? clean-dag)) "c-dag-neg-001: clean dag not deadlocked")
    true))

(df test-dag-completion [] -> Bool
  :d "Verifies DAG complete predicate reports true only when all nodes have settled."
  (let [(t1 (dag/make-task-node "t1" "Single task" "triage" (list)))
        (d (dag/make-task-dag "dag-done" (list t1)))
        (d-done (dag/mark-node-completed d "t1" "receipt: ok"))]
    (assert (dag/is-dag-complete? d-done) "dag is complete")
    (assert (not (dag/is-dag-complete? d)) "partial dag is not complete")
    true))

(df test-dag-status-strings [] -> Bool
  :d "Verifies node status conversion to canonical strings."
  (let [(s1 (dag/node-status-to-string (dag/node-pending)))
        (s2 (dag/node-status-to-string (dag/node-completed)))]
    (assert (= s1 "pending") "c-dag-status-001: pending matches")
    (assert (= s2 "completed") "c-dag-status-002: completed matches")
    (assert (not (= s1 s2)) "c-dag-status-neg-001: states distinct")
    true))

(df test-dag-boxart-rendering [] -> Bool
  :d "Verifies TaskDAG Unicode box-art rendering."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (t2 (dag/make-task-node "t2" "Child task" "coding" (list "t1")))
        (d (dag/make-task-dag "dag-render" (list t1 t2)))
        (art (dag/render-task-dag-boxart d))]
    (assert (string-contains? art "t1 : Root task") "c-dag-box-001: contains t1")
    (assert (string-contains? art "t2 : Child task") "c-dag-box-002: contains t2")
    (assert (string-contains? art "▼") "c-dag-box-003: contains directed arrow")
    (assert (not (string-empty? art)) "c-dag-box-neg-001: art not empty")
    true))

(df test-dag-vdom-rendering [] -> Bool
  :d "Verifies TaskDAG declarative VDOM ASN S-expression rendering."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (d (dag/make-task-dag "dag-vdom" (list t1)))
        (vdom (dag/render-task-dag-vdom-asn d))]
    (assert (string-contains? vdom "(:div :class \"task-dag\"") "c-dag-vdom-001: root div class")
    (assert (string-contains? vdom ":data-dag-id \"dag-vdom\"") "c-dag-vdom-002: data-dag-id present")
    (assert (string-contains? vdom "(:span :class \"node-title\" \"Root task\")") "c-dag-vdom-003: node title present")
    (assert (not (string-contains? vdom ":data-complete true")) "c-dag-vdom-neg-001: incomplete dag")
    true))

(df run-tests [] -> Bool
  :d "Executes all task DAG test functions."
  (and (test-dag-creation-and-ready-queue)
       (and (test-dag-topological-advancement)
            (and (test-dag-deadlock-detection)
                 (and (test-dag-completion)
                      (and (test-dag-status-strings)
                           (and (test-dag-boxart-rendering)
                                (test-dag-vdom-rendering))))))))
