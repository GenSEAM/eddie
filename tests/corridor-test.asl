(module asl-agent-tests/corridor-test
  :d "Dual-polarity test suite for Freedom Corridor boundary defense, invariant enforcement, and ASN serialization."
  :x [test-corridor-creation-and-defaults
      test-corridor-boundary-defense
      test-corridor-asn-serialization
      run-tests]
  :i [(corridor :a corr)])

(df test-corridor-creation-and-defaults [] -> Bool
  :d "Verifies default corridor constructor populates immutable invariants and exploration freedoms."
  (let [(c (corr/default-corridor "corr-01"))]
    (assert (= (list-length (.-immutable-invariants c)) 4) "c-corr-pos-001: default invariants count is 4")
    (assert (not (list-empty? (.-allowed-explorations c))) "c-corr-pos-001: allowed explorations not empty")
    true))

(df test-corridor-boundary-defense [] -> Bool
  :d "Verifies corridor rejects gate weakening and comment violations while permitting AST refactoring."
  (let [(c (corr/default-corridor "corr-01"))
        (ok-action (corr/is-action-permitted-by-corridor? c "ast refactoring of functions" "src/agent.asl"))
        (bad-gate (corr/is-action-permitted-by-corridor? c "weaken verification gate assertions" "src/gate.asl"))
        (bad-comment (corr/is-action-permitted-by-corridor? c "add comment explaining algorithm" "src/agent.asl"))]
    (assert ok-action "c-corr-neg-001: ast refactoring permitted")
    (assert (not bad-gate) "c-corr-neg-001: gate weakening rejected")
    (assert (not bad-comment) "c-corr-neg-001: comments rejected")
    true))

(df test-corridor-asn-serialization [] -> Bool
  :d "Verifies canonical ASN serialization formats balanced S-expression with all constraints."
  (let [(c (corr/default-corridor "corr-01"))
        (asn (corr/corridor-to-asn c))]
    (assert (string-contains? asn "(:corridor :id \"corr-01\"") "corridor serialized cleanly")
    (assert (not (= asn "")) "corridor serialization not empty")
    true))

(df run-tests [] -> Bool
  :d "Executes all corridor test functions."
  (and (test-corridor-creation-and-defaults)
       (and (test-corridor-boundary-defense)
            (test-corridor-asn-serialization))))
