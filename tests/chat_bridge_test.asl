(module asl-agent/test-chat-bridge
  :d "Unit verification test suite for Real-Time Chat Prompt Streamer, Anaphora Context, and Barge-In Abort"
  :x [test-chat-ingress-creation-and-formatting
      test-anaphora-shorthand-resolution
      test-chat-streaming-and-history-bounding
      test-barge-in-interruption-abort
      run-all-chat-tests]
  :i [(chat_bridge :a cb)])

(df test-chat-ingress-creation-and-formatting [] -> Bool
  (let [(env (cb/make-chat-ingress "sess-1" "ну запусти тест" "запусти тест" "ru" "dev" "запусти тест" 1773910000000))
        (asn-repr (cb/format-chat-ingress-asn env))]
    (assert (.-source-voice env) "source is marked as voice")
    (assert (= (.-session-id env) "sess-1") "session-id matches")
    (assert (string-contains? asn-repr ":session \"sess-1\"") "asn contains session")
    (assert (string-contains? asn-repr ":intent \"dev\"") "asn contains intent")
    (assert (string-contains? asn-repr ":locale \"ru\"") "asn contains locale")
    (assert (string-contains? asn-repr ":prompt \"запусти тест\"") "asn contains prompt")
    true))

(df test-anaphora-shorthand-resolution [] -> Bool
  (let [(prev "asl test voice/tests/audio_bridge_test.asl")
        (r1 (cb/resolve-anaphora-directive "run that again" prev))
        (r2 (cb/resolve-anaphora-directive "повтори" prev))
        (r3 (cb/resolve-anaphora-directive "retry" prev))
        (r4 (cb/resolve-anaphora-directive "fix it" "parser syntax error"))
        (r5 (cb/resolve-anaphora-directive "исправь это" "type inference bug"))
        (r6 (cb/resolve-anaphora-directive "apply it" "proposal 42"))
        (r7 (cb/resolve-anaphora-directive "clean project" prev))]
    (assert (= r1 prev) "run that again returns previous prompt")
    (assert (= r2 prev) "повтори returns previous prompt")
    (assert (= r3 prev) "retry returns previous prompt")
    (assert (= r4 "fix: parser syntax error") "fix it prepends fix:")
    (assert (= r5 "fix: type inference bug") "исправь это prepends fix:")
    (assert (= r6 "apply: proposal 42") "apply it prepends apply:")
    (assert (= r7 "clean project") "unmatched directive preserved as-is")
    true))

(df test-chat-streaming-and-history-bounding [] -> Bool
  (let [(st0 (cb/init-chat-bridge "chat-42"))
        (e1 (cb/make-chat-ingress "chat-42" "p1" "p1" "en" "dev" "p1" 1000))
        (e2 (cb/make-chat-ingress "chat-42" "p2" "p2" "en" "dev" "p2" 2000))
        (st1 (cb/stream-voice-to-chat st0 e1))
        (st2 (cb/stream-voice-to-chat st1 e2))]
    (assert (.-is-streaming st2) "bridge is marked streaming")
    (assert (= (list-length (.-prompt-history st2)) 2) "history holds 2 items")
    (let [(st-many (list-fold
                     (fn [(acc cb/ChatBridgeState) (idx Int64)]
                       (cb/stream-voice-to-chat acc (cb/make-chat-ingress "chat-42" "p" "p" "en" "dev" "p" (+ 3000 idx))))
                     st2
                     (list 1 2 3 4 5 6 7 8 9 10 11)))]
      (assert (= (list-length (.-prompt-history st-many)) 10) "history clamped at 10 items"))
    true))

(df test-barge-in-interruption-abort [] -> Bool
  (let [(st0 (cb/init-chat-bridge "chat-42"))
        (e1 (cb/make-chat-ingress "chat-42" "prompt" "prompt" "en" "dev" "prompt" 1000))
        (st-streaming (cb/stream-voice-to-chat st0 e1))
        (st-aborted (cb/trigger-barge-in-abort st-streaming))
        (telemetry (cb/render-chat-telemetry-asn st-aborted))]
    (refute (.-is-streaming st-aborted) "streaming is false after barge-in abort")
    (assert (= (.-barge-in-count st-aborted) 1) "barge-in count incremented to 1")
    (assert (string-contains? telemetry ":barge-ins 1") "telemetry reports 1 barge-in")
    (assert (string-contains? telemetry ":streaming false") "telemetry reports streaming false")
    true))

(df run-all-chat-tests [] -> Bool
  (do
    (test-chat-ingress-creation-and-formatting)
    (test-anaphora-shorthand-resolution)
    (test-chat-streaming-and-history-bounding)
    (test-barge-in-interruption-abort)
    true))

(run-all-chat-tests)
