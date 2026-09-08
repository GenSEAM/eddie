(module asl-agent-tests/task-dag-test
  :d "Dual-polarity test suite for task DAG orchestration, ready queue, and cycle/deadlock detection."
  :x [test-dag-creation-and-ready-queue
      test-dag-topological-advancement
      test-dag-deadlock-detection
      test-dag-completion
      run-tests]
  :i [(task_dag :a dag)])

(df test-dag-creation-and-ready-queue [] -> Bool
  :d "Verifies initial DAG ready queue unblocks root nodes with zero dependencies."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (t2 (dag/make-task-node "t2" "Child task" "coding" (list "t1")))
        (d (dag/make-task-dag "dag-1" (list t1 t2)))
        (ready (dag/get-ready-nodes d))]
    (assert-case "c-dag-pos-001" (= (list-length ready) 1))
    (refute-case "c-dag-pos-001" (list-empty? ready))
    true))

(df test-dag-topological-advancement [] -> Bool
  :d "Verifies completing root node unblocks dependent child task in ready queue."
  (let [(t1 (dag/make-task-node "t1" "Root task" "triage" (list)))
        (t2 (dag/make-task-node "t2" "Child task" "coding" (list "t1")))
        (d (dag/make-task-dag "dag-1" (list t1 t2)))
        (d2 (dag/mark-node-completed d "t1" "receipt: ok"))
        (ready (dag/get-ready-nodes d2))]
    (assert-case "c-dag-pos-002" (= (list-length ready) 1))
    (refute-case "c-dag-pos-002" (= (list-length (dag/get-completed-node-ids d2)) 0))
    true))

(df test-dag-deadlock-detection [] -> Bool
  :d "Verifies circular dependencies or unmet prerequisites are caught as deadlocks."
  (let [(t1 (dag/make-task-node "t1" "Cycle 1" "coding" (list "t2")))
        (t2 (dag/make-task-node "t2" "Cycle 2" "coding" (list "t1")))
        (cyclic-dag (dag/make-task-dag "dag-cyclic" (list t1 t2)))
        (clean-root (dag/make-task-node "root" "Clean root" "triage" (list)))
        (clean-dag (dag/make-task-dag "dag-clean" (list clean-root)))]
    (assert-case "c-dag-neg-001" (dag/has-dag-deadlock? cyclic-dag))
    (refute-case "c-dag-neg-001" (dag/has-dag-deadlock? clean-dag))
    true))

(df test-dag-completion [] -> Bool
  :d "Verifies DAG complete predicate reports true only when all nodes have settled."
  (let [(t1 (dag/make-task-node "t1" "Single task" "triage" (list)))
        (d (dag/make-task-dag "dag-done" (list t1)))
        (d-done (dag/mark-node-completed d "t1" "receipt: ok"))]
    (assert (dag/is-dag-complete? d-done))
    (refute (dag/is-dag-complete? d))
    true))

(df run-tests [] -> Bool
  :d "Executes all task DAG test functions."
  (and (test-dag-creation-and-ready-queue)
       (and (test-dag-topological-advancement)
            (and (test-dag-deadlock-detection)
                 (test-dag-completion)))))
