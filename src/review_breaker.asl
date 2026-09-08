(module asl-agent/review-breaker
  :d "Review circuit breaker and anti-thrash escalation guard enforcing finite peer review iterations."
  :x [ReviewDecision ReviewExchange
      rev-approved rev-rejected rev-escalated
      make-review-exchange record-review-critique record-review-approval
      is-review-tripped? is-review-passed? format-escalation-report]
  :i [])

(dfe ReviewDecision
  (:c rev-approved [] "Review passed cleanly, implementation approved")
  (:c rev-rejected [] "Review rejected with feedback, returned for revision")
  (:c rev-escalated [] "Review iterations exhausted, escalated to human maintainer"))

(dfs ReviewExchange
  (:f round-idx I64 "Current review round index starting at 1")
  (:f max-rounds I64 "Hard ceiling for mutual review ping-pong (default 2)")
  (:f draft-summary Str "Summary of artifact or code under review")
  (:f rejection-count I64 "Number of consecutive reviewer rejections")
  (:f last-critique Str "Most recent critique diagnostic notes")
  (:f decision ReviewDecision "Current review verdict"))

(df make-review-exchange [(draft-summary Str) (max-rounds I64)] -> ReviewExchange
  :d "Constructs an initialized ReviewExchange state with ceiling limit."
  (let [(limit (if (<= max-rounds 0) 2 max-rounds))]
    (ReviewExchange
      :round-idx 1
      :max-rounds limit
      :draft-summary draft-summary
      :rejection-count 0
      :last-critique ""
      :decision (rev-rejected))))

(df record-review-critique [(ex ReviewExchange) (critique Str)] -> ReviewExchange
  :d "Records a reviewer rejection, incrementing failure counter and tripping circuit on threshold."
  (let [(new-rejections (+ (.-rejection-count ex) 1))
        (cur-round (.-round-idx ex))
        (limit (.-max-rounds ex))
        (is-tripped (>= new-rejections limit))
        (new-decision (if is-tripped (rev-escalated) (rev-rejected)))]
    (ReviewExchange
      :round-idx (+ cur-round 1)
      :max-rounds limit
      :draft-summary (.-draft-summary ex)
      :rejection-count new-rejections
      :last-critique critique
      :decision new-decision)))

(df record-review-approval [(ex ReviewExchange)] -> ReviewExchange
  :d "Records full reviewer approval settling the exchange in clean approved state."
  (ReviewExchange
    :round-idx (.-round-idx ex)
    :max-rounds (.-max-rounds ex)
    :draft-summary (.-draft-summary ex)
    :rejection-count (.-rejection-count ex)
    :last-critique ""
    :decision (rev-approved)))

(df is-review-tripped? [(ex ReviewExchange)] -> Bool
  :d "Returns true if review breaker has tripped and requires human maintainer intervention."
  (mt (.-decision ex)
    ((rev-escalated) true)
    ((rev-approved) false)
    ((rev-rejected) false)))

(df is-review-passed? [(ex ReviewExchange)] -> Bool
  :d "Returns true if review has been explicitly approved."
  (mt (.-decision ex)
    ((rev-approved) true)
    ((rev-escalated) false)
    ((rev-rejected) false)))

(df format-escalation-report [(ex ReviewExchange)] -> Str
  :d "Renders a compact diagnostic report for the human maintainer upon circuit trip."
  (str "REVIEW ESCALATION: Mutual review ceiling reached (" (string-from-int64 (.-rejection-count ex))
       "/" (string-from-int64 (.-max-rounds ex)) " rounds). Target: \"" (.-draft-summary ex)
       "\" | Last critique: " (.-last-critique ex) " | Awaiting human maintainer direction."))
