(module asl-agent/test-compose-prompt-pool
  :d "Unit test suite for the compose reasoner, unresolved question queue, and prompt context pool."
  :x [test-compose-pool-unresolved
      test-compose-supersede-and-close
      test-compose-lookup-resolution
      test-prompt-pool-retention-and-ttl
      run-all-agent-tests]
  :i [(compose :a cmp)
      (prompt_pool :a pp)])

(df test-compose-pool-unresolved [] -> Bool
  (let [(c0 (cmp/make-empty-composition))
        (q1 (cmp/make-unresolved-question "u1" "Какой порт для API?" (cmp/operator)))
        (q2 (cmp/make-unresolved-question "u2" "Где определена схема базы данных?" (cmp/lookup)))
        (c1 (cmp/add-unresolved-question c0 q1))
        (c2 (cmp/add-unresolved-question c1 q2))
        (f1 (cmp/make-assumed-fact "a1" "Используем порт по умолчанию 8080"))
        (c3 (cmp/add-assumed-fact c2 f1))]
    (assert (= (list-length (.-open-questions c2)) 2) "two open questions added")
    (assert (= (list-length (.-assumed-facts c3)) 1) "one assumed fact added")
    (let [(ctx (cmp/render-composition-context c3))]
      (assert (string-contains? ctx ":open-count 2") "context shows 2 open questions")
      (assert (string-contains? ctx ":assumed-count 1") "context shows 1 assumed fact"))
    true))

(df test-compose-supersede-and-close [] -> Bool
  (let [(c0 (cmp/make-empty-composition))
        (q1 (cmp/make-unresolved-question "u1" "Какой порт?" (cmp/operator)))
        (c1 (cmp/add-unresolved-question c0 q1))
        (c2 (cmp/close-unresolved-question c1 "u1"))
        (f1 (cmp/make-assumed-fact "a1" "staging"))
        (c3 (cmp/add-assumed-fact c2 f1))
        (c4 (cmp/supersede-assumed-fact c3 "a1" "production"))]
    (assert (= (list-length (.-open-questions c2)) 0) "question u1 closed")
    (assert (= (list-length (.-assumed-facts c4)) 1) "assumption updated")
    (let [(updated-fact (list-first (.-assumed-facts c4)))]
      (assert (= (.-claim updated-fact) "production") "assumption superseded with production"))
    true))

(df test-prompt-pool-retention-and-ttl [] -> Bool
  (let [(p0 (pp/make-prompt-pool "chat-42" 3 180000))
        (p1 (pp/record-prompt p0 "первая команда" 1000))
        (p2 (pp/record-prompt p1 "вторая команда" 2000))
        (p3 (pp/record-prompt p2 "третья команда" 3000))
        (p4 (pp/record-prompt p3 "четвертая команда" 4000))]
    (assert (= (list-length (.-entries p4)) 3) "capacity capped at 3 entries")
    (let [(old-pool (pp/make-prompt-pool "chat-old" 3 5000))
          (p-stale (pp/record-prompt old-pool "старый запрос" 1000))
          (active-now (pp/get-active-prompts p-stale 10000))]
      (assert (= (list-length active-now) 0) "stale entry evicted by TTL"))
    (let [(ctx (pp/render-prompt-pool-asn p4 5000))]
      (assert (string-contains? ctx "chat-42") "context renders chat-id")
      (assert (string-contains? ctx ":count 3") "context renders 3 active entries"))
    true))

(df test-compose-lookup-resolution [] -> Bool
  (let [(c0 (cmp/make-empty-composition))
        (q1 (cmp/make-unresolved-question "u1" "Какой порт?" (cmp/operator)))
        (q2 (cmp/make-unresolved-question "u2" "Где определен VadConfig?" (cmp/lookup)))
        (c1 (cmp/add-unresolved-question (cmp/add-unresolved-question c0 q1) q2))
        (lookups (cmp/extract-pending-lookups c1))]
    (assert (= (list-length lookups) 1) "exactly one lookup question extracted")
    (assert (= (.-id (list-first lookups)) "u2") "extracted question is u2")
    (let [(c2 (cmp/resolve-lookup-question c1 "u2" "VadConfig определен в voice/src/voice_settle.asl"))]
      (assert (= (list-length (.-open-questions c2)) 1) "only operator question remains in open pool")
      (assert (= (list-length (.-assumed-facts c2)) 1) "lookup promoted to assumed facts")
      (assert (= (.-claim (list-first (.-assumed-facts c2))) "VadConfig определен в voice/src/voice_settle.asl") "fact claim matches resolution"))
    true))

(df run-all-agent-tests [] -> Bool
  (do
    (test-compose-pool-unresolved)
    (test-compose-supersede-and-close)
    (test-compose-lookup-resolution)
    (test-prompt-pool-retention-and-ttl)
    true))

(run-all-agent-tests)
