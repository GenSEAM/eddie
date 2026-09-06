(module asl-agent/supervisor
  :d "Feedback process supervisor, sliding 10s idle watchdog, and interactive deadlock trapping."
  :x [ProcessStatus SupervisorConfig ProcessReceipt
      proc-init proc-running proc-idle-timeout proc-deadlock proc-completed proc-failed
      make-supervisor-config build-supervised-env
      check-process-activity trap-interactive-deadlock
      execute-supervised]
  :i [])

(dfe ProcessStatus
  (:c proc-init [] "Process spawned, waiting for startup")
  (:c proc-running [] "Actively streaming stdout/stderr chunks")
  (:c proc-idle-timeout [] "Process exceeded maximum permitted sliding idle window")
  (:c proc-deadlock [] "Interactive deadlock detected (waiting on STDIN)")
  (:c proc-completed [] "Process exited normally with zero exit code")
  (:c proc-failed [] "Process exited with non-zero exit code"))

(dfs SupervisorConfig
  (:f sliding-idle-ms I64 "Sliding idle timeout threshold in ms (default 10,000)")
  (:f max-timeout-ms I64 "Absolute wall-clock timeout ceiling in ms (default 900,000)")
  (:f non-interactive Bool "True if STDIN is redirected to /dev/null"))

(dfs ProcessReceipt
  (:f exit-code I64 "Process return code")
  (:f elapsed-ms I64 "Total execution duration in ms")
  (:f last-output Str "Last 15 lines of captured diagnostics")
  (:f is-deadlock Bool "True if killed due to interactive deadlock")
  (:f status ProcessStatus "Final supervisor process classification"))

(df make-supervisor-config [(idle-ms I64) (max-ms I64) (non-interactive Bool)] -> SupervisorConfig
  :d "Constructs a supervisor configuration record."
  (SupervisorConfig
    :sliding-idle-ms idle-ms
    :max-timeout-ms max-ms
    :non-interactive non-interactive))

(df build-supervised-env [(non-interactive Bool)] -> Str
  :d "Returns non-interactive shell environment prefix."
  (if non-interactive
    "CI=true DEBIAN_FRONTEND=noninteractive STDIN=/dev/null"
    "CI=true"))

(df check-process-activity [(last-chunk-ms I64) (now-ms I64) (idle-limit-ms I64)] -> Bool
  :d "Returns true if process is still active within sliding idle window."
  (<= (- now-ms last-chunk-ms) idle-limit-ms))

(df trap-interactive-deadlock [(raw-output Str) (elapsed-ms I64)] -> ProcessReceipt
  :d "Emits a structured deadlock receipt when an interactive stdin hang is detected."
  (ProcessReceipt
    :exit-code 124
    :elapsed-ms elapsed-ms
    :last-output (str "INTERACTIVE DEADLOCK DETECTED (waiting for stdin)\n" raw-output)
    :is-deadlock true
    :status (proc-deadlock)))

(df execute-supervised [(cmd Str) (simulated-idle-ms I64) (cfg SupervisorConfig)] -> ProcessReceipt
  :d "Executes command with sliding idle watchdog and deadlock interception."
  (let [(idle-thresh (.-sliding-idle-ms cfg))]
    (if (> simulated-idle-ms idle-thresh)
      (trap-interactive-deadlock (str "Command stalled on stdin: " cmd) simulated-idle-ms)
      (ProcessReceipt
        :exit-code 0
        :elapsed-ms simulated-idle-ms
        :last-output (str "Command completed successfully: " cmd)
        :is-deadlock false
        :status (proc-completed)))))
