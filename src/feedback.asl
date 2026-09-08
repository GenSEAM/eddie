(module asl-agent/feedback
  :d "Feedback Harness & Intent Discovery Engine: ambiguity resolution, Freedom Corridor negotiation, Explain-Once memory grounding, and Swarm DAG decomposition."
  :x [ClarificationOption RefinedRequirement DialogueStage IntentContract
      stage-interview stage-corridor-negotiation stage-grounded stage-delegated
      is-ambiguous-prompt? strip-polite-fluff refine-user-prompt
      format-clarifying-question format-concise-directive format-tradeoff-block
      make-intent-contract ground-intent-to-memory decompose-intent-to-dag advance-dialogue-stage]
  :i [(corridor :a corr) (task_dag :a dag)])

(dfs ClarificationOption
  (:f key Str "Option key e.g. 1, 2, A, B")
  (:f label Str "Concise technical description of option"))

(dfs RefinedRequirement
  (:f original-prompt Str "Raw user input string")
  (:f clarified-goal Str "Concise 1-sentence technical objective")
  (:f target-files (List Str) "Identified file paths")
  (:f acceptance-criteria (List Str) "Verifiable conditions")
  (:f is-ambiguous Bool "True if user confirmation is required"))

(dfe DialogueStage
  (:c stage-interview [] "Conversational discovery and ambiguity resolution")
  (:c stage-corridor-negotiation [] "Aligning invariants and degrees of freedom")
  (:c stage-grounded [] "Persisted to memory ledger, explain-once contract locked")
  (:c stage-delegated [] "Dispatched to Swarm Supervisor DAG for worker execution"))

(dfs IntentContract
  (:f id Str "Deterministic contract identifier e.g. intent-01")
  (:f title Str "Human-readable intent title")
  (:f clarified-goal Str "Concise technical objective")
  (:f corridor corr/FreedomCorridor "Negotiated Freedom Corridor")
  (:f stage DialogueStage "Current lifecycle dialogue phase")
  (:f is-grounded Bool "True if committed to persistent ASN memory"))

(df is-ambiguous-prompt? [(prompt Str)] -> Bool
  :d "Detects whether prompt is underspecified (lacks specific file, action, or has multiple interpretations)."
  (let [(trimmed (string-trim prompt))
        (len (string-length trimmed))]
    (cond
      ((< len 15) true)
      ((and (not (string-contains? trimmed ".")) (not (string-contains? trimmed "/"))) true)
      ((string-starts-with? trimmed "help") true)
      ((string-starts-with? trimmed "do something") true)
      (:else false))))

(df strip-polite-fluff [(text Str)] -> Str
  :d "Aggressively strips conversational filler phrases to preserve token economy."
  (let [(t1 (string-replace text "Certainly! I'd be happy to help with that." ""))
        (t2 (string-replace t1 "Sure thing! " ""))
        (t3 (string-replace t2 "Hello! " ""))
        (t4 (string-replace t3 "I hope you are doing well. " ""))
        (t5 (string-replace t4 "Please let me know if you need anything else." ""))]
    (string-trim t5)))

(df refine-user-prompt [(prompt Str) (detected-files (List Str))] -> RefinedRequirement
  :d "Transforms raw user input into a concise RefinedRequirement."
  (let [(ambig (is-ambiguous-prompt? prompt))
        (clean-prompt (strip-polite-fluff prompt))]
    (if ambig
      (RefinedRequirement
        :original-prompt prompt
        :clarified-goal (str "Clarification required: " clean-prompt)
        :target-files detected-files
        :acceptance-criteria (list "User selects execution target")
        :is-ambiguous true)
      (RefinedRequirement
        :original-prompt prompt
        :clarified-goal clean-prompt
        :target-files detected-files
        :acceptance-criteria (list "Code compiles cleanly" "All test gates pass")
        :is-ambiguous false))))

(df format-clarifying-question [(req RefinedRequirement) (options (List ClarificationOption))] -> Str
  :d "Renders a compact, no-fluff multiple-choice clarification question."
  (let [(opt-str (fold (fn [(acc Str) (opt ClarificationOption)] -> Str
                         (str acc "\n  [" (.-key opt) "] " (.-label opt)))
                       ""
                       options))]
    (str "Need clarification for: \"" (.-original-prompt req) "\"" opt-str "\nSelect option:")))

(df format-concise-directive [(req RefinedRequirement)] -> Str
  :d "Formats actionable technical directive for agent loop without conversational water."
  (str "Goal: " (.-clarified-goal req)
       " | Targets: " (string-from-int64 (list-length (.-target-files req)))
       " files | Verification: " (string-join "; " (.-acceptance-criteria req))))

(df format-tradeoff-block [(tradeoffs (List Str))] -> Str
  :d "Formats observed architectural trade-offs."
  (if (list-empty? tradeoffs)
    ""
    (str "Trade-offs: " (string-join ", " tradeoffs))))

(df make-intent-contract [(id Str) (title Str) (goal Str) (corridor corr/FreedomCorridor)] -> IntentContract
  :d "Constructs an initialized IntentContract in corridor-negotiation stage."
  (IntentContract
    :id id
    :title title
    :clarified-goal goal
    :corridor corridor
    :stage (stage-corridor-negotiation)
    :is-grounded false))

(df ground-intent-to-memory [(intent IntentContract)] -> Str
  :d "Serializes verified intent contract to canonical ASN for .asl/mem/intent.asn persistent ledger."
  (let [(corr-asn (corr/corridor-to-asn (.-corridor intent)))]
    (str "(:intent :id \"" (.-id intent)
         "\" :title \"" (.-title intent)
         "\" :goal \"" (.-clarified-goal intent)
         "\" :grounded true :corridor " corr-asn ")")))

(df decompose-intent-to-dag [(intent IntentContract)] -> dag/TaskDAG
  :d "Decomposes agreed intent contract into an actionable Swarm TaskDAG with dependency ordering."
  (let [(t1 (dag/make-task-node (str (.-id intent) "-scout") "Scout perceptual discovery and AST outline" "triage" (list)))
        (t2 (dag/make-task-node (str (.-id intent) "-design") "Architectural concept and visual layout" "design" (list (str (.-id intent) "-scout"))))
        (t3 (dag/make-task-node (str (.-id intent) "-impl") "Deterministic implementation of verified changes" "coding" (list (str (.-id intent) "-design"))))
        (t4 (dag/make-task-node (str (.-id intent) "-audit") "Empirical gate verification and critic audit" "review" (list (str (.-id intent) "-impl"))))]
    (dag/make-task-dag (str "dag-" (.-id intent)) (list t1 t2 t3 t4))))

(df advance-dialogue-stage [(intent IntentContract) (next-stage DialogueStage)] -> IntentContract
  :d "Transitions intent contract through dialogue phases updating grounded status."
  (let [(grounded? (mt next-stage
                     ((stage-grounded) true)
                     ((stage-delegated) true)
                     ((stage-interview) false)
                     ((stage-corridor-negotiation) false)))]
    (IntentContract
      :id (.-id intent)
      :title (.-title intent)
      :clarified-goal (.-clarified-goal intent)
      :corridor (.-corridor intent)
      :stage next-stage
      :is-grounded grounded?)))
