(module asl-agent/ide-mesh
  :d "Cross-IDE Hub Bridge (Claude Code CLI, Antigravity IDE, Native AD-Agent) and Git Worktree Mesh Coordinator"
  :x [IdeRuntime
      WorktreeSlot
      MeshHubConfig
      IdeTaskEnvelope
      IdeExecutionReceipt
      IdeMeshCoordinator
      ide-claude-code
      ide-antigravity
      ide-native-ad
      ide-cursor-bridge
      runtime-to-str
      str-to-runtime
      make-worktree-slot
      format-git-worktree-add
      format-git-worktree-remove
      has-worktree-collision?
      make-default-hub-config
      make-ide-task
      format-claude-cli-dispatch
      format-antigravity-mcp-payload
      format-hub-envelope-asn
      make-execution-receipt
      is-receipt-falsified-and-green?
      format-receipt-aloud
      make-mesh-coordinator
      allocate-task-worktree
      release-task-worktree
      dispatch-task-to-mesh
      record-task-settlement
      render-mesh-status-asn]
  :i [(asl-text/string :a s)])

(dfe IdeRuntime
  (:c ide-claude-code [] "Claude Code CLI headless runner")
  (:c ide-antigravity [] "Google Antigravity IDE custom MCP sidecar")
  (:c ide-native-ad [] "Native AgentScript autonomous session")
  (:c ide-cursor-bridge [] "Cursor or Windsurf external tool bridge"))

(dfs WorktreeSlot
  (:f task-id Str "Unique task identifier")
  (:f branch-name Str "Git branch name: eddie/<task-id>")
  (:f worktree-path Str "Isolated worktree filesystem directory")
  (:f repo-root Str "Base git repository root")
  (:f is-active Bool "Active reservation status")
  (:f allocated-at Int64 "Timestamp of slot creation"))

(dfs MeshHubConfig
  (:f socket-path Str "Authoritative unix domain socket path")
  (:f default-timeout-sec Int64 "Execution timeout floor in seconds")
  (:f max-concurrent-workers Int64 "Maximum concurrent parallel workers"))

(dfs IdeTaskEnvelope
  (:f task-id Str "Task identifier")
  (:f runtime IdeRuntime "Target IDE execution runtime")
  (:f intent-kind Str "Intent kind tag (:dev, :intel, :fast-path, etc.)")
  (:f prompt Str "Cleaned execution directive or prompt")
  (:f worktree-path Str "Filesystem path to isolated workspace")
  (:f timeout-sec Int64 "Execution timeout ceiling")
  (:f enqueued-at Int64 "Timestamp of envelope dispatch"))

(dfs IdeExecutionReceipt
  (:f task-id Str "Settled task identifier")
  (:f runtime IdeRuntime "Executing IDE runtime")
  (:f exit-code Int64 "Process return code: 0 = verified green")
  (:f assertions-passed Int64 "Non-vacuous physical assertions passed (>0)")
  (:f files-modified Int64 "Count of modified files in worktree")
  (:f duration-ms Int64 "Wall clock execution latency in milliseconds")
  (:f digest Str "Concise execution summary digest"))

(dfs IdeMeshCoordinator
  (:f config MeshHubConfig "Authoritative hub socket and timeout config")
  (:f worktrees (List WorktreeSlot) "Active worktree allocations")
  (:f dispatched-tasks (List IdeTaskEnvelope) "In-flight tasks across IDE workers")
  (:f receipts (List IdeExecutionReceipt) "Completed execution receipts"))

(df runtime-to-str [(runtime IdeRuntime)] -> Str
  :d "Converts IdeRuntime enum to canonical string"
  (mt runtime
    ((ide-claude-code) "claude-code")
    ((ide-antigravity) "antigravity")
    ((ide-native-ad) "native-ad")
    ((ide-cursor-bridge) "cursor-bridge")))

