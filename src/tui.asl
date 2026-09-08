(module asl-agent/tui
  :d "High-efficiency terminal UI renderer: streaming chat turns, folding tool calls, and session telemetry."
  :x [TuiHeader MeshNodeStats
      make-tui-header
      make-tui-header-with-mode
      format-tui-header
      format-tool-call
      format-tool-call-fold
      format-spinner-status
      format-chat-msg
      format-agent-badge
      format-thinking-block
      format-reflection-channel
      format-mesh-telemetry
      format-context-bar
      format-diff-preview
      format-context-and-diff-bar
      format-session-summary]
  :i [(policy :a pol)])

(dfs TuiHeader
  (:f model-name Str "Active LLM profile identifier e.g. gemma-4-31b-it")
  (:f pipeline-mode Str "Active pipeline profile mode e.g. fast, standard, full")
  (:f autonomy pol/AutonomyLevel "Active autonomy permission tier")
  (:f prompt-tokens I64 "Accumulated input context tokens")
  (:f completion-tokens I64 "Accumulated generated tokens")
  (:f session-cost F64 "Estimated USD cost"))

(df make-tui-header [(model-name Str) (autonomy pol/AutonomyLevel)] -> TuiHeader
  :d "Constructs an initial TuiHeader record."
  (TuiHeader
    :model-name model-name
    :pipeline-mode "standard"
    :autonomy autonomy
    :prompt-tokens 0
    :completion-tokens 0
    :session-cost 0.0))

(df make-tui-header-with-mode [(model-name Str) (mode Str) (autonomy pol/AutonomyLevel)] -> TuiHeader
  :d "Constructs a TuiHeader record with explicit pipeline mode."
  (TuiHeader
    :model-name model-name
    :pipeline-mode mode
    :autonomy autonomy
    :prompt-tokens 0
    :completion-tokens 0
    :session-cost 0.0))

(df format-tui-header [(header TuiHeader)] -> Str
  :d "Renders compact 1-line terminal status header with active model and pipeline mode."
  (let [(total-tokens (+ (.-prompt-tokens header) (.-completion-tokens header)))
        (lvl-str (pol/autonomy-level-to-string (.-autonomy header)))]
    (str "┌── [Addie TUI: Orchestration Window] Model: " (.-model-name header)
         " | Mode: " (.-pipeline-mode header)
         " | Autonomy: " lvl-str
         " | Tokens: " (string-from-int64 total-tokens)
         " | Cost: $" (string-slice (string-from-float (.-session-cost header)) 0 6) " ──┐")))

(df format-agent-badge [(role Str) (alias Str) (model Str)] -> Str
  :d "Renders rich agent role and model routing indicator badge."
  (str "  [Agent: " role "] routed to alias @" alias " (" model ")"))

(dfs MeshNodeStats
  (:f alias Str "Agent mesh alias e.g. @scout")
  (:f role Str "Assigned agent role e.g. scout")
  (:f tokens I64 "Accumulated token count")
  (:f latency-ms I64 "Latency in milliseconds"))

(df format-mesh-telemetry [(scout-tok I64) (coder-tok I64) (reviewer-tok I64) (latency-ms I64)] -> Str
  :d "Renders live telemetry block for multi-agent mesh orchestration."
  (str "  [Mesh Telemetry] @scout: " (string-from-int64 scout-tok) " tok"
       " | @coder: " (string-from-int64 coder-tok) " tok"
       " | @reviewer: " (string-from-int64 reviewer-tok) " tok"
       " | Latency: " (string-from-int64 latency-ms) "ms"))

(df format-thinking-block [(think Str)] -> Str
  :d "Formats quarantined reasoning/thinking channel with clean indentation."
  (str "  [Quarantined Reasoning Channel]\n     | " (string-trim think)))

(df format-reflection-channel [(thought Str)] -> Str
  :d "Formats quarantined 7-stage epistemic reflection channel with clean indentation."
  (str "  [Quarantined Reflection Channel]: " (string-trim thought)))

(df format-context-bar [(current I64) (limit I64)] -> Str
  :d "Formats context window memory utilization bar."
  (let [(pct (if (> limit 0) (/ (* current 100) limit) 0))]
    (str "  [Context: " (string-from-int64 current) " / "
         (string-from-int64 limit) " tok (" (string-from-int64 pct) "%)]")))

(df format-diff-preview [(path Str) (added I64) (removed I64)] -> Str
  :d "Formats compact file diff line summary."
  (str "  Δ [" path "] +" (string-from-int64 added) " -" (string-from-int64 removed) " lines"))

(df format-context-and-diff-bar [(current I64) (limit I64) (path Str) (added I64) (removed I64)] -> Str
  :d "Formats combined context window utilization bar and diff preview summary."
  (str (format-context-bar current limit) " " (format-diff-preview path added removed)))

(df format-tool-call [(tool Str) (target Str) (status Str)] -> Str
  :d "Formats compact 1-line folding tool block for terminal output."
  (str "  ▶ [" tool "] " target " → " status))

(df format-tool-call-fold [(tool Str) (target Str) (status Str) (is-folded Bool) (detail Str)] -> Str
  :d "Formats a collapsible tool call showing compact one-line header when folded or indented details when unfolded."
  (if is-folded
    (str "  ▶ [" tool "] " target " → " status)
    (str "  ▼ [" tool "] " target " → " status "\n     " detail)))

(df format-spinner-status [(action Str)] -> Str
  :d "Formats an in-progress terminal status notification."
  (str "  ⠋ " action "..."))

(df format-chat-msg [(role Str) (content Str)] -> Str
  :d "Formats clean chat message without conversational filler."
  (if (= role "user")
    (str "\n❯ " content)
    (str "\n◆ " (string-trim content))))

(df format-session-summary [(header TuiHeader) (turns I64)] -> Str
  :d "Renders final session completion summary."
  (let [(total-toks (+ (.-prompt-tokens header) (.-completion-tokens header)))]
    (str "\n✔ Session complete (" (string-from-int64 turns) " turns). Total tokens: "
         (string-from-int64 total-toks) " ($"
         (string-slice (string-from-float (.-session-cost header)) 0 6) ")")))

