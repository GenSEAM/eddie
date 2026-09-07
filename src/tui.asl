(module asl-agent/tui
  :d "High-efficiency terminal UI renderer: streaming chat turns, folding tool calls, and session telemetry."
  :x [TuiHeader
      make-tui-header
      format-tui-header
      format-tool-call
      format-spinner-status
      format-chat-msg
      format-agent-badge
      format-thinking-block
      format-context-bar
      format-diff-preview
      format-session-summary]
  :i [(policy :a pol)])

(dfs TuiHeader
  (:f model-name Str "Active LLM profile identifier e.g. gemma-4-31b-it")
  (:f autonomy pol/AutonomyLevel "Active autonomy permission tier")
  (:f prompt-tokens I64 "Accumulated input context tokens")
  (:f completion-tokens I64 "Accumulated generated tokens")
  (:f session-cost F64 "Estimated USD cost"))

(df make-tui-header [(model-name Str) (autonomy pol/AutonomyLevel)] -> TuiHeader
  :d "Constructs an initial TuiHeader record."
  (TuiHeader
    :model-name model-name
    :autonomy autonomy
    :prompt-tokens 0
    :completion-tokens 0
    :session-cost 0.0))

(df format-tui-header [(header TuiHeader)] -> Str
  :d "Renders compact 1-line terminal status header."
  (let [(total-tokens (+ (.-prompt-tokens header) (.-completion-tokens header)))
        (lvl-str (pol/autonomy-level-to-string (.-autonomy header)))]
    (str "┌── [Eddie TUI] Model: " (.-model-name header)
         " | Autonomy: " lvl-str
         " | Tokens: " (string-from-int64 total-tokens)
         " | Cost: $" (string-slice (string-from-float (.-session-cost header)) 0 6) " ──┐")))

(df format-agent-badge [(role Str) (alias Str) (model Str)] -> Str
  :d "Renders rich agent role and model routing indicator badge."
  (str "  👤 [Agent: " role "] routed to alias @" alias " (" model ")"))

(df format-thinking-block [(think Str)] -> Str
  :d "Formats quarantined reasoning/thinking channel with clean indentation."
  (str "  🧠 [Quarantined Reasoning Channel]\n     | " (string-trim think)))

(df format-context-bar [(current I64) (limit I64)] -> Str
  :d "Formats context window memory utilization bar."
  (let [(pct (if (> limit 0) (/ (* current 100) limit) 0))]
    (str "  📊 [Context: " (string-from-int64 current) " / "
         (string-from-int64 limit) " tok (" (string-from-int64 pct) "%)]")))

(df format-diff-preview [(path Str) (added I64) (removed I64)] -> Str
  :d "Formats compact file diff line summary."
  (str "  Δ [" path "] +" (string-from-int64 added) " -" (string-from-int64 removed) " lines"))

(df format-tool-call [(tool Str) (target Str) (status Str)] -> Str
  :d "Formats compact 1-line folding tool block for terminal output."
  (str "  ▶ [" tool "] " target " → " status))

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

