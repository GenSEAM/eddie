(module asl-agent/supervisor-test
  :d "Unit tests for feedback process supervisor and 10s sliding idle watchdog."
  :x [test-supervisor-config
      test-supervised-env-injection
      test-sliding-idle-watchdog-activity
      test-deadlock-trapping-receipt
      test-execute-supervised-completion
      run-tests]
  :i [(supervisor :a sup)])

"run: (run-tests)"

(df test-supervisor-config [] -> Bool
  (let [(cfg (sup/make-supervisor-config 10000 900000 true))]
    (assert (= (.-sliding-idle-ms cfg) 10000) "sliding idle ms is 10000")
    (assert (.-non-interactive cfg) "non-interactive flag is true")
    true))

(df test-supervised-env-injection [] -> Bool
  (let [(env (sup/build-supervised-env true))]
    (assert (>= (string-length env) 20) "supervised env length >= 20")
    true))

(df test-sliding-idle-watchdog-activity [] -> Bool
  (do
    (assert (sup/check-process-activity 1000 5000 10000) "active within idle threshold")
    (assert (not (sup/check-process-activity 1000 15000 10000)) "inactive exceeding idle threshold")
    true))

(df test-deadlock-trapping-receipt [] -> Bool
  (let [(rcpt (sup/trap-interactive-deadlock "prompt: Do you want to proceed? [y/N]" 12000))]
    (assert (.-is-deadlock rcpt) "interactive prompt detected as deadlock")
    (assert (= (.-exit-code rcpt) 124) "exit code is 124")
    true))

(df test-execute-supervised-completion [] -> Bool
  (let [(cfg (sup/make-supervisor-config 10000 900000 true))
        (rcpt-ok (sup/execute-supervised "asl test app.asl" 2000 cfg))
        (rcpt-stalled (sup/execute-supervised "read -p 'Name:'" 15000 cfg))]
    (assert (not (.-is-deadlock rcpt-ok)) "normal execution not deadlock")
    (assert (.-is-deadlock rcpt-stalled) "stalled execution marked deadlock")
    true))

(df run-tests [] -> Bool
  (do
    (test-supervisor-config)
    (test-supervised-env-injection)
    (test-sliding-idle-watchdog-activity)
    (test-deadlock-trapping-receipt)
    (test-execute-supervised-completion)
    true))
