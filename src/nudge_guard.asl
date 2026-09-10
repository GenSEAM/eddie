(module asl-agent/nudge-guard
  :d "Proactive Nudge Engine and UI Focus Guard: non-disruptive attention management, failure streak warnings, and idle-release buffers."
  :x [NudgeEvent NudgeGuardState
      make-initial-nudge-guard
      record-task-outcome
      evaluate-proactive-nudge
      hold-disruptive-intent
      release-held-intents-on-idle]
  :i [(core/strings :a s)])

(dfs NudgeEvent
  (:f task-id Str "Associated task identifier")
  (:f reason Str "Trigger classification: failure-run, stale-plan, idle-decision")
  (:f text Str "Formatted concise notification text")
  (:f timestamp-ms Int64 "Emission epoch timestamp"))

(dfs NudgeGuardState
  (:f last-nudge-time-ms Int64 "Timestamp of most recent proactive notice")
  (:f consecutive-failures Int64 "Count of consecutive failures in current project")
  (:f active-project Str "Project where failures are occurring")
  (:f held-intent-ids (List Str) "Queue of disruptive UI intents held during active input"))

(df make-initial-nudge-guard [] -> NudgeGuardState
  :d "Constructs an empty initial NudgeGuardState"
  (NudgeGuardState
    :last-nudge-time-ms 0
    :consecutive-failures 0
    :active-project ""
    :held-intent-ids (list)))

(df record-task-outcome [(state NudgeGuardState) (project Str) (is-success Bool)] -> NudgeGuardState
  :d "Updates consecutive failure streaks across projects"
  (if is-success
    (NudgeGuardState
      :last-nudge-time-ms (.-last-nudge-time-ms state)
      :consecutive-failures 0
      :active-project project
      :held-intent-ids (.-held-intent-ids state))
    (let [(prev-proj (.-active-project state))
          (cur-streak (if (= prev-proj project) (.-consecutive-failures state) 0))]
      (NudgeGuardState
        :last-nudge-time-ms (.-last-nudge-time-ms state)
        :consecutive-failures (+ cur-streak 1)
        :active-project project
        :held-intent-ids (.-held-intent-ids state)))))

(df evaluate-proactive-nudge [(state NudgeGuardState) (now-ms Int64)] -> (Option NudgeEvent)
  :d "Evaluates whether a proactive warning should be emitted without violating minimum interval bounds"
  (let [(streak (.-consecutive-failures state))
        (last-time (.-last-nudge-time-ms state))
        (elapsed (- now-ms last-time))]
    (if (and (>= streak 3) (>= elapsed 60000))
      (some (NudgeEvent
              :task-id (.-active-project state)
              :reason "failure-run"
              :text (str "Project " (.-active-project state) " has failed 3 times consecutively")
              :timestamp-ms now-ms))
      none)))

(df hold-disruptive-intent [(state NudgeGuardState) (intent-id Str)] -> NudgeGuardState
  :d "Buffers a disruptive UI intent to prevent yanking cursor while operator is active"
  (let [(current (.-held-intent-ids state))
        (updated (list-append current (list intent-id)))]
    (NudgeGuardState
      :last-nudge-time-ms (.-last-nudge-time-ms state)
      :consecutive-failures (.-consecutive-failures state)
      :active-project (.-active-project state)
      :held-intent-ids updated)))

(df release-held-intents-on-idle [(state NudgeGuardState)] -> (Pair NudgeGuardState (List Str))
  :d "Flushes held intents once operator input goes idle"
  (let [(drained (.-held-intent-ids state))
        (cleared (NudgeGuardState
                   :last-nudge-time-ms (.-last-nudge-time-ms state)
                   :consecutive-failures (.-consecutive-failures state)
                   :active-project (.-active-project state)
                   :held-intent-ids (list)))]
    (pair cleared drained)))