(df str-to-runtime [(name Str)] -> IdeRuntime
  :d "Maps string to IdeRuntime enum"
  (cond
    ((= name "claude-code") (ide-claude-code))
    ((= name "antigravity") (ide-antigravity))
    ((= name "native-ad") (ide-native-ad))
    (:else (ide-cursor-bridge))))

(df make-worktree-slot [(task-id Str) (repo-root Str) (now Int64)] -> WorktreeSlot
  :d "Constructs an isolated worktree slot for an eddie task branch"
  (WorktreeSlot
    :task-id task-id
    :branch-name (str "eddie/" task-id)
    :worktree-path (str repo-root "/.worktrees/" task-id)
    :repo-root repo-root
    :is-active true
    :allocated-at now))

(df format-git-worktree-add [(slot WorktreeSlot)] -> Str
  :d "Generates git command to create an isolated worktree with target branch"
  (str "git worktree add -b " (.-branch-name slot) " " (.-worktree-path slot)))

(df format-git-worktree-remove [(slot WorktreeSlot)] -> Str
  :d "Generates git command to remove an isolated worktree directory"
  (str "git worktree remove --force " (.-worktree-path slot)))

(df has-worktree-collision? [(slots (List WorktreeSlot)) (task-id Str)] -> Bool
  :d "Detects if a worktree slot is already allocated for the given task"
  (let [(matches (list-filter (fn [(s WorktreeSlot)] (and (.-is-active s) (= (.-task-id s) task-id))) slots))]
    (> (list-length matches) 0)))

(df make-default-hub-config [] -> MeshHubConfig
  :d "Constructs the standard mesh hub configuration"
  (MeshHubConfig
    :socket-path "~/.asl/run/hub.sock"
    :default-timeout-sec 300
    :max-concurrent-workers 8))

(df make-ide-task [(task-id Str) (runtime IdeRuntime) (intent-kind Str) (prompt Str) (worktree-path Str) (now Int64)] -> IdeTaskEnvelope
  :d "Constructs an IDE task execution envelope"
  (IdeTaskEnvelope
    :task-id task-id
    :runtime runtime
    :intent-kind intent-kind
    :prompt prompt
    :worktree-path worktree-path
    :timeout-sec 300
    :enqueued-at now))

(df format-claude-cli-dispatch [(task IdeTaskEnvelope)] -> Str
  :d "Formats CLI command to run headless Claude Code inside isolated worktree"
  (str "cd " (.-worktree-path task) " && claude -p \"" (string-replace (.-prompt task) "\"" "") "\""))

(df format-antigravity-mcp-payload [(task IdeTaskEnvelope)] -> Str
  :d "Formats structured MCP request payload for Google Antigravity IDE sidecar"
  (str "(:agy-mcp-request :task-id \"" (.-task-id task) "\" :workspace \"" (.-worktree-path task) "\" :intent \"" (.-intent-kind task) "\" :prompt \"" (string-replace (.-prompt task) "\"" "") "\")"))

(df format-hub-envelope-asn [(task IdeTaskEnvelope)] -> Str
  :d "Formats canonical mesh dispatch packet for domain socket transport"
  (str "(:mesh-envelope :task-id \"" (.-task-id task) "\" :runtime \"" (runtime-to-str (.-runtime task)) "\" :worktree \"" (.-worktree-path task) "\" :timeout " (string-from-int64 (.-timeout-sec task)) ")"))

(df make-execution-receipt [(task-id Str) (runtime IdeRuntime) (exit-code Int64) (asserts Int64) (files Int64) (duration Int64) (digest Str)] -> IdeExecutionReceipt
  :d "Constructs an IdeExecutionReceipt"
  (IdeExecutionReceipt
    :task-id task-id
    :runtime runtime
    :exit-code exit-code
    :assertions-passed asserts
    :files-modified files
    :duration-ms duration
    :digest digest))

(df is-receipt-falsified-and-green? [(r IdeExecutionReceipt)] -> Bool
  :d "Enforces Ground Truth: process must exit 0 and have executed at least 1 non-vacuous assertion"
  (and (= (.-exit-code r) 0) (> (.-assertions-passed r) 0)))

