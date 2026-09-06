(module asl-eddie/policy
  :d "Capability-based sandboxing, autonomy levels, and zero-spam permission policy."
  :x [AutonomyLevel ActionCategory PermissionManifest PermissionResult
      level-ask level-guarded level-auto
      cat-read cat-test cat-write cat-exec
      make-manifest allow-silent allow-prompt deny-strict deny-unauthorized
      has-traversal? is-system-path? is-in-worktrees?
      action-to-category autonomy-level-to-string
      check-permission check-autonomy-permission]
  :i [])

(dfe AutonomyLevel
  (:c level-ask [] "L0: Prompt for every file edit and shell command")
  (:c level-guarded [] "L1: Auto-allow read/search/test; prompt for write/exec")
  (:c level-auto [] "L2: Fully autonomous execution within workspace sandbox"))

(dfe ActionCategory
  (:c cat-read [] "Read-only file inspection, grep, search")
  (:c cat-test [] "Sandboxed verification and test runner")
  (:c cat-write [] "File modification, deletion, or creation")
  (:c cat-exec [] "Shell command execution"))

(dfs PermissionManifest
  (:f workspace-root Str "Canonical workspace root directory")
  (:f worktree-roots (List Str) "List of authorized git worktree root directories")
  (:f temp-dir Str "Authorized sandbox temporary directory")
  (:f read-only Bool "True if entire sandbox is read-only"))

(dfs PermissionResult
  (:f allowed Bool "True if access is granted")
  (:f silent Bool "True if granted without user prompt")
  (:f reason Str "Diagnostic reason or error message")
  (:f code Str "Status code: ALLOW_SILENT, ALLOW_PROMPT, DENY_TRAVERSAL, DENY_ROOT, DENY_READONLY, DENY_UNAUTHORIZED"))

(df make-manifest [(workspace-root Str) (worktree-roots (List Str)) (temp-dir Str) (read-only Bool)] -> PermissionManifest
  :d "Constructs an authorized capability permission manifest."
  (PermissionManifest
    :workspace-root workspace-root
    :worktree-roots worktree-roots
    :temp-dir temp-dir
    :read-only read-only))

(df allow-silent [(reason Str)] -> PermissionResult
  :d "Constructs an allow-silent permission result without user prompt."
  (PermissionResult
    :allowed true
    :silent true
    :reason reason
    :code "ALLOW_SILENT"))

(df allow-prompt [(reason Str)] -> PermissionResult
  :d "Constructs an allow-prompt permission result requiring user confirmation."
  (PermissionResult
    :allowed true
    :silent false
    :reason reason
    :code "ALLOW_PROMPT"))

(df deny-strict [(reason Str)] -> PermissionResult
  :d "Constructs a strict denial permission result for traversal or escape attacks."
  (PermissionResult
    :allowed false
    :silent false
    :reason reason
    :code "DENY_STRICT"))

(df deny-unauthorized [(reason Str)] -> PermissionResult
  :d "Constructs an unauthorized denial permission result."
  (PermissionResult
    :allowed false
    :silent false
    :reason reason
    :code "DENY_UNAUTHORIZED"))

(df action-to-category [(action Str)] -> ActionCategory
  :d "Categorizes action string into canonical ActionCategory enum."
  (cond
    ((= action "read") (cat-read))
    ((= action "view") (cat-read))
    ((= action "grep") (cat-read))
    ((= action "search") (cat-read))
    ((= action "test") (cat-test))
    ((= action "audit") (cat-test))
    ((= action "write") (cat-write))
    ((= action "patch") (cat-write))
    ((= action "delete") (cat-write))
    ((= action "exec") (cat-exec))
    ((= action "shell") (cat-exec))
    (:else (cat-write))))

(df autonomy-level-to-string [(lvl AutonomyLevel)] -> Str
  :d "Converts AutonomyLevel to display string."
  (mt lvl
    ((level-ask) "L0:Ask")
    ((level-guarded) "L1:Guarded")
    ((level-auto) "L2:FullAuto")))

(df has-traversal? [(p Str)] -> Bool
  :d "Detects directory traversal sequences in path."
  (cond
    ((string-contains? p "../") true)
    ((string-contains? p "/..") true)
    ((= p "..") true)
    ((string-starts-with? p "..") true)
    (:else false)))

(df is-system-path? [(p Str)] -> Bool
  :d "Detects access to sensitive system paths."
  (cond
    ((string-starts-with? p "/etc") true)
    ((string-starts-with? p "/root") true)
    ((string-starts-with? p "/sys") true)
    ((string-starts-with? p "/proc") true)
    ((string-starts-with? p "/dev") true)
    ((string-starts-with? p "~/.ssh") true)
    ((string-contains? p ".ssh") true)
    (:else false)))

(df is-in-worktrees? [(p Str) (worktrees (List Str))] -> Bool
  :d "Checks whether target path resides within any authorized worktree root."
  (mt (list-head worktrees)
    ((none) false)
    ((some root)
     (if (string-starts-with? p root)
       true
       (is-in-worktrees? p (option-or (list-tail worktrees) (list)))))))

(df check-autonomy-permission [(action Str) (target-path Str) (manifest PermissionManifest) (level AutonomyLevel)] -> PermissionResult
  :d "Evaluates action and path against manifest capabilities and autonomy level."
  (if (has-traversal? target-path)
    (deny-strict "sandbox escape: directory traversal rejected")
    (if (is-system-path? target-path)
      (deny-strict "sandbox escape: sensitive system path rejected")
      (if (and (.-read-only manifest) (or (= action "write") (= action "patch")))
        (deny-strict "permission denied: manifest is read-only")
        (let [(in-ws (string-starts-with? target-path (.-workspace-root manifest)))
              (in-tmp (string-starts-with? target-path (.-temp-dir manifest)))
              (in-wt (is-in-worktrees? target-path (.-worktree-roots manifest)))
              (is-authorized (or in-ws (or in-tmp in-wt)))]
          (if (not is-authorized)
            (deny-unauthorized "path outside authorized manifest boundaries")
            (let [(cat (action-to-category action))]
              (mt level
                ((level-ask)
                 (mt cat
                   ((cat-read) (allow-silent "path authorized (read-only)"))
                   ((cat-test) (allow-silent "test verification authorized"))
                   ((cat-write) (allow-prompt "confirmation required in L0:Ask mode for file write"))
                   ((cat-exec) (allow-prompt "confirmation required in L0:Ask mode for command execution"))))
                ((level-guarded)
                 (mt cat
                   ((cat-read) (allow-silent "path authorized (auto-read)"))
                   ((cat-test) (allow-silent "test verification authorized (auto-test)"))
                   ((cat-write) (allow-prompt "confirmation required in L1:Guarded mode for mutation"))
                   ((cat-exec) (allow-prompt "confirmation required in L1:Guarded mode for execution"))))
                ((level-auto)
                 (allow-silent "path authorized for autonomous execution (L2:FullAuto)"))))))))))

(df check-permission [(action Str) (target-path Str) (manifest PermissionManifest)] -> PermissionResult
  :d "Evaluates action and path with default L2:FullAuto capability."
  (check-autonomy-permission action target-path manifest (level-auto)))

