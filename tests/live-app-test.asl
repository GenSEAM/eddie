(module asl-agent/live-app-test
  :d "End-to-end integration test verifying Eddie autonomous coding agent on real game application in sandbox."
  :x [test-live-game-specification
      test-live-game-execution-loop
      test-live-game-tui-telemetry
      run-tests]
  :i [(policy :a pol) (agent :a ag) (feedback :a fb) (tui :a tui) (eddie :a ed)])

"run: (run-tests)"

(df test-live-game-specification [] -> Bool
  (let [(raw-prompt "Please build a terminal snake game with collision detection and unit tests.")
        (req (fb/refine-user-prompt raw-prompt (list "scratch/test-app/src/snake.asl" "scratch/test-app/tests/snake-test.asl")))]
    (and (not (.-is-ambiguous req))
         (and (= (list-length (.-target-files req)) 2)
              (string-contains? (.-clarified-goal req) "terminal snake game")))))

(df test-live-game-execution-loop [] -> Bool
  (let [(ws "/Users/purplelephant/projects/asex/scratch/test-app")
        (m (pol/make-manifest ws (list) "/tmp" false))
        (sess (ag/make-autonomy-session "build snake game" m (pol/level-auto)))
        (s1 (ag/step-agent sess "read" (str ws "/src/snake.asl") ""))
        (s2 (ag/step-agent (.-session s1) "test" (str ws "/tests/snake-test.asl") ""))
        (s3 (ag/step-agent (.-session s2) "finish" "" "Snake game engine and tests verified passing"))]
    (and (.-success s1)
         (and (.-success s2)
              (and (.-success s3)
                   (.-is-terminal (.-state (.-session s3))))))))

(df test-live-game-tui-telemetry [] -> Bool
  (let [(h (tui/make-tui-header "gemma-4-31b-it" (pol/level-auto)))
        (folding1 (tui/format-tool-call "read" "src/snake.asl" "ok (60 lines)"))
        (folding2 (tui/format-tool-call "test" "tests/snake-test.asl" "passing (5/5 assertions)"))
        (summary (tui/format-session-summary h 3))]
    (and (string-contains? (tui/format-tui-header h) "Eddie TUI")
         (and (string-contains? folding1 "▶ [read]")
              (and (string-contains? folding2 "▶ [test]")
                   (string-contains? summary "✔ Session complete"))))))

(df run-tests [] -> Bool
  (and (and (test-live-game-specification)
            (test-live-game-execution-loop))
       (test-live-game-tui-telemetry)))
