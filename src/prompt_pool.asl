(module asl-agent/prompt-pool
  :d "Prompt Context Pool: retains recent raw prompts per chat session with TTL eviction to resolve follow-ups and anaphora."
  :x [PromptEntry PromptPool
      make-prompt-entry
      make-prompt-pool
      record-prompt
      get-active-prompts
      render-prompt-pool-asn]
  :i [(asl-text/string :a s)])

(dfs PromptEntry
  (:f text Str "Raw prompt text")
  (:f timestamp-ms Int64 "Arrival epoch timestamp in ms"))

(dfs PromptPool
  (:f chat-id Str "Unique chat or lane identifier")
  (:f entries (List PromptEntry) "List of recent prompt entries, newest last")
  (:f capacity Int64 "Maximum number of prompts retained (default 3)")
  (:f ttl-ms Int64 "Time-to-live expiration window in ms (default 180,000)"))

(df make-prompt-entry [(text Str) (timestamp-ms Int64)] -> PromptEntry
  :d "Constructs a PromptEntry record"
  (PromptEntry
    :text text
    :timestamp-ms timestamp-ms))

(df make-prompt-pool [(chat-id Str) (capacity Int64) (ttl-ms Int64)] -> PromptPool
  :d "Constructs an empty PromptPool record for a chat session"
  (PromptPool
    :chat-id chat-id
    :entries (list)
    :capacity (if (> capacity 0) capacity 3)
    :ttl-ms (if (> ttl-ms 0) ttl-ms 180000)))

(df record-prompt [(pool PromptPool) (text Str) (now-ms Int64)] -> PromptPool
  :d "Appends a new prompt to the pool and evicts entries exceeding TTL or capacity"
  (let [(cutoff (- now-ms (.-ttl-ms pool)))
        (alive (list-filter (fn [(e PromptEntry)] (> (.-timestamp-ms e) cutoff)) (.-entries pool)))
        (new-entry (make-prompt-entry (string-trim text) now-ms))
        (appended (list-append alive (list new-entry)))
        (len (list-length appended))
        (cap (.-capacity pool))
        (trimmed (if (> len cap)
                   (list-drop appended (- len cap))
                   appended))]
    (PromptPool
      :chat-id (.-chat-id pool)
      :entries trimmed
      :capacity (.-capacity pool)
      :ttl-ms (.-ttl-ms pool))))

(df get-active-prompts [(pool PromptPool) (now-ms Int64)] -> (List PromptEntry)
  :d "Returns all non-expired prompt entries from the pool"
  (let [(cutoff (- now-ms (.-ttl-ms pool)))]
    (list-filter (fn [(e PromptEntry)] (> (.-timestamp-ms e) cutoff)) (.-entries pool))))

(df render-prompt-pool-asn [(pool PromptPool) (now-ms Int64)] -> Str
  :d "Renders active pool entries as a compact S-expression context block"
  (let [(active (get-active-prompts pool now-ms))]
    (if (list-empty? active)
      ""
      (let [(count (list-length active))]
        (str "(:recent-context :chat-id \"" (.-chat-id pool) "\" :count " (string-from-int64 count) ")")))))
