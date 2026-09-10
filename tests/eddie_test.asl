(module asl-agent/test
  :d "Unit tests for EDDIE orchestrator in ASL"
  :x [test-fast-triage
      test-consult-and-refine
      test-plan-execution
      test-circuit-breaker
      test-version-banner
      run-tests]
  :i [(eddie :a ed)])

(df test-fast-triage [] -> Bool
  (let [(v-help (ed/fast-triage "help"))
        (v-code (ed/fast-triage "refactor app"))]
    (assert (= v-help (ed/consult)) "fast-triage help should yield consult")
    (assert (= v-code (ed/swarm)) "fast-triage code should yield swarm")
    true))

(df test-consult-and-refine [] -> Bool
  (let [(plan-ambig (ed/consult-and-refine "help" true))
        (plan-clear (ed/consult-and-refine "build compiler" false))]
    (assert (.-follow-up-needed plan-ambig) "ambiguous plan requires follow up")
    (assert (= (.-task-id plan-ambig) "addie-consult") "ambiguous task-id match")
    (assert (not (.-follow-up-needed plan-clear)) "clear plan does not require follow up")
    (assert (= (.-speculative-branches plan-clear) 2) "clear plan speculative branches")
    true))

(df test-plan-execution [] -> Bool
  (let [(plan (ed/plan-execution "task-001" "implement vector search"))]
    (assert (= (.-task-id plan) "task-001") "task-id matches")
    (assert (= (.-circuit-breaker-limit plan) 2) "circuit breaker limit")
    (assert (= (list-length (.-assigned-agents plan)) 3) "three agents assigned")
    true))

(df test-circuit-breaker [] -> Bool
  (do
    (assert (ed/evaluate-circuit-breaker 2 2) "circuit breaker fires at threshold")
    (assert (ed/evaluate-circuit-breaker 3 2) "circuit breaker fires above threshold")
    (assert (not (ed/evaluate-circuit-breaker 1 2)) "circuit breaker open below threshold")
    true))

(df test-version-banner [] -> Bool
  (do
    (assert (= (ed/addie-version) "0.1.0") "addie-version is 0.1.0")
    (assert (= (ed/eddie-version) "0.1.0") "eddie-version is 0.1.0")
    (assert (string-contains? (ed/addie-banner) "GSA (GenSEAM Agent)") "addie banner contains GSA")
    (assert (string-contains? (ed/eddie-banner) "GSA (GenSEAM Agent)") "eddie banner contains GSA")
    true))

(df run-tests [] -> Bool
  (do
    (test-fast-triage)
    (test-consult-and-refine)
    (test-plan-execution)
    (test-circuit-breaker)
    (test-version-banner)
    true))

(run-tests)
