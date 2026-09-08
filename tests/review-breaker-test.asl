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
    (assert (rev/is-review-passed? approved-ex) "c-rev-pos-001: review approved")
    (assert (not (rev/is-review-tripped? approved-ex)) "c-rev-pos-001: approved not tripped")
    true))

(df test-review-rejection-under-ceiling [] -> Bool
  :d "Verifies that first rejection increments counter but does not trip circuit."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "Fix off-by-one error"))]
    (assert (not (rev/is-review-tripped? r1)) "single rejection not tripped")
    (assert (not (rev/is-review-passed? r1)) "single rejection not passed")
    true))

(df test-review-tripped-on-second-rejection [] -> Bool
  :d "Verifies that reaching ceiling threshold trips circuit into human escalation state."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "First critique"))
        (r2 (rev/record-review-critique r1 "Second critique"))]
    (assert (rev/is-review-tripped? r2) "c-rev-neg-001: review tripped on second rejection")
    (assert (not (rev/is-review-passed? r2)) "c-rev-neg-001: tripped is not passed")
    true))

(df test-escalation-report-formatting [] -> Bool
  :d "Verifies that escalation diagnostics report formats target, critique notes, and call to action."
  (let [(init-ex (rev/make-review-exchange "Draft feature" 2))
        (r1 (rev/record-review-critique init-ex "Fix edge case"))
        (r2 (rev/record-review-critique r1 "Still broken"))
        (rep (rev/format-escalation-report r2))]
    (assert (string-contains? rep "REVIEW ESCALATION") "report contains header")
    (assert (not (= rep "")) "report not empty")
    true))

(df run-tests [] -> Bool
  :d "Executes all review breaker test functions."
  (and (test-review-approval)
       (and (test-review-rejection-under-ceiling)
            (and (test-review-tripped-on-second-rejection)
                 (test-escalation-report-formatting)))))
