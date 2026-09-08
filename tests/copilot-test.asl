(module asl-agent/copilot-test
  :d "Unit tests for perceptual pointer dereferencing, shadow staging, and intent traceability."
  :x [test-pointer-dereference
      test-staging-lifecycle
      test-intent-recording-querying
      test-trace-verification
      run-tests]
  :i [(copilot :a cop)])

(df test-pointer-dereference [] -> Bool
  (let [(ptr (cop/make-pointer "b3-dom-01" (cop/ptr-dom) "Login form DOM tree" "sha256:abcd"))
        (fact (cop/dereference-pointer ptr "submit_button_visible"))]
    (assert (>= (string-length fact) 20) "fact length >= 20")
    true))

(df test-staging-lifecycle [] -> Bool
  (let [(prop (cop/make-proposal "branch-alpha" "decisions.asn" "(:dec :id 1)"))
        (path (cop/stage-proposal prop))
        (committed (cop/commit-staged-proposal prop))]
    (assert (>= (string-length path) 15) "path length >= 15")
    (assert (.-is-committed committed) "proposal is committed")
    true))

(df test-intent-recording-querying [] -> Bool
  (let [(rec (cop/intent-record "decision" "dec:001" "ASL Native" "docs/ADR.md:1"))
        (qry (cop/intent-query "dec:001" "fulfills"))]
    (assert (>= (string-length rec) 20) "rec length >= 20")
    (assert (>= (string-length qry) 20) "qry length >= 20")
    true))

(df test-trace-verification [] -> Bool
  (do
    (assert (cop/trace-verify "eddie-run") "trace verify eddie-run")
    (assert (not (cop/trace-verify "")) "trace verify empty fails")
    true))

(df run-tests [] -> Bool
  (do
    (assert (test-pointer-dereference) "test-pointer-dereference must pass")
    (assert (test-staging-lifecycle) "test-staging-lifecycle must pass")
    (assert (test-intent-recording-querying) "test-intent-recording-querying must pass")
    (assert (test-trace-verification) "test-trace-verification must pass")
    true))
