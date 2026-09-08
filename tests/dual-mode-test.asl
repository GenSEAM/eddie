(module asl-agent-tests/dual-mode-test
  :d "Dual-polarity test suite for Simple ReAct mode versus Sovereign Maintainer mode execution routing."
  :x [test-simple-mode-routing
      test-maintainer-mode-routing
      test-cli-simple-flag-selection
      run-tests]
  :i [(agent :a ag) (cli :a cli) (policy :a pol)])

(df test-simple-mode-routing [] -> Bool
  :d "Verifies simple mode executes direct tool step bypass without DAG setup overhead."
  (let [(manifest (pol/make-manifest "/tmp" (list) "/tmp" false))
        (out (ag/run-in-mode (ag/mode-simple) "read config" "/tmp" manifest (pol/level-auto)))]
    (assert (string-starts-with? out "SIMPLE-MODE") "c-mode-pos-001: starts with simple mode prefix")
    (assert (not (string-starts-with? out "MAINTAINER-MODE")) "c-mode-pos-001: not maintainer mode")
    true))

(df test-maintainer-mode-routing [] -> Bool
  :d "Verifies maintainer mode initializes DAG orchestration, model matrix routing, and review envelope."
  (let [(manifest (pol/make-manifest "/tmp" (list) "/tmp" false))
        (out (ag/run-in-mode (ag/mode-maintainer) "refactor auth" "/tmp" manifest (pol/level-auto)))]
    (assert (string-starts-with? out "MAINTAINER-MODE") "c-mode-pos-002: starts with maintainer mode prefix")
    (assert (not (string-starts-with? out "SIMPLE-MODE")) "c-mode-pos-002: not simple mode")
    true))

(df test-cli-simple-flag-selection [] -> Bool
  :d "Verifies CLI options differentiate between default maintainer mode and simple direct mode."
  (let [(opt-simple (cli/make-simple-cli-options (pol/level-auto) "gemma-4-31b-it" "quick-cmd" "" false true))
        (opt-default (cli/make-cli-options (pol/level-auto) "gemma-4-31b-it" "quick-cmd" "" false))]
    (assert (.-is-simple opt-simple) "simple flag is true")
    (assert (not (.-is-simple opt-default)) "default is not simple")
    true))

(df run-tests [] -> Bool
  :d "Executes all dual mode test functions."
  (and (test-simple-mode-routing)
       (and (test-maintainer-mode-routing)
            (test-cli-simple-flag-selection))))
