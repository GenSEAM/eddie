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
    (and (== (.-sliding-idle-ms cfg) 10000)
         (.-non-interactive cfg))))

(df test-supervised-env-injection [] -> Bool
  (let [(env (sup/build-supervised-env true))]
    (>= (len env) 20)))

(df test-sliding-idle-watchdog-activity [] -> Bool
  (and (sup/check-process-activity 1000 5000 10000)
       (not (sup/check-process-activity 1000 15000 10000))))

(df test-deadlock-trapping-receipt [] -> Bool
  (let [(rcpt (sup/trap-interactive-deadlock "prompt: Do you want to proceed? [y/N]" 12000))]
    (and (.-is-deadlock rcpt)
         (== (.-exit-code rcpt) 124))))

(df test-execute-supervised-completion [] -> Bool
  (let [(cfg (sup/make-supervisor-config 10000 900000 true))
        (rcpt-ok (sup/execute-supervised "asl test app.asl" 2000 cfg))
        (rcpt-stalled (sup/execute-supervised "read -p 'Name:'" 15000 cfg))]
    (and (not (.-is-deadlock rcpt-ok))
         (.-is-deadlock rcpt-stalled))))

(df run-tests [] -> Bool
  (and (and (test-supervisor-config)
            (test-supervised-env-injection))
       (and (test-sliding-idle-watchdog-activity)
            (and (test-deadlock-trapping-receipt)
                 (test-execute-supervised-completion)))))
