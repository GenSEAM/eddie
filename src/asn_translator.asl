(module asl-agent/asn-translator
  :d "High-Speed Multilingual Prompt-to-ASN Intent Translator supporting English, Russian, and Mixed Code-Switching"
  :x [AsnIntentFrame
      make-asn-intent-frame
      extract-project-target
      is-release-disposition?
      translate-prompt-to-asn
      render-asn-intent-sexp]
  :i [(core/strings :a s)
      (intent_cleaner :a ic)])

(dfs AsnIntentFrame
  (:f intent-id Str "Unique intent identifier")
  (:f kind Str "Intent kind: dev, fast-path, intel, meta, research")
  (:f project-target Str "Target codebase repository name or 'general'")
  (:f disposition Str "Frontline disposition: new, release, query, admin, followup")
  (:f goal Str "Purified intent goal statement")
  (:f requires-worktree Bool "True if git branch isolation is required")
  (:f requires-gate Bool "True if failing verification gate is required"))

(df make-asn-intent-frame [(id Str) (kind Str) (target Str) (disp Str) (goal Str) (worktree Bool) (gate Bool)] -> AsnIntentFrame
  :d "Constructs an AsnIntentFrame record"
  (AsnIntentFrame
    :intent-id id
    :kind kind
    :project-target target
    :disposition disp
    :goal goal
    :requires-worktree worktree
    :requires-gate gate))

(df extract-project-target [(text Str)] -> Str
  :d "Extracts target repository from prompt text in English or Russian transliteration"
  (let [(low (string-lower text))]
    (cond
      ((or (string-contains? low "agentube") (string-contains? low "агентуб")) "agentube")
      ((or (string-contains? low "vtbot") (string-contains? low "втбот")) "vtbot")
      ((or (string-contains? low "datahub-core") (string-contains? low "датахаб")) "datahub-core")
      ((or (string-contains? low "shrody") (string-contains? low "шроуди")) "shrody")
      ((or (string-contains? low "paykit") (string-contains? low "пейкит")) "paykit")
      ((or (string-contains? low "storefront") (string-contains? low "сторфронт")) "storefront")
      ((or (string-contains? low "asex") (string-contains? low "асекс")) "asex")
      (:else "general"))))

(df is-release-disposition? [(low Str)] -> Bool
  :d "Detects release dispositions in Russian and English (го, давай, поехали, всё, send it, that's it)"
  (or (= low "го")
      (or (= low "давай")
          (or (= low "поехали")
              (or (= low "всё")
                  (or (= low "send it")
                      (or (= low "that's it")
                          (= low "thats it"))))))))

(df is-intel-query? [(low Str)] -> Bool
  :d "Detects code intelligence and inspection queries"
  (or (string-contains? low "где находится")
      (or (string-contains? low "кто вызывает")
          (or (string-contains? low "find symbol")
              (or (string-contains? low "callers")
                  (string-contains? low "ast outline"))))))

(df is-meta-query? [(low Str)] -> Bool
  :d "Detects system status and introspection queries"
  (or (string-contains? low "статус")
      (or (string-contains? low "status")
          (or (string-contains? low "что сейчас выполняется")
              (or (string-contains? low "what is running")
                  (string-contains? low "почему упало"))))))

(df is-admin-command? [(low Str)] -> Bool
  :d "Detects project administrative commands"
  (or (string-contains? low "unregister ")
      (or (string-contains? low "переключись на проект")
          (or (string-contains? low "удали все задачи")
              (string-contains? low "switch project")))))

(df translate-prompt-to-asn [(raw-prompt Str)] -> AsnIntentFrame
  :d "Translates a natural language developer prompt into a formal ASN intent frame"
  (let [(clean-res (ic/clean-voice-intent raw-prompt))
        (goal (.-cleaned-intent clean-res))
        (low (string-lower goal))
        (target (extract-project-target goal))]
    (cond
      ((is-release-disposition? low)
       (make-asn-intent-frame "intent-release" "fast-path" "general" "release" goal false false))
      ((is-admin-command? low)
       (make-asn-intent-frame "intent-admin" "fast-path" target "admin" goal false false))
      ((is-intel-query? low)
       (make-asn-intent-frame "intent-intel" "intel" target "query" goal false false))
      ((is-meta-query? low)
       (make-asn-intent-frame "intent-meta" "meta" "general" "meta" goal false false))
      ((or (string-contains? low "найди в документации") (string-contains? low "search web"))
       (make-asn-intent-frame "intent-research" "research" "general" "new" goal false false))
      (:else
       (let [(needs-repo (not (= target "general")))]
         (make-asn-intent-frame "intent-dev" "dev" target "new" goal needs-repo needs-repo))))))

(df render-asn-intent-sexp [(frame AsnIntentFrame)] -> Str
  :d "Renders an AsnIntentFrame into a compact, delimiter-balanced ASN S-expression"
  (let [(wt-str (if (.-requires-worktree frame) "true" "false"))
        (gate-str (if (.-requires-gate frame) "true" "false"))]
    (str "(:intent :id \"" (.-intent-id frame) "\" :kind :" (.-kind frame)
         " :project \"" (.-project-target frame) "\" :disposition :" (.-disposition frame)
         " :goal \"" (.-goal frame) "\" :requires-worktree " wt-str
         " :requires-gate " gate-str ")")))
