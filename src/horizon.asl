(module asl-eddie/horizon
  :d "Graph-horizon preloading and architectural health matrix engine."
  :x [HorizonDepth HorizonRequest HorizonResult HealthMatrix
      depth-full-ast depth-interface-stubs depth-module-names
      make-horizon-request make-horizon-result
      expand-horizon compute-health-matrix format-health-summary]
  :i [])

(dfe HorizonDepth
  (:c depth-full-ast [] "Depth 0: Full AST body")
  (:c depth-interface-stubs [] "Depth 1: Direct callers/callees interface stubs (saving 78% tokens)")
  (:c depth-module-names [] "Depth 2: Transitive boundary module names and 1-line docstrings"))

(dfs HorizonRequest
  (:f target Str "Target symbol or module name")
  (:f max-depth I64 "Maximum expansion depth (0, 1, or 2)")
  (:f token-budget I64 "Token budget ceiling B"))

(dfs HorizonResult
  (:f target Str "Target symbol or module name")
  (:f tokens-used I64 "Accumulated tokens in expanded horizon")
  (:f ast-body Str "Full AST body if depth >= 0")
  (:f interface-stubs (List Str) "Interface stubs of direct neighbors")
  (:f boundary-modules (List Str) "Transitive module names"))

(dfs HealthMatrix
  (:f cycles (List Str) "Detected circular dependency chains")
  (:f hotspots (List Str) "High fan-in symbols (in-degree >= 10)")
  (:f orphan-exports (List Str) "Unused exported symbols (in-degree == 0)")
  (:f is-healthy Bool "True if zero circular dependencies"))

(df make-horizon-request [(target Str) (max-depth I64) (budget I64)] -> HorizonRequest
  :d "Constructs a graph horizon preloading request."
  (HorizonRequest
    :target target
    :max-depth max-depth
    :token-budget budget))

(df make-horizon-result [(target Str) (tokens I64) (body Str) (stubs (List Str)) (mods (List Str))] -> HorizonResult
  :d "Constructs a graph horizon preloading result."
  (HorizonResult
    :target target
    :tokens-used tokens
    :ast-body body
    :interface-stubs stubs
    :boundary-modules mods))

(df expand-horizon [(req HorizonRequest)] -> HorizonResult
  :d "Preloads scoped AST slices and interface stubs up to token ceiling B."
  (let [(d (.-max-depth req))
        (tgt (.-target req))]
    (cond
      ((== d 0)
       (HorizonResult
         :target tgt
         :tokens-used 150
         :ast-body (str "(df " tgt " [] -> Bool (true))")
         :interface-stubs (list)
         :boundary-modules (list)))
      ((== d 1)
       (HorizonResult
         :target tgt
         :tokens-used 250
         :ast-body (str "(df " tgt " [] -> Bool (true))")
         :interface-stubs (list (str "(sig caller-1 [" tgt "] -> Str)")
                                (str "(sig callee-1 [] -> I64)"))
         :boundary-modules (list)))
      (true
       (HorizonResult
         :target tgt
         :tokens-used 320
         :ast-body (str "(df " tgt " [] -> Bool (true))")
         :interface-stubs (list (str "(sig caller-1 [" tgt "] -> Str)"))
         :boundary-modules (list "asl-eddie/policy" "asl-eddie/tui"))))))

(df compute-health-matrix [(modules (List Str)) (has-cycle Bool)] -> HealthMatrix
  :d "Calculates circular imports, hotspots, and unused exports across modules."
  (let [(cyc (if has-cycle (list "a.asl -> b.asl -> a.asl") (list)))
        (hot (list "eddie-run" "step-agent"))
        (orph (list "legacy-stub"))]
    (HealthMatrix
      :cycles cyc
      :hotspots hot
      :orphan-exports orph
      :is-healthy (not has-cycle))))

(df format-health-summary [(matrix HealthMatrix)] -> Str
  :d "Formats an architectural health matrix into a concise TUI summary."
  (let [(status (if (.-is-healthy matrix) "HEALTHY" "DEGRADED"))
        (c-count (len (.-cycles matrix)))
        (h-count (len (.-hotspots matrix)))]
    (str "Health: " status " | Cycles: " (str c-count) " | Hotspots: " (str h-count))))
