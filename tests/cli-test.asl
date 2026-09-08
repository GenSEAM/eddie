(module asl-agent/cli-test
  :d "Unit tests for standalone CLI argument processor, phased inference, and REPL."
  :x [test-cli-options-and-parsing
      test-phased-inference-parameters
      test-telemetry-counters
      test-repl-slash-commands
      test-format-cli-help
      run-tests]
  :i [(cli :a cli) (policy :a pol)])

(df test-cli-options-and-parsing [] -> Bool
  (let [(opts (cli/make-cli-options (pol/level-guarded) "gemma-4-31b-it" "make tests green" "" false))]
    (assert (= (.-model-id opts) "gemma-4-31b-it") "model id")
    (assert (not (.-is-repl opts)) "not repl")
    (assert (= (cli/parse-autonomy-flag "ask") (pol/level-ask)) "autonomy ask")
    true))

(df test-phased-inference-parameters [] -> Bool
  (let [(cfg-insp (cli/get-phased-config (cli/phase-inspect)))
        (cfg-plan (cli/get-phased-config (cli/phase-plan)))
        (cfg-ast (cli/get-phased-config (cli/phase-ast-patch)))
        (cfg-dbg (cli/get-phased-config (cli/phase-reason-debug)))]
    (assert (= (.-thinking-budget cfg-insp) 0) "inspect budget 0")
    (assert (= (.-thinking-budget cfg-plan) 2048) "plan budget 2048")
    (assert (= (.-thinking-budget cfg-ast) 0) "ast budget 0")
    (assert (= (.-thinking-budget cfg-dbg) 4096) "dbg budget 4096")
    true))

(df test-telemetry-counters [] -> Bool
  (let [(tel (cli/make-telemetry 14 85.5 0.932 4 4))]
    (assert (= (.-ttft-ms tel) 14) "ttft-ms 14")
    (assert (> (.-tps tel) 50.0) "tps > 50")
    (assert (>= (.-kv-cache-hit-ratio tel) 0.90) "kv cache hit ratio >= 0.90")
    true))

(df test-repl-slash-commands [] -> Bool
  (do
    (assert (= (cli/process-repl-command "/exit") "EXIT") "/exit")
    (assert (= (cli/process-repl-command "/quit") "EXIT") "/quit")
    (assert (= (cli/process-repl-command "/clear") "CLEAR") "/clear")
    (assert (>= (string-length (cli/process-repl-command "/status")) 10) "/status length")
    (assert (>= (string-length (cli/process-repl-command "/telemetry")) 10) "/telemetry length")
    true))

(df test-format-cli-help [] -> Bool
  (let [(h (cli/format-cli-help))]
    (assert (>= (string-length h) 100) "help length >= 100")
    (assert (= (cli/parse-autonomy-flag "auto") (pol/level-auto)) "parse auto flag")
    true))

(df run-tests [] -> Bool
  (do
    (assert (test-cli-options-and-parsing) "test-cli-options-and-parsing must pass")
    (assert (test-phased-inference-parameters) "test-phased-inference-parameters must pass")
    (assert (test-telemetry-counters) "test-telemetry-counters must pass")
    (assert (test-repl-slash-commands) "test-repl-slash-commands must pass")
    (assert (test-format-cli-help) "test-format-cli-help must pass")
    true))
