(module asl-agent/chat-bridge
  :d "Real-Time Chat Prompt Streamer: Ingress projection of voice bursts into chat sessions, conversational anaphora resolution, and instant barge-in abort"
  :x [ChatIngressEnvelope
      ChatBridgeState
      make-chat-ingress
      init-chat-bridge
      stream-voice-to-chat
      trigger-barge-in-abort
      resolve-anaphora-directive
      format-chat-ingress-asn
      render-chat-telemetry-asn]
  :i [(asl-text/string :a s)])

(dfs ChatIngressEnvelope
  (:f session-id Str "Chat session identifier")
  (:f source-voice Bool "True if originating from real-time microphone stream")
  (:f raw-transcript Str "Unsanitized speech recognition transcript")
  (:f cleaned-prompt Str "Sanitized and normalized prompt text")
  (:f detected-locale Str "Acoustic language identifier e.g. en, ru, mixed")
  (:f intent-archetype Str "Canonical intent kind e.g. dev, intel, research")
  (:f anaphora-resolved Str "Resolved historical reference or original prompt")
  (:f timestamp-ms Int64 "Ingress event millisecond timestamp"))

(dfs ChatBridgeState
  (:f active-session-id Str "Bound interactive chat session ID")
  (:f is-streaming Bool "True if prompt stream is currently in-flight")
  (:f barge-in-count Int64 "Cumulative count of detected user interruptions")
  (:f prompt-history (List ChatIngressEnvelope) "History of recent chat envelopes"))

(df make-chat-ingress [(session-id Str) (raw Str) (cleaned Str) (locale Str) (intent Str) (anaphora Str) (ts Int64)] -> ChatIngressEnvelope
  :d "Constructs a ChatIngressEnvelope record"
  (ChatIngressEnvelope
    :session-id session-id
    :source-voice true
    :raw-transcript raw
    :cleaned-prompt cleaned
    :detected-locale locale
    :intent-archetype intent
    :anaphora-resolved anaphora
    :timestamp-ms ts))

(df init-chat-bridge [(session-id Str)] -> ChatBridgeState
  :d "Initializes clean chat bridge state"
  (ChatBridgeState
    :active-session-id session-id
    :is-streaming false
    :barge-in-count 0
    :prompt-history (list)))

(df resolve-anaphora-directive [(raw Str) (last-prompt Str)] -> Str
  :d "Resolves conversational anaphoric shorthand against the preceding prompt"
  (let [(low (string-lower (string-trim raw)))]
    (cond
      ((or (= low "run that again")
           (or (= low "запусти это снова")
               (or (= low "повтори") (= low "retry"))))
       last-prompt)
      ((or (string-contains? low "fix it")
           (string-contains? low "исправь это"))
       (str "fix: " last-prompt))
      ((or (string-contains? low "apply it")
           (string-contains? low "примени это"))
       (str "apply: " last-prompt))
      (:else raw))))

(df stream-voice-to-chat [(bridge ChatBridgeState) (envelope ChatIngressEnvelope)] -> ChatBridgeState
  :d "Appends incoming prompt envelope into chat session history with K=10 FIFO retention"
  (let [(current (.-prompt-history bridge))
        (appended (list-append current (list envelope)))
        (appended-len (list-length appended))
        (retained (if (> appended-len 10) (list-drop appended (- appended-len 10)) appended))]
    (ChatBridgeState
      :active-session-id (.-active-session-id bridge)
      :is-streaming true
      :barge-in-count (.-barge-in-count bridge)
      :prompt-history retained)))

(df trigger-barge-in-abort [(bridge ChatBridgeState)] -> ChatBridgeState
  :d "Cancels active stream upon speaker barge-in and increments interrupt counter"
  (ChatBridgeState
    :active-session-id (.-active-session-id bridge)
    :is-streaming false
    :barge-in-count (+ (.-barge-in-count bridge) 1)
    :prompt-history (.-prompt-history bridge)))

(df format-chat-ingress-asn [(envelope ChatIngressEnvelope)] -> Str
  :d "Renders canonical ASN S-expression for chat pane injection"
  (str "(:chat-ingress :session \"" (.-session-id envelope) "\" :intent \"" (.-intent-archetype envelope) "\" :locale \"" (.-detected-locale envelope) "\" :prompt \"" (.-anaphora-resolved envelope) "\")"))

(df render-chat-telemetry-asn [(bridge ChatBridgeState)] -> Str
  :d "Renders high-density ASN telemetry summarizing active chat bridge"
  (let [(hist-len (string-from-int64 (list-length (.-prompt-history bridge))))
        (b-count (string-from-int64 (.-barge-in-count bridge)))
        (stream-str (if (.-is-streaming bridge) "true" "false"))]
    (str "(:chat-bridge :session \"" (.-active-session-id bridge) "\" :streaming " stream-str " :history-count " hist-len " :barge-ins " b-count ")")))
