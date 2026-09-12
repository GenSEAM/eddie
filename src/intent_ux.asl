(module asl-agent/intent-ux
  :d "Holistic Intent Taxonomy, User Experience Policies, Focus Guard, and Modality Routing for all 9 Intent Types"
  :x [IntentKind UxModality FocusPolicy IntentSpec
      classify-intent
      is-disruptive-to-user?
      resolve-optimal-ux
      make-intent-spec]
  :i [(asl-text/string :a s)])

(dfe IntentKind
  (:c intent-fast-path [] "Instant local action: pause, mute, stop, cancel (<1ms)")
  (:c intent-dev [] "Code generation, refactoring, and bugfixing with worktree and failing gates")
  (:c intent-intel [] "Code intelligence: AST outlines, callers, impact without disk mutation")
  (:c intent-research [] "Autonomous fact lookup in docs/APIs without interrupting operator")
  (:c intent-clarify [] "Operator consultation and specification disambiguation")
  (:c intent-followup [] "Conversational continuation linked to previous parent task")
  (:c intent-meta [] "Bookkeeping and self-reflection answered directly from task memory")
  (:c intent-nudge [] "Proactive notification of failure runs or unreviewed decisions")
  (:c intent-mesh [] "Swarm delegation across Claude Code CLI, Antigravity IDE, and AD-agents"))

(dfe UxModality
  (:c modality-voice [] "Auditory speech response via Silero TTS with 8s attention budget")
  (:c modality-hud [] "Compact visual sparkline HUD or status bar")
  (:c modality-editor [] "Inline code diff preview in IDE")
  (:c modality-silent [] "Background execution with zero UI disruption"))

(dfe FocusPolicy
  (:c focus-immediate [] "Allowed to shift focus (e.g. critical operator clarification)")
  (:c focus-hold-until-idle [] "Held while operator is speaking or typing, applied when idle")
  (:c focus-badge-only [] "Never shifts focus, annotates rail badge"))

(dfs IntentSpec
  (:f intent-id Str "Unique intent identifier")
  (:f kind IntentKind "Categorical intent archetype")
  (:f modality UxModality "Primary presentation modality")
  (:f focus FocusPolicy "Focus guard policy")
  (:f target-workspace Str "Target workspace path or 'general'")
  (:f requires-worktree Bool "True if code mutation requires isolated git branch")
  (:f requires-gate Bool "True if execution requires failing verification gate")
  (:f latency-tier Str "Performance SLA: sub-millisecond, interactive, background"))

(df make-intent-spec [(id Str) (kind IntentKind) (modality UxModality) (focus FocusPolicy) (target Str) (worktree Bool) (gate Bool) (sla Str)] -> IntentSpec
  :d "Constructs an IntentSpec record"
  (IntentSpec
    :intent-id id
    :kind kind
    :modality modality
    :focus focus
    :target-workspace target
    :requires-worktree worktree
    :requires-gate gate
    :latency-tier sla))

(df is-stop-command? [(low Str)] -> Bool
  :d "Detects instant stop and pause commands"
  (or (= low "стоп")
      (or (= low "stop")
          (or (= low "отмена")
              (or (= low "cancel")
                  (or (= low "пауза") (= low "pause")))))))

(df is-intel-command? [(low Str)] -> Bool
  :d "Detects code intelligence queries"
  (or (string-contains? low "где находится")
      (or (string-contains? low "кто вызывает")
          (or (string-contains? low "find symbol")
              (string-contains? low "callers")))))

(df is-meta-command? [(low Str)] -> Bool
  :d "Detects system reflection and status queries"
  (or (string-contains? low "почему упало")
      (or (string-contains? low "что ты делаешь")
          (or (string-contains? low "статус")
              (string-contains? low "status")))))

(df is-research-command? [(low Str)] -> Bool
  :d "Detects autonomous background research requests"
  (or (string-contains? low "найди в документации")
      (or (string-contains? low "как работает библиотека")
          (string-contains? low "search web"))))

(df is-dev-command? [(low Str)] -> Bool
  :d "Detects software mutation and coding requests"
  (or (string-contains? low "исправь")
      (or (string-contains? low "добавь")
          (or (string-contains? low "напиши тест")
              (string-contains? low "refactor")))))

(df is-mesh-command? [(low Str)] -> Bool
  :d "Detects multi-IDE swarm delegation requests"
  (or (string-contains? low "распредели на claude и antigravity")
      (or (string-contains? low "запусти в воркспейсах")
          (string-contains? low "swarm"))))

(df classify-intent [(prompt Str)] -> IntentSpec
  :d "Classifies raw input into one of the 9 canonical intent archetypes with tailored UX policies"
  (let [(low (string-lower (string-trim prompt)))]
    (cond
      ((is-stop-command? low)
       (make-intent-spec "fast-path" (intent-fast-path) (modality-voice) (focus-immediate) "general" false false "sub-millisecond"))
      ((is-intel-command? low)
       (make-intent-spec "intel" (intent-intel) (modality-hud) (focus-hold-until-idle) "current" false false "interactive"))
      ((is-meta-command? low)
       (make-intent-spec "meta" (intent-meta) (modality-voice) (focus-hold-until-idle) "general" false false "sub-second"))
      ((is-research-command? low)
       (make-intent-spec "research" (intent-research) (modality-silent) (focus-badge-only) "general" false false "background"))
      ((is-dev-command? low)
       (make-intent-spec "dev" (intent-dev) (modality-editor) (focus-hold-until-idle) "current" true true "interactive"))
      ((is-mesh-command? low)
       (make-intent-spec "mesh" (intent-mesh) (modality-hud) (focus-badge-only) "multi" true true "background"))
      (:else
       (make-intent-spec "general" (intent-dev) (modality-voice) (focus-hold-until-idle) "general" false false "interactive")))))

(df is-disruptive-to-user? [(intent IntentSpec) (is-user-active Bool)] -> Bool
  :d "Evaluates whether presenting this intent would disrupt active user speaking or typing"
  (if (not is-user-active)
    false
    (let [(f (.-focus intent))]
      (cond
        ((= f (focus-immediate)) false)
        ((= f (focus-badge-only)) false)
        ((= f (focus-hold-until-idle)) true)
        (:else false)))))

(df resolve-optimal-ux [(intent IntentSpec)] -> Str
  :d "Emits structured S-expression declaring optimal UX ergonomics for the intent"
  (let [(sla (.-latency-tier intent))]
    (str "(:ux-plan :intent \"" (.-intent-id intent) "\" :sla \"" sla "\")")))
