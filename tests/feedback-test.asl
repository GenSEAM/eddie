(module asl-eddie/feedback-test
  :d "Unit tests for zero-fluff feedback and requirement refinement engine."
  :x [test-ambiguity-detection
      test-strip-polite-fluff
      test-refine-prompt
      test-clarifying-question-format
      test-concise-directive-format
      run-tests]
  :i [(feedback :a fb)])

"run: (run-tests)"

(df test-ambiguity-detection [] -> Bool
  (let [(short-p (fb/is-ambiguous-prompt? "fix bug"))
        (no-file-p (fb/is-ambiguous-prompt? "please optimize this calculation"))
        (clear-p (fb/is-ambiguous-prompt? "run tests on src/main.asl and fix assertion"))]
    (and (and short-p no-file-p)
         (not clear-p))))

(df test-strip-polite-fluff [] -> Bool
  (let [(fluffy "Certainly! I'd be happy to help with that. Please update policy.asl")
        (clean (fb/strip-polite-fluff fluffy))]
    (and (not (string-contains? clean "Certainly"))
         (string-contains? clean "Please update policy.asl"))))

(df test-refine-prompt [] -> Bool
  (let [(req (fb/refine-user-prompt "Refactor eddie/src/agent.asl with new methods" (list "eddie/src/agent.asl")))]
    (and (not (.-is-ambiguous req))
         (= (list-length (.-target-files req)) 1))))

(df test-clarifying-question-format [] -> Bool
  (let [(req (fb/refine-user-prompt "make game" (list)))
        (opts (list (fb/ClarificationOption :key "1" :label "Terminal Snake in ASL")
                    (fb/ClarificationOption :key "2" :label "Text RPG in TypeScript")))
        (q (fb/format-clarifying-question req opts))]
    (and (string-contains? q "Need clarification")
         (and (string-contains? q "[1] Terminal Snake in ASL")
              (string-contains? q "[2] Text RPG in TypeScript")))))

(df test-concise-directive-format [] -> Bool
  (let [(req (fb/refine-user-prompt "Patch repl.asl" (list "harness/src/repl.asl")))
        (dir (fb/format-concise-directive req))]
    (and (string-contains? dir "Goal: Patch repl.asl")
         (string-contains? dir "Targets: 1 files"))))

(df run-tests [] -> Bool
  (and (and (test-ambiguity-detection)
            (test-strip-polite-fluff))
       (and (test-refine-prompt)
            (and (test-clarifying-question-format)
                 (test-concise-directive-format)))))
