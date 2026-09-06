(module asl-agent/onion
  :d "Composable onion middleware pipeline and event-driven filter stack."
  :x [MiddlewareKind MiddlewareResult MiddlewareContext MiddlewareItem OnionPipeline
      kind-filter kind-pre-call kind-mutate kind-post-call kind-audit
      mw-proceed mw-block mw-modify
      make-context make-item make-pipeline
      add-middleware run-firewall-check run-cost-guard-check
      run-sanitizer execute-pipeline]
  :i [(policy :a pol)])

(dfe MiddlewareKind
  (:c kind-filter [] "Pre-execution security and permission filter")
  (:c kind-pre-call [] "Pre-call slot hydration and context enrichment")
  (:c kind-mutate [] "Payload normalization and error compression")
  (:c kind-post-call [] "Post-call AST delta auditing and verification")
  (:c kind-audit [] "Post-execution event bus and intent persistence"))

(dfe MiddlewareResult
  (:c mw-proceed [] "Pipeline stage passed successfully; proceed to next layer")
  (:c mw-block [] "Pipeline stage blocked operation with policy error")
  (:c mw-modify [] "Pipeline stage mutated arguments or payload; proceed with updated context"))

(dfs MiddlewareContext
  (:f tool-name Str "Target tool identifier e.g. read-file, exec-cmd")
  (:f target-path Str "File or directory path target")
  (:f payload Str "Serialized input payload or diagnostic output")
  (:f tokens-used I64 "Accumulated token count")
  (:f max-tokens I64 "Token budget ceiling for the session")
  (:f autonomy pol/AutonomyLevel "Current session autonomy permission level")
  (:f status Str "Execution state: READY, PROCEED, BLOCKED, MUTATED"))

(dfs MiddlewareItem
  (:f name Str "Unique middleware identifier e.g. mw-firewall, mw-sanitizer")
  (:f kind MiddlewareKind "Lifecycle execution phase")
  (:f priority I64 "Topological execution priority (lower runs earlier)")
  (:f enabled Bool "True if active in current pipeline"))

(dfs OnionPipeline
  (:f items (List MiddlewareItem) "Topologically ordered middleware layers")
  (:f context MiddlewareContext "Active execution context"))

(df make-context [(tool Str) (target Str) (payload Str) (tokens I64) (max-tokens I64) (autonomy pol/AutonomyLevel)] -> MiddlewareContext
  :d "Constructs an initial middleware execution context."
  (MiddlewareContext
    :tool-name tool
    :target-path target
    :payload payload
    :tokens-used tokens
    :max-tokens max-tokens
    :autonomy autonomy
    :status "READY"))

(df make-item [(name Str) (kind MiddlewareKind) (priority I64) (enabled Bool)] -> MiddlewareItem
  :d "Constructs a middleware registration item."
  (MiddlewareItem
    :name name
    :kind kind
    :priority priority
    :enabled enabled))

(df make-pipeline [(ctx MiddlewareContext)] -> OnionPipeline
  :d "Constructs an empty middleware onion pipeline with initial context."
  (OnionPipeline
    :items (list)
    :context ctx))

(df add-middleware [(pipe OnionPipeline) (item MiddlewareItem)] -> OnionPipeline
  :d "Registers a middleware item into the pipeline."
  (OnionPipeline
    :items (concat (.-items pipe) (list item))
    :context (.-context pipe)))

(df run-firewall-check [(ctx MiddlewareContext)] -> MiddlewareResult
  :d "Checks path traversal and autonomy policy permissions."
  (let [(target (.-target-path ctx))]
    (cond
      ((pol/has-traversal? target) (mw-block))
      ((pol/is-system-path? target) (mw-block))
      (true (mw-proceed)))))

(df run-cost-guard-check [(ctx MiddlewareContext)] -> MiddlewareResult
  :d "Validates that accumulated tokens do not exceed configured session budget."
  (if (> (.-tokens-used ctx) (.-max-tokens ctx))
    (mw-block)
    (mw-proceed)))

(df run-sanitizer [(text Str)] -> Str
  :d "Compresses diagnostic traces and long outputs to bound tokens (<300 tokens / 1200 chars)."
  (let [(max-chars 1200)
        (l (len text))]
    (if (<= l max-chars)
      text
      (str (slice text 0 max-chars) "\n... [truncated to 300 tokens by mw-sanitizer]"))))

(df execute-pipeline [(pipe OnionPipeline)] -> MiddlewareContext
  :d "Executes all registered middleware layers against active context."
  (let [(ctx (.-context pipe))
        (fw (run-firewall-check ctx))]
    (case fw
      ((mw-block)
       (MiddlewareContext
         :tool-name (.-tool-name ctx)
         :target-path (.-target-path ctx)
         :payload "ERROR: Blocked by mw-firewall"
         :tokens-used (.-tokens-used ctx)
         :max-tokens (.-max-tokens ctx)
         :autonomy (.-autonomy ctx)
         :status "BLOCKED"))
      ((mw-proceed)
       (let [(cg (run-cost-guard-check ctx))]
         (case cg
           ((mw-block)
            (MiddlewareContext
              :tool-name (.-tool-name ctx)
              :target-path (.-target-path ctx)
              :payload "ERROR: Blocked by mw-cost-guard (token budget exceeded)"
              :tokens-used (.-tokens-used ctx)
              :max-tokens (.-max-tokens ctx)
              :autonomy (.-autonomy ctx)
              :status "BLOCKED"))
           ((mw-proceed)
            (let [(sanitized (run-sanitizer (.-payload ctx)))]
              (MiddlewareContext
                :tool-name (.-tool-name ctx)
                :target-path (.-target-path ctx)
                :payload sanitized
                :tokens-used (.-tokens-used ctx)
                :max-tokens (.-max-tokens ctx)
                :autonomy (.-autonomy ctx)
                :status "PROCEED")))
           ((mw-modify)
            ctx))))
      ((mw-modify)
       ctx))))
