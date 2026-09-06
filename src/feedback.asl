(module asl-eddie/feedback
  :d "Zero-fluff feedback and requirement clarification engine: parses ambiguous requests, generates concise options, and enforces radical token economy."
  :x [ClarificationOption
      RefinedRequirement
      is-ambiguous-prompt?
      strip-polite-fluff
      refine-user-prompt
      format-clarifying-question
      format-concise-directive
      format-tradeoff-block]
  :i [])

(dfs ClarificationOption
  (:f key Str "Option key e.g. 1, 2, A, B")
  (:f label Str "Concise technical description of option"))

(dfs RefinedRequirement
  (:f original-prompt Str "Raw user input string")
  (:f clarified-goal Str "Concise 1-sentence technical objective")
  (:f target-files (List Str) "Identified file paths")
  (:f acceptance-criteria (List Str) "Verifiable conditions")
  (:f is-ambiguous Bool "True if user confirmation is required"))

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
