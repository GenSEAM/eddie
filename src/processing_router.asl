(module asl-agent/processing-router
  :d "4-Tier Latency Optimization Router: Edge-to-cloud execution routing matrix for sub-100ms real-time operation"
  :x [ProcessingTier
      RouteDecision
      tier-0-ast
      tier-1-audio
      tier-2-slm
      tier-3-cloud
      tier-to-str
      resolve-processing-tier
      format-route-decision-asn]
  :i [(asl-text/string :a s)])

(dfe ProcessingTier
  (:c tier-0-ast [] "Sub-millisecond deterministic AST / regex in-memory")
  (:c tier-1-audio [] "Sub-20ms local ONNX audio engine on Apple Silicon")
  (:c tier-2-slm [] "Sub-100ms local Apple Silicon SLM for triage and computer use")
  (:c tier-3-cloud [] "500-2000ms cloud frontier LLM for deep architectural waves"))

(dfs RouteDecision
  (:f prompt Str "Input directive being routed")
  (:f tier ProcessingTier "Selected execution tier")
  (:f target-engine Str "Assigned compute substrate")
  (:f expected-latency-ms Int64 "Estimated latency SLA")
  (:f rationale Str "Architectural reasoning for tier assignment"))

(df tier-to-str [(tier ProcessingTier)] -> Str
  :d "Converts ProcessingTier enum to canonical string"
  (mt tier
    ((tier-0-ast) "tier-0-ast")
    ((tier-1-audio) "tier-1-audio")
    ((tier-2-slm) "tier-2-slm")
    ((tier-3-cloud) "tier-3-cloud")))

(df is-instant-command? [(low Str)] -> Bool
  :d "Detects sub-millisecond local commands: stop, cancel, pause, status"
  (or (= low "stop")
      (or (= low "стоп")
          (or (= low "cancel")
              (or (= low "отмена")
                  (or (= low "pause")
                      (or (= low "пауза")
                          (or (= low "status") (= low "статус")))))))))

(df is-audio-command? [(low Str)] -> Bool
  :d "Detects audio synthesis or acoustic manipulation commands"
  (or (string-contains? low "озвучь")
      (or (string-contains? low "скажи голосом")
          (or (string-contains? low "громкость")
              (or (string-contains? low "speak")
                  (string-contains? low "volume"))))))

(df is-fast-action-command? [(low Str)] -> Bool
  :d "Detects fast browser navigation, element click, or lightweight triage commands"
  (or (string-contains? low "кликни")
      (or (string-contains? low "открой")
          (or (string-contains? low "перейди")
              (or (string-contains? low "click")
                  (or (string-contains? low "open")
                      (string-contains? low "navigate")))))))

(df resolve-processing-tier [(prompt Str)] -> RouteDecision
  :d "Resolves the optimal execution tier balancing latency, compute locality, and reasoning depth"
  (let [(low (string-lower (string-trim prompt)))]
    (cond
      ((is-instant-command? low)
       (RouteDecision
         :prompt prompt
         :tier (tier-0-ast)
         :target-engine "in-memory-ast"
         :expected-latency-ms 1
         :rationale "Instant local deterministic control action"))
      ((is-audio-command? low)
       (RouteDecision
         :prompt prompt
         :tier (tier-1-audio)
         :target-engine "silero-onnx"
         :expected-latency-ms 18
         :rationale "Local acoustic ONNX synthesis on Apple Neural Engine"))
      ((is-fast-action-command? low)
       (RouteDecision
         :prompt prompt
         :tier (tier-2-slm)
         :target-engine "mlx-qwen-3b"
         :expected-latency-ms 85
         :rationale "Fast local SLM computer use and CDP action matching"))
      (:else
       (RouteDecision
         :prompt prompt
         :tier (tier-3-cloud)
         :target-engine "claude-frontier"
         :expected-latency-ms 1200
         :rationale "Complex architectural reasoning or multi-file coding wave")))))

(df format-route-decision-asn [(decision RouteDecision)] -> Str
  :d "Renders high-density ASN telemetry summarizing routing decision"
  (str "(:route-decision :tier \"" (tier-to-str (.-tier decision)) "\" :engine \"" (.-target-engine decision) "\" :sla-ms " (string-from-int64 (.-expected-latency-ms decision)) ")"))
