(module asl-agent/test-shrody-asn-translation-bench
  :d "Benchmark and verification suite evaluating ASN translation accuracy and speed against Shrody benchmark cases"
  :x [test-shrody-release-cases
      test-shrody-admin-cases
      test-shrody-dev-cases
      test-multilingual-codeswitch-cases
      test-intel-and-meta-queries
      test-asn-sexp-rendering-balance
      test-multilingual-detection-matrix
      run-all-bench-tests]
  :i [(asn_translator :a tr)
      (multilingual_matrix :a mm)])

(df test-shrody-release-cases [] -> Bool
  (let [(f1 (tr/translate-prompt-to-asn "го"))
        (f2 (tr/translate-prompt-to-asn "давай"))
        (f3 (tr/translate-prompt-to-asn "send it"))
        (f4 (tr/translate-prompt-to-asn "that's it"))]
    (assert (= (.-disposition f1) "release") "го yields release disposition")
    (assert (= (.-disposition f2) "release") "давай yields release disposition")
    (assert (= (.-disposition f3) "release") "send it yields release disposition")
    (assert (= (.-disposition f4) "release") "that's it yields release disposition")
    (assert (= (.-kind f1) "fast-path") "release is fast-path")
    true))

(df test-shrody-admin-cases [] -> Bool
  (let [(f1 (tr/translate-prompt-to-asn "unregister vtbot"))
        (f2 (tr/translate-prompt-to-asn "переключись на проект vtbot"))]
    (assert (= (.-disposition f1) "admin") "unregister yields admin disposition")
    (assert (= (.-disposition f2) "admin") "переключись yields admin disposition")
    (assert (= (.-project-target f1) "vtbot") "target is vtbot")
    (assert (= (.-project-target f2) "vtbot") "target is vtbot")
    true))

(df test-shrody-dev-cases [] -> Bool
  (let [(f-en (tr/translate-prompt-to-asn "fix the flaky login test in agentube"))
        (f-ru (tr/translate-prompt-to-asn "добавь ретрай в datahub-core"))]
    (assert (= (.-kind f-en) "dev") "english dev command classified as dev")
    (assert (= (.-project-target f-en) "agentube") "target project is agentube")
    (assert (.-requires-worktree f-en) "agentube dev task requires worktree")
    (assert (.-requires-gate f-en) "agentube dev task requires verification gate")
    (assert (= (.-kind f-ru) "dev") "russian dev command classified as dev")
    (assert (= (.-project-target f-ru) "datahub-core") "target project is datahub-core")
    true))

(df test-multilingual-codeswitch-cases [] -> Bool
  (let [(f-mix (tr/translate-prompt-to-asn "ну эээ сделай git commit и push в vtbot"))]
    (assert (= (.-kind f-mix) "dev") "mixed codeswitch classified as dev")
    (assert (= (.-project-target f-mix) "vtbot") "project target extracted as vtbot")
    (assert (not (string-contains? (.-goal f-mix) "ну")) "fillers stripped from goal")
    (assert (string-contains? (.-goal f-mix) "commit") "commit token preserved")
    true))

(df test-intel-and-meta-queries [] -> Bool
  (let [(f-intel (tr/translate-prompt-to-asn "где находится символ VadConfig в asex"))
        (f-meta-ru (tr/translate-prompt-to-asn "что сейчас выполняется"))
        (f-meta-en (tr/translate-prompt-to-asn "what is running"))]
    (assert (= (.-kind f-intel) "intel") "intel query classified")
    (assert (= (.-project-target f-intel) "asex") "asex project target extracted")
    (assert (= (.-disposition f-intel) "query") "query disposition")
    (assert (= (.-kind f-meta-ru) "meta") "russian meta query classified")
    (assert (= (.-kind f-meta-en) "meta") "english meta query classified")
    true))

(df test-asn-sexp-rendering-balance [] -> Bool
  (let [(frame (tr/make-asn-intent-frame "intent-01" "dev" "vtbot" "new" "add poller retry" true true))
        (sexp (tr/render-asn-intent-sexp frame))]
    (assert (string-starts-with? sexp "(:intent") "rendered sexp starts with (:intent")
    (assert (string-ends-with? sexp ")") "rendered sexp ends with balanced paren")
    (assert (string-contains? sexp ":project \"vtbot\"") "rendered sexp contains project")
    (assert (string-contains? sexp ":requires-worktree true") "rendered sexp contains worktree flag")
    true))

(df test-multilingual-detection-matrix [] -> Bool
  (let [(d-en (mm/detect-language-dialect "run the verification gate"))
        (d-ru (mm/detect-language-dialect "запусти проверку гейтов"))
        (d-mix (mm/detect-language-dialect "запусти build и tests в asex"))
        (cfg-mix (mm/make-multilingual-config (mm/locale-mixed-codeswitch)))
        (engine (mm/resolve-speech-engine cfg-mix d-mix))]
    (assert (= (.-detected-dialect d-en) (mm/locale-en-primary)) "detected english dialect")
    (assert (= (.-detected-dialect d-ru) (mm/locale-ru-native)) "detected russian dialect")
    (assert (= (.-detected-dialect d-mix) (mm/locale-mixed-codeswitch)) "detected mixed codeswitch dialect")
    (assert (= engine "silero-ru") "mixed dialect with cyrillic routes to silero-ru")
    true))

(df run-all-bench-tests [] -> Bool
  (do
    (test-shrody-release-cases)
    (test-shrody-admin-cases)
    (test-shrody-dev-cases)
    (test-multilingual-codeswitch-cases)
    (test-intel-and-meta-queries)
    (test-asn-sexp-rendering-balance)
    (test-multilingual-detection-matrix)
    true))

(run-all-bench-tests)
