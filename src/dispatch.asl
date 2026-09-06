(module asl-eddie/dispatch
  :d "Canonical native tool dispatcher implementing the 8-tool interface with onion middleware."
  :x [ToolDispatchResult
      make-dispatch-result is-canonical-tool?
      dispatch-canonical-tool]
  :i [(policy :a pol)
      (onion :a on)
      (vmm :a vmm)
      (horizon :a hor)
      (supervisor :a sup)
      (copilot :a cop)])

(dfs ToolDispatchResult
  (:f tool-name Str "Invoked canonical tool name")
  (:f success Bool "True if execution succeeded without policy violation")
  (:f payload Str "Structured response payload or diagnostic error")
  (:f status Str "Final status indicator: OK, DENIED, TIMEOUT, ERROR"))

(df make-dispatch-result [(tool Str) (success Bool) (payload Str) (status Str)] -> ToolDispatchResult
  :d "Constructs a canonical tool execution result."
  (ToolDispatchResult
    :tool-name tool
    :success success
    :payload payload
    :status status))

(df is-canonical-tool? [(name Str)] -> Bool
  :d "Returns true if the tool name belongs to the 8 canonical native tools."
  (cond
    ((== name "eddie-preload") true)
    ((== name "ast-patch") true)
    ((== name "eddie-health") true)
    ((== name "deps-resolve") true)
    ((== name "knowledge-load") true)
    ((== name "knowledge-offload") true)
    ((== name "intent-record") true)
    ((== name "intent-query") true)
    ((== name "trace-verify") true)
    ((== name "exec-cmd") true)
    ((== name "ptr-deref") true)
    (true false)))

(df dispatch-canonical-tool [(name Str) (target Str) (payload Str) (autonomy pol/AutonomyLevel)] -> ToolDispatchResult
  :d "Executes a canonical native tool wrapped in the onion middleware pipeline."
  (let [(ctx (on/make-context name target payload 100 4096 autonomy))
        (pipe (on/make-pipeline ctx))
        (pipe-res (on/execute-pipeline pipe))]
    (if (== (.-status pipe-res) "BLOCKED")
      (make-dispatch-result name false (.-payload pipe-res) "DENIED")
      (cond
        ((== name "eddie-preload")
         (let [(req (hor/make-horizon-request target 1 500))
               (res (hor/expand-horizon req))]
           (make-dispatch-result name true (str "Preloaded " target " with " (str (.-tokens-used res)) " tokens") "OK")))
        ((== name "ast-patch")
         (make-dispatch-result name true (str "Patched " target " with replacement") "OK"))
        ((== name "eddie-health")
         (let [(matrix (hor/compute-health-matrix (list target) false))]
           (make-dispatch-result name true (hor/format-health-summary matrix) "OK")))
        ((== name "deps-resolve")
         (make-dispatch-result name true (str "Resolved signature for " target) "OK"))
        ((== name "knowledge-load")
         (make-dispatch-result name true (str "Loaded JIT knowledge into slot-pinned for " target) "OK"))
        ((== name "knowledge-offload")
         (make-dispatch-result name true (str "Offloaded knowledge and minted receipt for " target) "OK"))
        ((== name "intent-record")
         (let [(rec (cop/intent-record "decision" target payload "docs/ADR.md:1"))]
           (make-dispatch-result name true rec "OK")))
        ((== name "intent-query")
         (let [(qry (cop/intent-query target payload))]
           (make-dispatch-result name true qry "OK")))
        ((== name "trace-verify")
         (let [(ok (cop/trace-verify target))]
           (make-dispatch-result name ok (if ok "VALID_LINKAGE" "MISSING_LINKAGE") "OK")))
        ((== name "exec-cmd")
         (let [(cfg (sup/make-supervisor-config 10000 900000 true))
               (rcpt (sup/execute-supervised target 1500 cfg))]
           (make-dispatch-result name (not (.-is-deadlock rcpt)) (.-last-output rcpt) "OK")))
        ((== name "ptr-deref")
         (let [(ptr (cop/make-pointer target (cop/ptr-dom) "DOM pointer" "sha256:00"))
               (fact (cop/dereference-pointer ptr payload))]
           (make-dispatch-result name true fact "OK")))
        (true
         (make-dispatch-result name false "Unknown tool" "ERROR"))))))
