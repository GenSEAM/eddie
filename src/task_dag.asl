(module asl-agent/task-dag
  :d "Task Directed Acyclic Graph (DAG) orchestrator with topological dependency resolution, deadlock trapping, and model role routing."
  :x [TaskNodeStatus TaskNode TaskDAG
      node-pending node-ready node-in-progress node-completed node-failed node-blocked
      make-task-node make-task-dag find-node
      is-node-completed? are-deps-satisfied? get-completed-node-ids get-ready-nodes
      mark-node-status mark-node-completed is-dag-complete? has-dag-deadlock? format-dag-summary]
  :i [])

(dfe TaskNodeStatus
  (:c node-pending [] "Awaiting dependency completion")
  (:c node-ready [] "All dependencies satisfied, unblocked for worker execution")
  (:c node-in-progress [] "Currently claimed and actively running")
  (:c node-completed [] "Successfully executed and verified against gates")
  (:c node-failed [] "Execution or gate verification failed")
  (:c node-blocked [] "Blocked due to upstream failure or unresolvable constraint"))

(dfs TaskNode
  (:f id Str "Deterministic task identifier e.g. task-01")
  (:f title Str "Human-readable summary of work item")
  (:f role Str "Task operational role: design, coding, review, triage")
  (:f deps (List Str) "List of prerequisite task IDs that must complete first")
  (:f status TaskNodeStatus "Current lifecycle execution status")
  (:f assigned-model Str "Designated model identifier or empty string")
  (:f receipt Str "Verification outcome or diagnostics receipt"))

(dfs TaskDAG
  (:f id Str "Unique DAG orchestration plan identifier")
  (:f nodes (List TaskNode) "Collection of all task nodes comprising the DAG")
  (:f iteration I64 "Monotonic execution cycle counter"))

(df make-task-node [(id Str) (title Str) (role Str) (deps (List Str))] -> TaskNode
  :d "Constructs an initialized TaskNode in pending state."
  (TaskNode
    :id id
    :title title
    :role role
    :deps deps
    :status (node-pending)
    :assigned-model ""
    :receipt ""))

(df make-task-dag [(id Str) (nodes (List TaskNode))] -> TaskDAG
  :d "Constructs an initialized TaskDAG container."
  (TaskDAG
    :id id
    :nodes nodes
    :iteration 0))

(df is-node-completed? [(node TaskNode)] -> Bool
  :d "Returns true if node has successfully settled in completed state."
  (mt (.-status node)
    ((node-completed) true)
    ((node-pending) false)
    ((node-ready) false)
    ((node-in-progress) false)
    ((node-failed) false)
    ((node-blocked) false)))

(df is-node-in-flight? [(node TaskNode)] -> Bool
  :d "Returns true if node is actively running or ready."
  (mt (.-status node)
    ((node-in-progress) true)
    ((node-ready) true)
    ((node-pending) false)
    ((node-completed) false)
    ((node-failed) false)
    ((node-blocked) false)))

(df find-node [(dag TaskDAG) (node-id Str)] -> (Option TaskNode)
  :d "Locates a node by ID within the DAG."
  (let [(nodes (.-nodes dag))
        (matched (fold (fn [(acc (Option TaskNode)) (n TaskNode)] -> (Option TaskNode)
                         (mt acc
                           ((some _) acc)
                           ((none) (if (= (.-id n) node-id) (some n) (none)))))
                       (none)
                       nodes))]
    matched))

(df get-completed-node-ids [(dag TaskDAG)] -> (List Str)
  :d "Returns list of IDs for all nodes currently in completed state."
  (fold (fn [(acc (List Str)) (n TaskNode)] -> (List Str)
          (if (is-node-completed? n)
            (list-cons (.-id n) acc)
            acc))
        (list)
        (.-nodes dag)))

(df are-deps-satisfied? [(node TaskNode) (completed-ids (List Str))] -> Bool
  :d "Checks if all dependencies of the given node exist in the completed IDs list."
  (let [(dependencies (.-deps node))]
    (if (list-empty? dependencies)
      true
      (fold (fn [(all-ok Bool) (dep-id Str)] -> Bool
              (if (not all-ok)
                false
                (let [(has-dep (fold (fn [(found Bool) (done-id Str)] -> Bool
                                       (if found true (= dep-id done-id)))
                                     false
                                     completed-ids))]
                  has-dep)))
            true
            dependencies))))

(df get-ready-nodes [(dag TaskDAG)] -> (List TaskNode)
  :d "Returns all pending or ready nodes whose dependencies are completely satisfied."
  (let [(completed (get-completed-node-ids dag))]
    (fold (fn [(acc (List TaskNode)) (n TaskNode)] -> (List TaskNode)
            (mt (.-status n)
              ((node-pending)
               (if (are-deps-satisfied? n completed)
                 (list-cons (TaskNode
                              :id (.-id n)
                              :title (.-title n)
                              :role (.-role n)
                              :deps (.-deps n)
                              :status (node-ready)
                              :assigned-model (.-assigned-model n)
                              :receipt (.-receipt n))
                            acc)
                 acc))
              ((node-ready) (list-cons n acc))
              ((node-in-progress) acc)
              ((node-completed) acc)
              ((node-failed) acc)
              ((node-blocked) acc)))
          (list)
          (.-nodes dag))))

(df mark-node-status [(dag TaskDAG) (node-id Str) (status TaskNodeStatus) (receipt Str)] -> TaskDAG
  :d "Updates the status and receipt of a specific task node."
  (let [(updated-nodes (fold (fn [(acc (List TaskNode)) (n TaskNode)] -> (List TaskNode)
                               (if (= (.-id n) node-id)
                                 (list-cons (TaskNode
                                              :id (.-id n)
                                              :title (.-title n)
                                              :role (.-role n)
                                              :deps (.-deps n)
                                              :status status
                                              :assigned-model (.-assigned-model n)
                                              :receipt receipt)
                                            acc)
                                 (list-cons n acc)))
                             (list)
                             (.-nodes dag)))]
    (TaskDAG
      :id (.-id dag)
      :nodes (reverse updated-nodes)
      :iteration (+ (.-iteration dag) 1))))

(df mark-node-completed [(dag TaskDAG) (node-id Str) (receipt Str)] -> TaskDAG
  :d "Marks a specific node as successfully completed with evidence receipt."
  (mark-node-status dag node-id (node-completed) receipt))

(df is-dag-complete? [(dag TaskDAG)] -> Bool
  :d "Returns true when every single node in the DAG has completed successfully."
  (fold (fn [(all-done Bool) (n TaskNode)] -> Bool
          (and all-done (is-node-completed? n)))
        true
        (.-nodes dag)))

(df has-dag-deadlock? [(dag TaskDAG)] -> Bool
  :d "Detects cyclic stalls where unfinished nodes exist but zero nodes can advance."
  (if (is-dag-complete? dag)
    false
    (let [(ready (get-ready-nodes dag))
          (has-in-flight (fold (fn [(acc Bool) (n TaskNode)] -> Bool
                                 (or acc (is-node-in-flight? n)))
                               false
                               (.-nodes dag)))]
      (and (list-empty? ready) (not has-in-flight)))))

(df format-dag-summary [(dag TaskDAG)] -> Str
  :d "Renders compact token-efficient status summary of all nodes in DAG."
  (let [(total (list-length (.-nodes dag)))
        (done (list-length (get-completed-node-ids dag)))
        (ready (list-length (get-ready-nodes dag)))]
    (str "DAG [" (.-id dag) "]: " (string-from-int64 done) "/" (string-from-int64 total) " completed, " (string-from-int64 ready) " ready")))
