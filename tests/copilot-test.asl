(module asl-agent/copilot-test
  :d "Unit tests for perceptual pointer dereferencing, shadow staging, and intent traceability."
  :x [test-pointer-dereference
      test-staging-lifecycle
      test-intent-recording-querying
      test-trace-verification
      run-tests]
  :i [(copilot :a cop)])

"run: (run-tests)"

(df test-pointer-dereference [] -> Bool
  (let [(ptr (cop/make-pointer "b3-dom-01" (cop/ptr-dom) "Login form DOM tree" "sha256:abcd"))
        (fact (cop/dereference-pointer ptr "submit_button_visible"))]
    (>= (len fact) 20)))

(df test-staging-lifecycle [] -> Bool
  (let [(prop (cop/make-proposal "branch-alpha" "decisions.asn" "(:dec :id 1)"))
        (path (cop/stage-proposal prop))
        (committed (cop/commit-staged-proposal prop))]
    (and (>= (len path) 15)
         (.-is-committed committed))))

(df test-intent-recording-querying [] -> Bool
  (let [(rec (cop/intent-record "decision" "dec:001" "ASL Native" "docs/ADR.md:1"))
        (qry (cop/intent-query "dec:001" "fulfills"))]
    (and (>= (len rec) 20)
         (>= (len qry) 20))))

(df test-trace-verification [] -> Bool
  (and (cop/trace-verify "eddie-run")
       (not (cop/trace-verify ""))))

(df run-tests [] -> Bool
  (and (and (test-pointer-dereference)
            (test-staging-lifecycle))
       (and (test-intent-recording-querying)
            (test-trace-verification))))
