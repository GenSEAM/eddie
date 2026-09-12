(module asl-agent/compose
  :d "The Third Reasoner: running multi-turn goal composition, open unresolved question pool, and assumed facts ledger."
  :x [UnresolvedNeed UnresolvedQuestion AssumedFact CompositionRecord
      make-unresolved-question
      make-assumed-fact
      make-empty-composition
      add-unresolved-question
      add-assumed-fact
      close-unresolved-question
      supersede-assumed-fact
      is-lookup-need?
      extract-pending-lookups
      resolve-lookup-question
      render-composition-context]
  :i [(asl-text/string :a s)])

(dfe UnresolvedNeed
  (:c operator [] "Only human operator can answer; subject to ask limits")
  (:c lookup [] "Public fact or repository code; investigated autonomously by scout agent"))

(dfs UnresolvedQuestion
  (:f id Str "Monotonic identifier (e.g. u1, u2)")
  (:f question Str "Concise description of the unknown detail")
  (:f need UnresolvedNeed "Categorical attribution: operator vs lookup")
  (:f seen-count Int64 "Number of turns survived unanswered")
  (:f asked-count Int64 "Number of times presented to operator"))

(dfs AssumedFact
  (:f id Str "Monotonic identifier (e.g. a1, a2)")
  (:f claim Str "Explicit working assumption adopted to proceed without waiting"))

(dfs CompositionRecord
  (:f goal Str "Consolidated multi-turn intent summary")
  (:f open-questions (List UnresolvedQuestion) "Active pool of open questions")
  (:f assumed-facts (List AssumedFact) "Active pool of working assumptions")
  (:f is-ready Bool "True if work can proceed without blocking on speaker")
  (:f missing Str "Short description of missing detail when is-ready is false"))

(df make-unresolved-question [(id Str) (question Str) (need UnresolvedNeed)] -> UnresolvedQuestion
  :d "Constructs an UnresolvedQuestion record"
  (UnresolvedQuestion
    :id id
    :question question
    :need need
    :seen-count 0
    :asked-count 0))

(df make-assumed-fact [(id Str) (claim Str)] -> AssumedFact
  :d "Constructs an AssumedFact record"
  (AssumedFact
    :id id
    :claim claim))

(df make-empty-composition [] -> CompositionRecord
  :d "Constructs an empty initial CompositionRecord"
  (CompositionRecord
    :goal ""
    :open-questions (list)
    :assumed-facts (list)
    :is-ready true
    :missing ""))

(df add-unresolved-question [(comp CompositionRecord) (q UnresolvedQuestion)] -> CompositionRecord
  :d "Appends an unresolved question to the composition pool, capped at 6 entries"
  (let [(current (.-open-questions comp))
        (updated (list-append current (list q)))
        (capped (if (> (list-length updated) 6) (list-take updated 6) updated))]
    (CompositionRecord
      :goal (.-goal comp)
      :open-questions capped
      :assumed-facts (.-assumed-facts comp)
      :is-ready (.-is-ready comp)
      :missing (.-missing comp))))

(df add-assumed-fact [(comp CompositionRecord) (fact AssumedFact)] -> CompositionRecord
  :d "Appends a working assumption to the composition pool, capped at 4 entries"
  (let [(current (.-assumed-facts comp))
        (updated (list-append current (list fact)))
        (capped (if (> (list-length updated) 4) (list-take updated 4) updated))]
    (CompositionRecord
      :goal (.-goal comp)
      :open-questions (.-open-questions comp)
      :assumed-facts capped
      :is-ready (.-is-ready comp)
      :missing (.-missing comp))))

(df close-unresolved-question [(comp CompositionRecord) (target-id Str)] -> CompositionRecord
  :d "Removes an unresolved question settled by incoming user response or waved off"
  (let [(current (.-open-questions comp))
        (filtered (list-filter (fn [(q UnresolvedQuestion)] (not (= (.-id q) target-id))) current))]
    (CompositionRecord
      :goal (.-goal comp)
      :open-questions filtered
      :assumed-facts (.-assumed-facts comp)
      :is-ready (.-is-ready comp)
      :missing (.-missing comp))))

(df supersede-assumed-fact [(comp CompositionRecord) (target-id Str) (new-claim Str)] -> CompositionRecord
  :d "Replaces an invalidated assumption with a new authoritative claim"
  (let [(current (.-assumed-facts comp))
        (filtered (list-filter (fn [(f AssumedFact)] (not (= (.-id f) target-id))) current))
        (updated (list-append filtered (list (make-assumed-fact target-id new-claim))))]
    (CompositionRecord
      :goal (.-goal comp)
      :open-questions (.-open-questions comp)
      :assumed-facts updated
      :is-ready (.-is-ready comp)
      :missing (.-missing comp))))

(df is-lookup-need? [(need UnresolvedNeed)] -> Bool
  :d "Returns true if need is categorized as lookup for autonomous scout investigation"
  (mt need
    ((operator) false)
    ((lookup) true)))

(df extract-pending-lookups [(comp CompositionRecord)] -> (List UnresolvedQuestion)
  :d "Filters open questions that can be investigated autonomously without human intervention"
  (list-filter (fn [(q UnresolvedQuestion)] (is-lookup-need? (.-need q))) (.-open-questions comp)))

(df resolve-lookup-question [(comp CompositionRecord) (target-id Str) (resolved-claim Str)] -> CompositionRecord
  :d "Promotes an autonomously investigated lookup question into an assumed fact and removes it from open questions"
  (let [(c-closed (close-unresolved-question comp target-id))
        (fact (make-assumed-fact target-id resolved-claim))]
    (add-assumed-fact c-closed fact)))

(df render-composition-context [(comp CompositionRecord)] -> Str
  :d "Renders high-density ASN context block representing the current running composition"
  (let [(g (.-goal comp))
        (q-count (list-length (.-open-questions comp)))
        (a-count (list-length (.-assumed-facts comp)))
        (ready-str (if (.-is-ready comp) "true" "false"))]
    (str "(:composition :goal \"" g "\" :ready " ready-str " :open-count " (string-from-int64 q-count) " :assumed-count " (string-from-int64 a-count) ")")))
