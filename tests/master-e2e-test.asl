(module asl-agent/master-e2e-test
  :d "Comprehensive end-to-end integration test verifying all subsystems of SPEC-2026-EDDIE-SYSTEM-v3.0."
  :x [test-e2e-feedback-and-vmm-hydration
      test-e2e-onion-pipeline-and-horizon
      test-e2e-canonical-dispatch-and-supervisor
      test-e2e-snapshot-and-cli-inference
      run-tests]
  :i [(policy :a pol)
      (tui :a tui)
      (feedback :a fb)
      (onion :a on)
      (snapshot :a snap)
      (vmm :a vmm)
      (horizon :a hor)
      (supervisor :a sup)
      (copilot :a cop)
      (dispatch :a disp)
      (cli :a cli)])

"run: (run-tests)"

(df test-e2e-feedback-and-vmm-hydration [] -> Bool
  (let [(raw-prompt "Please refactor src/db.asl to use transactions.")
        (refined (fb/refine-user-prompt raw-prompt (list "src/db.asl")))
        (st0 (vmm/make-vmm-state "Constitution: No foreign code" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "sqlite3" "export function open()"))
        (st2 (vmm/vmm-offload-knowledge st1 "sqlite3" "src/db.asl:10"))]
    (assert (not (.-is-ambiguous refined)) "refined prompt is not ambiguous")
    (assert (= (.-tokens (get (.-slots st2) 2)) 0) "slot 2 tokens cleared")
    (assert (> (string-length (.-payload (get (.-slots st2) 1))) 0) "slot 1 receipt payload non-empty")
    true))

(df test-e2e-onion-pipeline-and-horizon [] -> Bool
  (let [(ctx (on/make-context "read-file" "src/db.asl" "code content" 50 2000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))
        (req (hor/make-horizon-request "db/open" 1 500))
        (h-res (hor/expand-horizon req))
        (matrix (hor/compute-health-matrix (list "db") false))]
    (assert (= (.-status res) "PROCEED") "status is PROCEED")
    (assert (<= (.-tokens-used h-res) 500) "tokens used within 500")
    (assert (.-is-healthy matrix) "matrix is healthy")
    true))

(df test-e2e-canonical-dispatch-and-supervisor [] -> Bool
  (let [(r1 (disp/dispatch-canonical-tool "eddie-preload" "src/db.asl" "" (pol/level-auto)))
        (r2 (disp/dispatch-canonical-tool "eddie-health" "src/db.asl" "" (pol/level-auto)))
        (r3 (disp/dispatch-canonical-tool "exec-cmd" "echo ok" "" (pol/level-auto)))
        (r4 (disp/dispatch-canonical-tool "ptr-deref" "b3-dom-01" "is_ready" (pol/level-auto)))
        (cfg (sup/make-supervisor-config 10000 900000 true))
        (sup-res (sup/execute-supervised "asl test db-test.asl" 1000 cfg))]
    (assert (.-success r1) "dispatch preload success")
    (assert (.-success r2) "dispatch health success")
    (assert (.-success r3) "dispatch exec-cmd success")
    (assert (.-success r4) "dispatch ptr-deref success")
    (assert (not (.-is-deadlock sup-res)) "supervised execution not deadlocked")
    true))

(df test-e2e-snapshot-and-cli-inference [] -> Bool
  (let [(ent (snap/make-entity "req:db-01" (snap/kind-req) "ACID transactions" "src/db.asl:1"))
        (graph (snap/make-graph (list ent) "v1.0"))
        (serialized (snap/serialize-graph graph))
        (inf-plan (cli/get-phased-config (cli/phase-plan)))
        (inf-ast (cli/get-phased-config (cli/phase-ast-patch)))
        (help (cli/format-cli-help))]
    (assert (>= (string-length serialized) 20) "serialized graph length >= 20")
    (assert (= (.-thinking-budget inf-plan) 2048) "plan thinking budget 2048")
    (assert (= (.-thinking-budget inf-ast) 0) "ast thinking budget 0")
    (assert (>= (string-length help) 50) "cli help length >= 50")
    true))

(df run-tests [] -> Bool
  (do
    (test-e2e-feedback-and-vmm-hydration)
    (test-e2e-onion-pipeline-and-horizon)
    (test-e2e-canonical-dispatch-and-supervisor)
    (test-e2e-snapshot-and-cli-inference)
    true))
