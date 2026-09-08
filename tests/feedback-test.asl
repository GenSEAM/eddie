(module asl-agent/feedback-test
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
    (assert short-p "short prompt without target should be ambiguous")
    (assert no-file-p "prompt without file should be ambiguous")
    (assert (not clear-p) "prompt with file and action should not be ambiguous")
    true))

(df test-strip-polite-fluff [] -> Bool
  (let [(fluffy "Certainly! I'd be happy to help with that. Please update policy.asl")
        (clean (fb/strip-polite-fluff fluffy))]
    (assert (not (string-contains? clean "Certainly")) "strip polite fluff removes Certainly")
    (assert (string-contains? clean "Please update policy.asl") "strip polite fluff keeps core content")
    true))

(df test-refine-prompt [] -> Bool
  (let [(req (fb/refine-user-prompt "Refactor eddie/src/agent.asl with new methods" (list "eddie/src/agent.asl")))]
    (assert (not (.-is-ambiguous req)) "specific request is not ambiguous")
    (assert (= (list-length (.-target-files req)) 1) "exactly one target file")
    true))

(df test-clarifying-question-format [] -> Bool
  (let [(req (fb/refine-user-prompt "make game" (list)))
        (opts (list (fb/ClarificationOption :key "1" :label "Terminal Snake in ASL")
                    (fb/ClarificationOption :key "2" :label "Text RPG in TypeScript")))
        (q (fb/format-clarifying-question req opts))]
    (assert (string-contains? q "Need clarification") "contains clarification heading")
    (assert (string-contains? q "[1] Terminal Snake in ASL") "contains option 1")
    (assert (string-contains? q "[2] Text RPG in TypeScript") "contains option 2")
    true))

(df test-concise-directive-format [] -> Bool
  (let [(req (fb/refine-user-prompt "Patch the harness repl.asl module" (list "harness/src/repl.asl")))
        (dir (fb/format-concise-directive req))]
    (assert (string-contains? dir "Goal: Patch the harness repl.asl module") "contains goal")
    (assert (string-contains? dir "Targets: 1 files") "contains target file count")
    true))

(df run-tests [] -> Bool
  (do
    (test-ambiguity-detection)
    (test-strip-polite-fluff)
    (test-refine-prompt)
    (test-clarifying-question-format)
    (test-concise-directive-format)
    true))
