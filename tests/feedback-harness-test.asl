(module asl-agent-tests/feedback-harness-test
  :d "Dual-polarity test suite for Feedback Harness dialogue progression, memory grounding, and Swarm DAG decomposition."
  :x [test-intent-contract-lifecycle
      test-intent-grounding-asn-serialization
      test-intent-decomposition-to-swarm-dag
      run-tests]
  :i [(feedback :a fb) (corridor :a corr) (task_dag :a dag)])

(df test-intent-contract-lifecycle [] -> Bool
  :d "Verifies intent contract transitions through dialogue stages to grounded state."
  (let [(c (corr/default-corridor "corr-01"))
        (contract (fb/make-intent-contract "intent-01" "Auth Refactor" "Migrate token storage" c))
        (grounded (fb/advance-dialogue-stage contract (fb/stage-grounded)))]
    (assert (.-is-grounded grounded) "c-fb-pos-001: contract grounded")
    (assert (not (.-is-grounded contract)) "c-fb-pos-001: initial not grounded")
    true))

(df test-intent-grounding-asn-serialization [] -> Bool
  :d "Verifies Explain-Once memory grounding serializes contract and corridor to persistent ASN."
  (let [(c (corr/default-corridor "corr-01"))
        (contract (fb/make-intent-contract "intent-01" "Auth Refactor" "Migrate token storage" c))
        (asn (fb/ground-intent-to-memory contract))]
    (assert (string-contains? asn "(:intent :id \"intent-01\"") "c-fb-pos-002: intent serialized")
    (assert (string-contains? asn ":grounded true") "c-fb-pos-002: grounded true in asn")
    (assert (not (= asn "")) "c-fb-pos-002: asn output not empty")
    true))

(df test-intent-decomposition-to-swarm-dag [] -> Bool
  :d "Verifies negotiated intent contract decomposes into valid 4-stage Swarm DAG with zero deadlocks."
  (let [(c (corr/default-corridor "corr-01"))
        (contract (fb/make-intent-contract "intent-01" "Auth Refactor" "Migrate token storage" c))
        (swarm-dag (fb/decompose-intent-to-dag contract))
        (ready (dag/get-ready-nodes swarm-dag))]
    (assert (= (list-length (.-nodes swarm-dag)) 4) "c-fb-pos-003: dag has 4 nodes")
    (assert (= (list-length ready) 1) "c-fb-pos-003: initial ready has 1 root node")
    (assert (not (dag/has-dag-deadlock? swarm-dag)) "c-fb-neg-001: zero deadlocks in swarm dag")
    true))

(df run-tests [] -> Bool
  :d "Executes all feedback harness test functions."
  (and (test-intent-contract-lifecycle)
       (and (test-intent-grounding-asn-serialization)
            (test-intent-decomposition-to-swarm-dag))))
