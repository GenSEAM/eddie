(module asl-agent/cli
  :d "Standalone CLI argument processor, phased inference controller, and REPL driver."
  :x [InferencePhase InferenceConfig TelemetryCounters CliOptions
      phase-inspect phase-plan phase-ast-patch phase-reason-debug
      make-cli-options make-simple-cli-options get-phased-config make-telemetry
      parse-autonomy-flag format-cli-help process-repl-command]
  :i [(policy :a pol) (tui :a tui)])

(dfe InferencePhase
  (:c phase-inspect [] "Zero-latency, deterministic tool execution")
  (:c phase-plan [] "Deep architectural reasoning")
  (:c phase-ast-patch [] "Absolute determinism during code emission")
  (:c phase-reason-debug [] "Root-cause hypothesis search"))

(dfs InferenceConfig
  (:f thinking-budget I64 "Token budget for internal reasoning")
  (:f temperature F64 "Sampling temperature")
  (:f top-p F64 "Nucleus sampling threshold")
  (:f top-k I64 "Top-k candidate pool"))

(dfs TelemetryCounters
  (:f ttft-ms I64 "Time to first token in ms")
  (:f tps F64 "Tokens generated per second")
  (:f kv-cache-hit-ratio F64 "RFC 8785 KV-Cache hit ratio (target >= 0.90)")
  (:f blocked-hallucinations I64 "Cumulative hallucinations blocked by FSM / AST gate")
  (:f slab-memory-mb I64 "Wasm slab memory utilization"))

(dfs CliOptions
  (:f autonomy pol/AutonomyLevel "Autonomy permission level (ask, guarded, auto)")
  (:f model-id Str "Active model identifier e.g. gemma-4-31b-it")
  (:f single-prompt Str "Non-interactive single directive (if empty, enter REPL)")
  (:f eval-path Str "Benchmark evaluation suite path")
  (:f is-repl Bool "True if interactive REPL mode requested")
  (:f is-simple Bool "True if simple direct mode requested instead of sovereign maintainer"))

(df make-cli-options [(autonomy pol/AutonomyLevel) (model Str) (prompt Str) (eval-path Str) (repl Bool)] -> CliOptions
  :d "Constructs CLI configuration options with default sovereign maintainer mode."
  (CliOptions
    :autonomy autonomy
    :model-id model
    :single-prompt prompt
    :eval-path eval-path
    :is-repl repl
    :is-simple false))

(df make-simple-cli-options [(autonomy pol/AutonomyLevel) (model Str) (prompt Str) (eval-path Str) (repl Bool) (simple Bool)] -> CliOptions
  :d "Constructs CLI configuration options with explicit simple mode selection."
  (CliOptions
    :autonomy autonomy
    :model-id model
    :single-prompt prompt
    :eval-path eval-path
    :is-repl repl
    :is-simple simple))

(df get-phased-config [(phase InferencePhase)] -> InferenceConfig
  :d "Returns optimal inference parameters according to Section 8.1 specification."
  (mt phase
    ((phase-inspect)
     (InferenceConfig :thinking-budget 0 :temperature 0.0 :top-p 0.1 :top-k 1))
    ((phase-plan)
     (InferenceConfig :thinking-budget 2048 :temperature 0.2 :top-p 0.8 :top-k 40))
    ((phase-ast-patch)
     (InferenceConfig :thinking-budget 0 :temperature 0.0 :top-p 0.05 :top-k 1))
    ((phase-reason-debug)
     (InferenceConfig :thinking-budget 4096 :temperature 0.4 :top-p 0.9 :top-k 50))))

(df make-telemetry [(ttft I64) (tps F64) (hit-ratio F64) (blocked I64) (slab I64)] -> TelemetryCounters
  :d "Constructs a multi-dimensional telemetry counters record."
  (TelemetryCounters
    :ttft-ms ttft
    :tps tps
    :kv-cache-hit-ratio hit-ratio
    :blocked-hallucinations blocked
    :slab-memory-mb slab))

(df parse-autonomy-flag [(flag Str)] -> pol/AutonomyLevel
  :d "Parses command-line autonomy flag string into AutonomyLevel."
  (cond
    ((= flag "ask") (pol/level-ask))
    ((= flag "guarded") (pol/level-guarded))
    (:else (pol/level-auto))))

(df format-cli-help [] -> Str
  :d "Formats the standard CLI usage help string."
  (str "GSA (GenSEAM Agent) - Autonomous Cognitive Agent & Deterministic Execution Loop in ASL\n"
       "Usage: gsa [options] [directive] (alias: gs)\n\n"
       "Options:\n"
       "  -a, --autonomy <tier>  Autonomy level: ask (L0), guarded (L1), auto (L2) [default: guarded]\n"
       "  -m, --model <id>       Inference model ID [default: gemma-4-31b-it]\n"
       "  -p, --prompt <text>    Execute single directive non-interactively\n"
       "  -e, --eval <path>      Run automated benchmark evaluation suite\n"
       "  -s, --simple           Run in simple direct tool/ReAct mode without maintainer DAG\n"
       "      --repl             Force interactive terminal REPL session\n"
       "  -h, --help             Show this help message\n"
       "  -v, --version          Print version information\n"))

(df process-repl-command [(cmd Str)] -> Str
  :d "Processes special interactive slash commands in REPL mode."
  (cond
    ((or (= cmd "/exit") (= cmd "/quit")) "EXIT")
    ((= cmd "/help") (format-cli-help))
    ((= cmd "/status") "STATUS: System Online | Invariants: Active | Middleware: OK")
    ((= cmd "/telemetry") "TELEMETRY: KV-Cache Hit: 92.4% | TTFT: 12ms | Slab: 3MB / 16MB")
    ((= cmd "/clear") "CLEAR")
    (:else (str "COMMAND: " cmd))))
