(module asl-agent/tui-test
  :d "Unit tests for Addie TUI terminal presentation and tool formatting."
  :x [test-tui-header-rendering
      test-orchestration-window-header
      test-tui-orchestration-window
      test-tool-call-folding
      test-tool-call-folding-summary
      test-spinner-formatting
      test-chat-msg-formatting
      test-session-summary
      test-reflection-channel
      test-mesh-telemetry
      run-tests]
  :i [(tui :a tui) (policy :a pol)])

(df test-tui-header-rendering [] -> Bool
  (let [(h (tui/make-tui-header "gemma-4-31b-it" (pol/level-guarded)))
        (rendered (tui/format-tui-header h))]
    (assert (string-contains? rendered "Addie TUI") "contains Addie TUI")
    (assert (string-contains? rendered "gemma-4-31b-it") "contains model")
    (assert (string-contains? rendered "L1:Guarded") "contains level")
    (assert (not (string-contains? rendered "L0:Autonomous")) "does not contain L0")
    true))

(df test-orchestration-window-header [] -> Bool
  :d "Verifies TuiHeader creation with explicit mode and rendering in status bar."
  (let [(hdr (tui/make-tui-header-with-mode "gemma-4-31b-it" "fast" (pol/level-guarded)))
        (rendered (tui/format-tui-header hdr))]
    (assert (= (.-pipeline-mode hdr) "fast") "pipeline mode is fast")
    (assert (string-contains? rendered "Model: gemma-4-31b-it") "contains model")
    (assert (string-contains? rendered "Mode: fast") "contains fast mode")
    (assert (not (string-contains? rendered "Mode: deep")) "does not contain deep mode")
    true))

(df test-tool-call-folding [] -> Bool
  (let [(line (tui/format-tool-call "read_file" "src/agent.asl" "ok (120 lines)"))]
    (assert (string-contains? line "[>] [read_file]") "contains arrow and tool name")
    (assert (string-contains? line "src/agent.asl -> ok") "contains path and status")
    (assert (not (string-contains? line "write_file")) "does not contain write_file")
    true))

(df test-tool-call-folding-summary [] -> Bool
  :d "Verifies collapsible tool call formatting in folded and unfolded states."
  (let [(folded (tui/format-tool-call-fold "asl:test" "batch_test.asl" "passed" true "Detail omitted"))
        (unfolded (tui/format-tool-call-fold "asl:test" "batch_test.asl" "passed" false "10 passed in 45ms"))]
    (assert (string-contains? folded "[>] [asl:test] batch_test.asl -> passed") "folded header matches")
    (assert (not (string-contains? folded "Detail omitted")) "folded detail omitted")
    (assert (string-contains? unfolded "[v] [asl:test] batch_test.asl -> passed") "unfolded header matches")
    (assert (string-contains? unfolded "10 passed in 45ms") "unfolded detail present")
    true))

(df test-spinner-formatting [] -> Bool
  (let [(s (tui/format-spinner-status "Executing verification gates"))]
    (assert (string-contains? s "[~] Executing verification gates...") "contains spinner message")
    (assert (not (string-contains? s "Idle")) "does not contain Idle")
    true))

(df test-chat-msg-formatting [] -> Bool
  (let [(u (tui/format-chat-msg "user" "Refactor policy.asl"))
        (a (tui/format-chat-msg "assistant" "Policy updated. 0 syntax errors."))]
    (assert (string-starts-with? u "\n> Refactor") "user message starts with prompt arrow")
    (assert (string-starts-with? a "\n[*] Policy updated.") "assistant message starts with diamond")
    (assert (not (string-contains? u "Error")) "user message has no error")
    true))

(df test-session-summary [] -> Bool
  (let [(h (tui/make-tui-header "qwen3:4b" (pol/level-auto)))
        (s (tui/format-session-summary h 4))]
    (assert (string-contains? s "Session complete (4 turns)") "contains session complete")
    (assert (not (string-contains? s "Aborted")) "does not contain aborted")
    true))

