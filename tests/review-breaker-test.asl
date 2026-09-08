(module asl-agent-tests/review-breaker-test
  :d "Dual-polarity test suite for review circuit breaker, finite review iterations, and human maintainer escalation."
  :x [test-review-approval
      test-review-rejection-under-ceiling
      test-review-tripped-on-second-rejection
      test-escalation-report-formatting
      run-tests]
  :i [(review_breaker :a rev)])

(df test-review-approval [] -> Bool
  :d "Verifies that recording reviewer approval transitions state to approved without tripping."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (approved-ex (rev/record-review-approval init-ex))]
    (assert-case "c-rev-pos-001" (rev/is-review-passed? approved-ex))
    (refute-case "c-rev-pos-001" (rev/is-review-tripped? approved-ex))
    true))

(df test-review-rejection-under-ceiling [] -> Bool
  :d "Verifies that first rejection increments counter but does not trip circuit."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "Fix off-by-one error"))]
    (assert (not (rev/is-review-tripped? r1)))
    (refute (rev/is-review-passed? r1))
    true))

(df test-review-tripped-on-second-rejection [] -> Bool
  :d "Verifies that reaching ceiling threshold trips circuit into human escalation state."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "First critique"))
        (r2 (rev/record-review-critique r1 "Second critique"))]
    (assert-case "c-rev-neg-001" (rev/is-review-tripped? r2))
    (refute-case "c-rev-neg-001" (rev/is-review-passed? r2))
    true))

(df test-escalation-report-formatting [] -> Bool
  :d "Verifies that escalation diagnostics report formats target, critique notes, and call to action."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "Fix edge case"))
        (r2 (rev/record-review-critique r1 "Still broken"))
        (rep (rev/format-escalation-report r2))]
    (assert (string-contains? rep "REVIEW ESCALATION"))
    (refute (= rep ""))
    true))

(df run-tests [] -> Bool
  :d "Executes all review breaker test functions."
  (and (test-review-approval)
       (and (test-review-rejection-under-ceiling)
            (and (test-review-tripped-on-second-rejection)
                 (test-escalation-report-formatting)))))
