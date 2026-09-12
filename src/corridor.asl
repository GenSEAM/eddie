(module asl-agent/corridor
  :d "Freedom Corridor contract engine formalizing immutable invariants, degrees of creative exploration, and falsifiable acceptance gates."
  :x [FreedomCorridor
      make-corridor default-corridor is-action-permitted-by-corridor?
      format-corridor-summary corridor-to-asn]
  :i [])

(dfs FreedomCorridor
  (:f corridor-id Str "Unique corridor contract identifier e.g. corr-auth-01")
  (:f immutable-invariants (List Str) "Mandatory constraints that must never be violated")
  (:f allowed-explorations (List Str) "Design and implementation degrees of freedom")
  (:f acceptance-criteria (List Str) "Falsifiable acceptance verification criteria")
  (:f max-review-rounds I64 "Hard ceiling for mutual review ping-pong (default 2)")
  (:f max-step-budget I64 "Maximum permitted execution step ceiling"))

(df make-corridor [(id Str) (invariants (List Str)) (explorations (List Str)) (criteria (List Str))] -> FreedomCorridor
  :d "Constructs an initialized FreedomCorridor record with default budgets."
  (FreedomCorridor
    :corridor-id id
    :immutable-invariants invariants
    :allowed-explorations explorations
    :acceptance-criteria criteria
    :max-review-rounds 2
    :max-step-budget 20))

(df default-corridor [(id Str)] -> FreedomCorridor
  :d "Constructs the standard system corridor enforcing zero-comment, zero-emoji, and gate preservation."
  (make-corridor
    id
    (list "C0001: zero comments in ASL"
          "C0002: zero emojis in ASN"
          "gate-integrity: zero gate weakening"
          "pure-asl: zero foreign code in packages")
    (list "ast-refactoring: structural AST edits permitted"
          "ui-composition: VDOM and terminal TUI exploration permitted"
          "model-routing: multi-model selection per task role permitted"
          "test-expansion: authoring dual-polarity test suites permitted")
    (list "all 7 verification gates pass cleanly"
          "test coverage >= 90.0%"
          "zero vacuous assertions")))

(df is-action-permitted-by-corridor? [(corridor FreedomCorridor) (action-desc Str) (target-path Str)] -> Bool
  :d "Validates proposed worker action against the immutable invariants of the corridor."
  (let [(act (string-lower action-desc))]
    (cond
      ((string-contains? act "weaken") false)
      ((string-contains? act "loosen") false)
      ((string-contains? act "skip gate") false)
      ((string-contains? act "bypass gate") false)
      ((string-contains? act "add comment") false)
      ((string-contains? act "insert comment") false)
      ((string-contains? act "delete test") false)
      ((string-contains? act "skip test") false)
      ((string-contains? act "rubber-stamp") false)
      (:else true))))

(df format-corridor-summary [(corridor FreedomCorridor)] -> Str
  :d "Renders compact token-efficient diagnostic summary of corridor boundaries."
  (str "Corridor [" (.-corridor-id corridor) "]: Invariants ("
       (string-from-int64 (list-length (.-immutable-invariants corridor))) "), Explorations ("
       (string-from-int64 (list-length (.-allowed-explorations corridor))) "), Criteria ("
       (string-from-int64 (list-length (.-acceptance-criteria corridor))) "), Review Ceiling ("
       (string-from-int64 (.-max-review-rounds corridor)) " rounds)"))

(df corridor-to-asn [(corridor FreedomCorridor)] -> Str
  :d "Serializes FreedomCorridor to canonical ASN S-expression format for persistent memory grounding."
  (let [(inv-str (fold (fn [(acc Str) (inv Str)] -> Str (str acc "\"" inv "\" ")) "" (.-immutable-invariants corridor)))
        (exp-str (fold (fn [(acc Str) (exp Str)] -> Str (str acc "\"" exp "\" ")) "" (.-allowed-explorations corridor)))
        (crt-str (fold (fn [(acc Str) (crt Str)] -> Str (str acc "\"" crt "\" ")) "" (.-acceptance-criteria corridor)))]
    (str "(:corridor :id \"" (.-corridor-id corridor)
         "\" :max-reviews " (string-from-int64 (.-max-review-rounds corridor))
         " :invariants [" (string-trim inv-str)
         "] :explorations [" (string-trim exp-str)
         "] :criteria [" (string-trim crt-str) "])")))
