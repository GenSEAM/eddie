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

"run: (run-tests)"

(df test-tui-header-rendering [] -> Bool
  (let [(h (tui/make-tui-header "gemma-4-31b-it" (pol/level-guarded)))
        (rendered (tui/format-tui-header h))]
    (and (string-contains? rendered "Addie TUI")
         (and (string-contains? rendered "gemma-4-31b-it")
              (string-contains? rendered "L1:Guarded")))))

(df test-orchestration-window-header [] -> Bool
  :d "Verifies TuiHeader creation with explicit mode and rendering in status bar."
  (let [(hdr (tui/make-tui-header-with-mode "gemma-4-31b-it" "fast" (pol/level-guarded)))
        (rendered (tui/format-tui-header hdr))]
    (and (= (.-pipeline-mode hdr) "fast")
         (and (string-contains? rendered "Model: gemma-4-31b-it")
              (string-contains? rendered "Mode: fast")))))

(df test-tool-call-folding [] -> Bool
  (let [(line (tui/format-tool-call "read_file" "src/agent.asl" "ok (120 lines)"))]
    (and (string-contains? line "▶ [read_file]")
         (string-contains? line "src/agent.asl → ok"))))

(df test-tool-call-folding-summary [] -> Bool
  :d "Verifies collapsible tool call formatting in folded and unfolded states."
  (let [(folded (tui/format-tool-call-fold "asl:test" "batch_test.asl" "passed" true "Detail omitted"))
        (unfolded (tui/format-tool-call-fold "asl:test" "batch_test.asl" "passed" false "10 passed in 45ms"))]
    (and (string-contains? folded "▶ [asl:test] batch_test.asl → passed")
         (and (not (string-contains? folded "Detail omitted"))
              (and (string-contains? unfolded "▼ [asl:test] batch_test.asl → passed")
                   (string-contains? unfolded "10 passed in 45ms"))))))

(df test-spinner-formatting [] -> Bool
  (let [(s (tui/format-spinner-status "Executing verification gates"))]
    (string-contains? s "⠋ Executing verification gates...")))

(df test-chat-msg-formatting [] -> Bool
  (let [(u (tui/format-chat-msg "user" "Refactor policy.asl"))
        (a (tui/format-chat-msg "assistant" "Policy updated. 0 syntax errors."))]
    (and (string-starts-with? u "\n❯ Refactor")
         (string-starts-with? a "\n◆ Policy updated."))))

(df test-session-summary [] -> Bool
  (let [(h (tui/make-tui-header "qwen3:4b" (pol/level-auto)))
        (s (tui/format-session-summary h 4))]
    (string-contains? s "✔ Session complete (4 turns)")))

(df test-agent-badge [] -> Bool
  (let [(b (tui/format-agent-badge "planner" "fable" "claude-fable-5-1"))]
    (and (string-contains? b "👤 [Agent: planner]")
         (string-contains? b "alias @fable"))))

(df test-thinking-block [] -> Bool
  (let [(tb (tui/format-thinking-block "Reasoning about AST tree"))]
    (and (string-contains? tb "🧠 [Quarantined Reasoning Channel]")
         (string-contains? tb "Reasoning about AST tree"))))

(df test-context-bar [] -> Bool
  (let [(cb (tui/format-context-bar 4096 131072))]
    (and (string-contains? cb "📊 [Context:")
         (string-contains? cb "4096 / 131072"))))


(df test-reflection-channel [] -> Bool
  (let [(rc (tui/format-reflection-channel "Epistemic calibration and fact reconciliation"))]
    (and (string-contains? rc "🧠 [Quarantined Reflection Channel]")
         (string-contains? rc "Epistemic calibration"))))

(df test-mesh-telemetry [] -> Bool
  (let [(mt (tui/format-mesh-telemetry 120 450 85 45))]
    (and (string-contains? mt "📡 [Mesh Telemetry]")
         (and (string-contains? mt "@scout: 120 tok")
              (and (string-contains? mt "@coder: 450 tok")
                   (string-contains? mt "@reviewer: 85 tok"))))))

(df test-diff-preview [] -> Bool
  (let [(dp (tui/format-diff-preview "src/main.asl" 12 3))]
    (and (string-contains? dp "Δ [src/main.asl]")
         (string-contains? dp "+12 -3 lines"))))

(df test-tui-orchestration-window [] -> Bool
  :d "Verifies terminal UI orchestration window header, reflection channel, tool folding, and context diff bar."
  (let [(hdr (tui/make-tui-header-with-mode "gemma-4-31b-it" "fast" (pol/level-guarded)))
        (h-str (tui/format-tui-header hdr))
        (r-str (tui/format-reflection-channel "Epistemic anchor active"))
        (t-str (tui/format-tool-call "read" "gsa/src/tui.asl" "completed"))
        (c-str (tui/format-context-and-diff-bar 4096 131072 "gsa/src/tui.asl" 15 2))]
    (and (string-contains? h-str "Addie TUI: Orchestration Window")
         (and (string-contains? h-str "Autonomy: ")
              (and (string-contains? r-str "🧠 [Quarantined Reflection Channel]:")
                   (and (string-contains? t-str "▶ [read]")
                        (and (string-contains? c-str "📊 [Context:")
                             (string-contains? c-str "Δ ["))))))))

(df run-tests [] -> Bool
  (do
    (assert (test-tui-header-rendering))
    (assert (test-orchestration-window-header))
    (assert (test-tool-call-folding))
    (assert (test-tool-call-folding-summary))
    (assert (test-spinner-formatting))
    (assert (test-chat-msg-formatting))
    (assert (test-session-summary))
    (assert (test-agent-badge))
    (assert (test-thinking-block))
    (assert (test-reflection-channel))
    (assert (test-mesh-telemetry))
    (assert (test-context-bar))
    (assert (test-diff-preview))
    (assert (test-tui-orchestration-window))))