(df format-receipt-aloud [(r IdeExecutionReceipt)] -> Str
  :d "Formats an ear-friendly audio digest for Jarvis voice TTS (<112 chars)"
  (let [(rt-name (runtime-to-str (.-runtime r)))
        (tid (.-task-id r))]
    (if (is-receipt-falsified-and-green? r)
      (str "Task " tid " verified on " rt-name ". " (string-from-int64 (.-assertions-passed r)) " assertions green across " (string-from-int64 (.-files-modified r)) " files.")
      (str "Task " tid " failed on " rt-name " with exit code " (string-from-int64 (.-exit-code r)) "."))))

(df make-mesh-coordinator [(config MeshHubConfig)] -> IdeMeshCoordinator
  :d "Constructs an initialized IdeMeshCoordinator"
  (IdeMeshCoordinator
    :config config
    :worktrees (list)
    :dispatched-tasks (list)
    :receipts (list)))

(df allocate-task-worktree [(mesh IdeMeshCoordinator) (task-id Str) (repo-root Str) (now Int64)] -> IdeMeshCoordinator
  :d "Allocates and reserves an isolated git worktree for a task"
  (if (has-worktree-collision? (.-worktrees mesh) task-id)
    mesh
    (let [(slot (make-worktree-slot task-id repo-root now))
          (updated (list-append (.-worktrees mesh) (list slot)))]
      (IdeMeshCoordinator
        :config (.-config mesh)
        :worktrees updated
        :dispatched-tasks (.-dispatched-tasks mesh)
        :receipts (.-receipts mesh)))))

(df release-task-worktree [(mesh IdeMeshCoordinator) (task-id Str)] -> IdeMeshCoordinator
  :d "Releases and deactivates a worktree allocation upon task settlement"
  (let [(filtered (list-filter (fn [(s WorktreeSlot)] (not (= (.-task-id s) task-id))) (.-worktrees mesh)))]
    (IdeMeshCoordinator
      :config (.-config mesh)
      :worktrees filtered
      :dispatched-tasks (.-dispatched-tasks mesh)
      :receipts (.-receipts mesh))))

(df dispatch-task-to-mesh [(mesh IdeMeshCoordinator) (envelope IdeTaskEnvelope)] -> IdeMeshCoordinator
  :d "Enqueues an IDE task into the active dispatch queue"
  (let [(updated (list-append (.-dispatched-tasks mesh) (list envelope)))]
    (IdeMeshCoordinator
      :config (.-config mesh)
      :worktrees (.-worktrees mesh)
      :dispatched-tasks updated
      :receipts (.-receipts mesh))))

(df record-task-settlement [(mesh IdeMeshCoordinator) (receipt IdeExecutionReceipt)] -> IdeMeshCoordinator
  :d "Records completed receipt, removes task from dispatched queue, and frees worktree"
  (let [(tid (.-task-id receipt))
        (active-tasks (list-filter (fn [(e IdeTaskEnvelope)] (not (= (.-task-id e) tid))) (.-dispatched-tasks mesh)))
        (active-worktrees (list-filter (fn [(s WorktreeSlot)] (not (= (.-task-id s) tid))) (.-worktrees mesh)))
        (updated-receipts (list-append (.-receipts mesh) (list receipt)))]
    (IdeMeshCoordinator
      :config (.-config mesh)
      :worktrees active-worktrees
      :dispatched-tasks active-tasks
      :receipts updated-receipts)))

(df render-mesh-status-asn [(mesh IdeMeshCoordinator)] -> Str
  :d "Renders high-density ASN telemetry summary of the IDE mesh state"
  (let [(w-count (list-length (.-worktrees mesh)))
        (t-count (list-length (.-dispatched-tasks mesh)))
        (r-count (list-length (.-receipts mesh)))]
    (str "(:ide-mesh :socket \"" (.-socket-path (.-config mesh)) "\" :worktrees " (string-from-int64 w-count) " :in-flight " (string-from-int64 t-count) " :settled " (string-from-int64 r-count) ")")))