(df test-agent-badge [] -> Bool
  (let [(b (tui/format-agent-badge "planner" "fable" "claude-fable-5-1"))]
    (assert (string-contains? b "[Agent: planner]") "contains agent role")
    (assert (string-contains? b "alias :fable") "contains alias")
    (assert (not (string-contains? b "executor")) "does not contain executor")
    true))

(df test-thinking-block [] -> Bool
  (let [(tb (tui/format-thinking-block "Reasoning about AST tree"))]
    (assert (string-contains? tb "[Quarantined Reasoning Channel]") "contains header")
    (assert (string-contains? tb "Reasoning about AST tree") "contains reasoning content")
    (assert (not (string-contains? tb "Unfiltered")) "does not contain unfiltered")
    true))

(df test-context-bar [] -> Bool
  (let [(cb (tui/format-context-bar 4096 131072))]
    (assert (string-contains? cb "[Context:") "contains context header")
    (assert (string-contains? cb "4096 / 131072") "contains tokens count")
    (assert (not (string-contains? cb "Overflow")) "does not contain overflow")
    true))

(df test-reflection-channel [] -> Bool
  (let [(rc (tui/format-reflection-channel "Epistemic calibration and fact reconciliation"))]
    (assert (string-contains? rc "[Quarantined Reflection Channel]") "contains reflection header")
    (assert (string-contains? rc "Epistemic calibration") "contains text")
    (assert (not (string-contains? rc "Hallucination")) "does not contain hallucination")
    true))

(df test-mesh-telemetry [] -> Bool
  (let [(mt (tui/format-mesh-telemetry 120 450 85 45))]
    (assert (string-contains? mt "[Mesh Telemetry]") "contains mesh telemetry header")
    (assert (string-contains? mt ":scout: 120 tok") "contains scout tokens")
    (assert (string-contains? mt ":coder: 450 tok") "contains coder tokens")
    (assert (string-contains? mt ":reviewer: 85 tok") "contains reviewer tokens")
    true))

(df test-diff-preview [] -> Bool
  (let [(dp (tui/format-diff-preview "src/main.asl" 12 3))]
    (assert (string-contains? dp "DELTA [src/main.asl]") "contains diff header")
    (assert (string-contains? dp "+12 -3 lines") "contains line counts")
    (assert (not (string-contains? dp "conflict")) "does not contain conflict")
    true))

(df test-tui-orchestration-window [] -> Bool
  :d "Verifies terminal UI orchestration window header, reflection channel, tool folding, and context diff bar."
  (let [(hdr (tui/make-tui-header-with-mode "gemma-4-31b-it" "fast" (pol/level-guarded)))
        (h-str (tui/format-tui-header hdr))
        (r-str (tui/format-reflection-channel "Epistemic anchor active"))
        (t-str (tui/format-tool-call "read" "gsa/src/tui.asl" "completed"))
        (c-str (tui/format-context-and-diff-bar 4096 131072 "gsa/src/tui.asl" 15 2))]
    (assert (string-contains? h-str "Addie TUI: Orchestration Window") "contains window header")
    (assert (string-contains? h-str "Autonomy: ") "contains autonomy label")
    (assert (string-contains? r-str "[Quarantined Reflection Channel]:") "contains reflection prefix")
    (assert (string-contains? t-str "[>] [read]") "contains tool call prefix")
    (assert (string-contains? c-str "[Context:") "contains context bar")
    (assert (string-contains? c-str "DELTA [") "contains diff indicator")
    true))

(df run-tests [] -> Bool
  (do
    (test-tui-header-rendering)
    (test-orchestration-window-header)
    (test-tool-call-folding)
    (test-tool-call-folding-summary)
    (test-spinner-formatting)
    (test-chat-msg-formatting)
    (test-session-summary)
    (test-agent-badge)
    (test-thinking-block)
    (test-reflection-channel)
    (test-mesh-telemetry)
    (test-context-bar)
    (test-diff-preview)
    (test-tui-orchestration-window)
    true))


