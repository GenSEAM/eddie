(module asl-agent/agent
  :d "Native ReAct agent loop, tool dispatch, autonomy levels, and capability sandboxing."
  :x [AgentState AgentSession StepResult
      make-agent-session make-autonomy-session step-agent run-bounded-session]
  :i [(policy :a pol) (ffi :a ffi) (tui :a tui)])

(dfs AgentState
  (:f phase Str "State phase: idle, reasoning, tool_eval, tool_exec, complete, error")
  (:f current-step I64 "Current iteration step counter")
  (:f max-steps I64 "Maximum permitted iteration ceiling (default 10)")
  (:f goal Str "Initial user objective")
  (:f last-output Str "Last observation or tool output")
  (:f is-terminal Bool "True if session has settled"))

(dfs AgentSession
  (:f state AgentState "Current execution state")
  (:f manifest pol/PermissionManifest "Sandbox capability boundaries")
  (:f autonomy pol/AutonomyLevel "Current autonomy permission tier")
  (:f history (List Str) "Trace log of ReAct thought-action-observation cycles"))

(dfs StepResult
  (:f session AgentSession "Updated session record")
  (:f action-taken Str "Description of action or completion")
  (:f success Bool "True if step completed without violation"))

(df make-agent-session [(goal Str) (manifest pol/PermissionManifest)] -> AgentSession
  :d "Initializes an AgentSession with standard 10-step ceiling and default L2:FullAuto."
  (make-autonomy-session goal manifest (pol/level-auto)))

(df make-autonomy-session [(goal Str) (manifest pol/PermissionManifest) (autonomy pol/AutonomyLevel)] -> AgentSession
  :d "Initializes an AgentSession with specified autonomy tier."
  (AgentSession
    :state (AgentState
             :phase "idle"
             :current-step 0
             :max-steps 10
             :goal goal
             :last-output ""
             :is-terminal false)
    :manifest manifest
    :autonomy autonomy
    :history (list)))

(df step-agent [(session AgentSession) (tool-name Str) (target-path Str) (payload Str)] -> StepResult
  :d "Executes one ReAct step under capability sandboxing and autonomy rules."
  (let [(st (.-state session))
        (cur-step (.-current-step st))
        (max-step (.-max-steps st))
        (manifest (.-manifest session))
        (autonomy (.-autonomy session))]
    (cond
      ((.-is-terminal st)
       (StepResult
         :session session
         :action-taken "session already terminal"
         :success true))
      ((>= cur-step max-step)
       (let [(updated-st (AgentState
                           :phase "error"
                           :current-step cur-step
                           :max-steps max-step
                           :goal (.-goal st)
                           :last-output "Step budget exhausted (anti-OOM limit reached)"
                           :is-terminal true))]
         (StepResult
           :session (AgentSession
                      :state updated-st
                      :manifest manifest
                      :autonomy autonomy
                      :history (list-cons "step-budget-exceeded" (.-history session)))
           :action-taken "aborted: step budget ceiling"
           :success false)))
      ((= tool-name "finish")
       (let [(updated-st (AgentState
                           :phase "complete"
                           :current-step (+ cur-step 1)
                           :max-steps max-step
                           :goal (.-goal st)
                           :last-output payload
                           :is-terminal true))]
         (StepResult
           :session (AgentSession
                      :state updated-st
                      :manifest manifest
                      :autonomy autonomy
                      :history (list-cons (str "final-answer: " payload) (.-history session)))
           :action-taken "finish"
           :success true)))
      (:else
       (let [(perm (pol/check-autonomy-permission tool-name target-path manifest autonomy))]
         (if (not (.-allowed perm))
           (let [(err-msg (str "Policy violation: " (.-reason perm)))
                 (updated-st (AgentState
                               :phase "error"
                               :current-step (+ cur-step 1)
                               :max-steps max-step
                               :goal (.-goal st)
                               :last-output err-msg
                               :is-terminal true))]
             (StepResult
               :session (AgentSession
                          :state updated-st
                          :manifest manifest
                          :autonomy autonomy
                          :history (list-cons err-msg (.-history session)))
               :action-taken (str "denied: " (.-code perm))
               :success false))
           (if (not (.-silent perm))
             (let [(prompt-msg (str "Confirmation required: " (.-reason perm)))
                   (updated-st (AgentState
                                 :phase "reasoning"
                                 :current-step (+ cur-step 1)
                                 :max-steps max-step
                                 :goal (.-goal st)
                                 :last-output prompt-msg
                                 :is-terminal false))]
               (StepResult
                 :session (AgentSession
                            :state updated-st
                            :manifest manifest
                            :autonomy autonomy
                            :history (list-cons prompt-msg (.-history session)))
                 :action-taken (str "prompt:" tool-name)
                 :success true))
             (let [(cap (if (or (= tool-name "read") (or (= tool-name "write") (= tool-name "patch"))) "fs" "exec"))
                   (act (if (= tool-name "read") "read" (if (= tool-name "write") "write" "exec")))
                   (ffi-res (ffi/host-call cap act target-path))
                   (folding-log (tui/format-tool-call tool-name target-path "ok"))
                   (updated-st (AgentState
                                 :phase "reasoning"
                                 :current-step (+ cur-step 1)
                                 :max-steps max-step
                                 :goal (.-goal st)
                                 :last-output (mt ffi-res
                                                ((ok val) val)
                                                ((err e) e))
                                 :is-terminal false))]
               (StepResult
                 :session (AgentSession
                            :state updated-st
                            :manifest manifest
                            :autonomy autonomy
                            :history (list-cons folding-log (.-history session)))
                 :action-taken (str "executed:" tool-name)
                 :success true)))))))))

(df run-bounded-session [(session AgentSession)] -> AgentSession
  :d "Advances session to terminal state if idle."
  (if (.-is-terminal (.-state session))
    session
    (let [(res (step-agent session "finish" "" "goal completed"))]
      (.-session res))))

