(module asl-agent/test
  :d "Unit tests for asl-agent autonomous agent: policy sandbox, triage, and ReAct loop."
  :x [run-tests main]
  :i [(policy :a pol) (triage :a tr) (agent :a ag)])

(df test-policy-sandbox [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list "/workspace/tree") "/tmp" false))
        (p1 (pol/check-permission "read" "/workspace/src/app.asl" m))
        (p2 (pol/check-permission "write" "/etc/passwd" m))
        (p3 (pol/check-permission "write" "/workspace/../escape" m))]
    (assert (.-allowed p1) "read allowed")
    (assert (not (.-allowed p2)) "passwd write blocked")
    (assert (not (.-allowed p3)) "escape write blocked")
    true))

(df test-triage-collapse [] -> Bool
  (let [(ctx (tr/make-workspace-context "asl" "/workspace" true (list "asl")))
        (d1 (tr/triage-request "fix and test and refactor core" ctx))]
    (assert (= (.-shape d1) "single") "shape is single")
    (assert (= (.-kind d1) "dev") "kind is dev")
    true))

(df test-agent-react-step [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (sess (ag/make-agent-session "inspect repo" m))
        (res (ag/step-agent sess "fs:read" "/workspace/src/app.asl" "dummy payload"))]
    (assert (.-success res) "step-agent success")
    true))

(df run-tests [] -> Bool
  :d "Runs all agent tests."
  (do
    (assert (test-policy-sandbox) "test-policy-sandbox must pass")
    (assert (test-triage-collapse) "test-triage-collapse must pass")
    (assert (test-agent-react-step) "test-agent-react-step must pass")
    true))

(df ! main [(args (List Str))] -> (Result Unit IoError)
  :d "Runs unit tests for asl-agent agent suite."
  (if (run-tests)
    (let [(u (println "asl-agent agent tests passed cleanly"))]
      (ok ()))
    (let [(u (eprintln "asl-agent agent test failure"))]
      (err (other)))))
