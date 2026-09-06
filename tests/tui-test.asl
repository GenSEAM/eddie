(module asl-agent/tui-test
  :d "Unit tests for Eddie TUI terminal presentation and tool formatting."
  :x [test-tui-header-rendering
      test-tool-call-folding
      test-spinner-formatting
      test-chat-msg-formatting
      test-session-summary
      run-tests]
  :i [(tui :a tui) (policy :a pol)])

"run: (run-tests)"

(df test-tui-header-rendering [] -> Bool
  (let [(h (tui/make-tui-header "gemma-4-31b-it" (pol/level-guarded)))
        (rendered (tui/format-tui-header h))]
    (and (string-contains? rendered "Eddie TUI")
         (and (string-contains? rendered "gemma-4-31b-it")
              (string-contains? rendered "L1:Guarded")))))

(df test-tool-call-folding [] -> Bool
  (let [(line (tui/format-tool-call "read_file" "src/agent.asl" "ok (120 lines)"))]
    (and (string-contains? line "▶ [read_file]")
         (string-contains? line "src/agent.asl → ok"))))

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

(df run-tests [] -> Bool
  (and (and (test-tui-header-rendering)
            (test-tool-call-folding))
       (and (test-spinner-formatting)
            (and (test-chat-msg-formatting)
                 (test-session-summary)))))
