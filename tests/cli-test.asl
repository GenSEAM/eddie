(module asl-agent/cli-test
  :d "Unit tests for standalone CLI argument processor, phased inference, and REPL."
  :x [test-cli-options-and-parsing
      test-phased-inference-parameters
      test-telemetry-counters
      test-repl-slash-commands
      test-format-cli-help
      run-tests]
  :i [(cli :a cli) (policy :a pol)])

"run: (run-tests)"

(df test-cli-options-and-parsing [] -> Bool
  (let [(opts (cli/make-cli-options (pol/level-guarded) "gemma-4-31b-it" "make tests green" "" false))]
    (and (== (.-model-id opts) "gemma-4-31b-it")
         (and (not (.-is-repl opts))
              (== (cli/parse-autonomy-flag "ask") (pol/level-ask))))))

(df test-phased-inference-parameters [] -> Bool
  (let [(cfg-insp (cli/get-phased-config (cli/phase-inspect)))
        (cfg-plan (cli/get-phased-config (cli/phase-plan)))
        (cfg-ast (cli/get-phased-config (cli/phase-ast-patch)))
        (cfg-dbg (cli/get-phased-config (cli/phase-reason-debug)))]
    (and (== (.-thinking-budget cfg-insp) 0)
         (and (== (.-thinking-budget cfg-plan) 2048)
              (and (== (.-thinking-budget cfg-ast) 0)
                   (== (.-thinking-budget cfg-dbg) 4096))))))

(df test-telemetry-counters [] -> Bool
  (let [(tel (cli/make-telemetry 14 85.5 0.932 4 4))]
    (and (== (.-ttft-ms tel) 14)
         (and (> (.-tps tel) 50.0)
              (>= (.-kv-cache-hit-ratio tel) 0.90)))))

(df test-repl-slash-commands [] -> Bool
  (and (== (cli/process-repl-command "/exit") "EXIT")
       (and (== (cli/process-repl-command "/quit") "EXIT")
            (and (== (cli/process-repl-command "/clear") "CLEAR")
                 (and (>= (len (cli/process-repl-command "/status")) 10)
                      (>= (len (cli/process-repl-command "/telemetry")) 10))))))

(df test-format-cli-help [] -> Bool
  (let [(h (cli/format-cli-help))]
    (and (>= (len h) 100)
         (== (cli/parse-autonomy-flag "auto") (pol/level-auto)))))

(df run-tests [] -> Bool
  (and (and (test-cli-options-and-parsing)
            (test-phased-inference-parameters))
       (and (test-telemetry-counters)
            (and (test-repl-slash-commands)
                 (test-format-cli-help)))))
