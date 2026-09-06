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
  (let [(raw-prompt "Hello! Could you please help me refactor the database module?")
        (refined (fb/refine-user-prompt raw-prompt))
        (st0 (vmm/make-vmm-state "Constitution: No foreign code" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "sqlite3" "export function open()"))
        (st2 (vmm/vmm-offload-knowledge st1 "sqlite3" "src/db.asl:10"))]
    (and (not (.-is-ambiguous refined))
         (and (== (.-tokens (get (.-slots st2) 2)) 0)
              (> (len (.-payload (get (.-slots st2) 1))) 0)))))

(df test-e2e-onion-pipeline-and-horizon [] -> Bool
  (let [(ctx (on/make-context "read-file" "src/db.asl" "code content" 50 2000 (pol/level-auto)))
        (pipe (on/make-pipeline ctx))
        (res (on/execute-pipeline pipe))
        (req (hor/make-horizon-request "db/open" 1 500))
        (h-res (hor/expand-horizon req))
        (matrix (hor/compute-health-matrix (list "db") false))]
    (and (== (.-status res) "PROCEED")
         (and (<= (.-tokens-used h-res) 500)
              (.-is-healthy matrix)))))

(df test-e2e-canonical-dispatch-and-supervisor [] -> Bool
  (let [(r1 (disp/dispatch-canonical-tool "eddie-preload" "src/db.asl" "" (pol/level-auto)))
        (r2 (disp/dispatch-canonical-tool "eddie-health" "src/db.asl" "" (pol/level-auto)))
        (r3 (disp/dispatch-canonical-tool "exec-cmd" "echo ok" "" (pol/level-auto)))
        (r4 (disp/dispatch-canonical-tool "ptr-deref" "b3-dom-01" "is_ready" (pol/level-auto)))
        (cfg (sup/make-supervisor-config 10000 900000 true))
        (sup-res (sup/execute-supervised "asl test db-test.asl" 1000 cfg))]
    (and (and (.-success r1) (.-success r2))
         (and (and (.-success r3) (.-success r4))
              (not (.-is-deadlock sup-res))))))

(df test-e2e-snapshot-and-cli-inference [] -> Bool
  (let [(ent (snap/make-entity "req:db-01" (snap/kind-req) "ACID transactions" "src/db.asl:1"))
        (graph (snap/make-graph (list ent) "v1.0"))
        (serialized (snap/serialize-graph graph))
        (inf-plan (cli/get-phased-config (cli/phase-plan)))
        (inf-ast (cli/get-phased-config (cli/phase-ast-patch)))
        (help (cli/format-cli-help))]
    (and (>= (len serialized) 20)
         (and (== (.-thinking-budget inf-plan) 2048)
              (and (== (.-thinking-budget inf-ast) 0)
                   (>= (len help) 50))))))

(df run-tests [] -> Bool
  (and (and (test-e2e-feedback-and-vmm-hydration)
            (test-e2e-onion-pipeline-and-horizon))
       (and (test-e2e-canonical-dispatch-and-supervisor)
            (test-e2e-snapshot-and-cli-inference))))
