(module asl-agent/model-router
  :d "Task-role model selection matrix with cognitive gateway routing, thinking budgets, and local SLM fallback."
  :x [TaskRole ModelEndpoint RoutingMatrix
      role-design role-coding role-review role-triage
      make-endpoint default-routing-matrix resolve-model-for-role format-route-decision]
  :i [])

(dfe TaskRole
  (:c role-design [] "Creative visual composition, UI architecture, and VDOM design")
  (:c role-coding [] "Deterministic code emission, AST editing, and assertion satisfaction")
  (:c role-review [] "Deep reasoning, gap analysis, pre-commit audit, and invariant defense")
  (:c role-triage [] "Zero-latency outline scanning, formatting, and lightweight routing"))

(dfs ModelEndpoint
  (:f model-id Str "Unique model identifier string")
  (:f base-url Str "Gateway HTTP endpoint URL")
  (:f temperature F64 "Sampling temperature float")
  (:f thinking-budget I64 "Token budget for reasoning or 0 for none")
  (:f is-local Bool "True if hosted locally via in-container gateway"))

(dfs RoutingMatrix
  (:f design-endpoint ModelEndpoint "Endpoint designated for creative and UI design")
  (:f coding-endpoint ModelEndpoint "Endpoint designated for code emission")
  (:f review-endpoint ModelEndpoint "Endpoint designated for deep audit and review")
  (:f triage-endpoint ModelEndpoint "Endpoint designated for triage and classification")
  (:f local-fallback ModelEndpoint "Reliable local SLM fallback when network is unavailable")
  (:f prefer-local Bool "Enforce local execution invariant across all roles"))

(df make-endpoint [(id Str) (url Str) (temp F64) (budget I64) (local Bool)] -> ModelEndpoint
  :d "Constructs an initialized ModelEndpoint record."
  (ModelEndpoint
    :model-id id
    :base-url url
    :temperature temp
    :thinking-budget budget
    :is-local local))

(df default-routing-matrix [] -> RoutingMatrix
  :d "Constructs standard production routing matrix with local Gemma 31B fallback."
  (let [(gateway-url "http://127.0.0.1:8765/v1")
        (local-gemma (make-endpoint "gemma-4-31b-it" gateway-url 0.1 0 true))
        (creative-design (make-endpoint "gemini-2.5-flash" gateway-url 0.4 0 false))
        (coding-impl (make-endpoint "gemma-4-31b-it" gateway-url 0.0 0 true))
        (deep-review (make-endpoint "gemini-2.5-pro" gateway-url 0.2 4096 false))
        (triage-fast (make-endpoint "gemma-4-31b-it" gateway-url 0.0 0 true))]
    (RoutingMatrix
      :design-endpoint creative-design
      :coding-endpoint coding-impl
      :review-endpoint deep-review
      :triage-endpoint triage-fast
      :local-fallback local-gemma
      :prefer-local false)))

(df resolve-model-for-role [(role TaskRole) (matrix RoutingMatrix) (offline Bool)] -> ModelEndpoint
  :d "Resolves the optimal model endpoint for a task role with seamless local fallback."
  (if (or offline (.-prefer-local matrix))
    (.-local-fallback matrix)
    (mt role
      ((role-design) (.-design-endpoint matrix))
      ((role-coding) (.-coding-endpoint matrix))
      ((role-review) (.-review-endpoint matrix))
      ((role-triage) (.-triage-endpoint matrix)))))

(df format-route-decision [(role TaskRole) (ep ModelEndpoint)] -> Str
  :d "Formats a concise routing decision descriptor."
  (let [(role-name (mt role
                     ((role-design) "design")
                     ((role-coding) "coding")
                     ((role-review) "review")
                     ((role-triage) "triage")))
        (loc-flag (if (.-is-local ep) "local" "cloud"))]
    (str "Role [" role-name "] routed to " (.-model-id ep) " (" loc-flag ", budget: " (string-from-int64 (.-thinking-budget ep)) ")")))
