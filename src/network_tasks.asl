(module asl-agent/network-tasks
  :d "Network Task Delegator: Spoken web search delegation, documentation scraping, and mesh broadcast"
  :x [NetworkTaskKind
      NetworkTaskRequest
      NetworkTaskOutcome
      task-web-search
      task-doc-crawl
      task-api-query
      task-mesh-broadcast
      make-network-task
      execute-network-task
      format-network-outcome-asn]
  :i [(asl-text/string :a s)])

(dfe NetworkTaskKind
  (:c task-web-search [] "Real-time web search query")
  (:c task-doc-crawl [] "Documentation page crawling and extraction")
  (:c task-api-query [] "External REST or GraphQL endpoint query")
  (:c task-mesh-broadcast [] "Broadcast task envelope to peer agent bus"))

(dfs NetworkTaskRequest
  (:f task-id Str "Unique network task identifier")
  (:f kind NetworkTaskKind "Categorical network operation")
  (:f query Str "Search terms, document URL, or API payload")
  (:f target-url Str "Target hostname or endpoint URI")
  (:f timeout-sec Int64 "Network socket timeout ceiling in seconds"))

(dfs NetworkTaskOutcome
  (:f task-id Str "Executed task identifier")
  (:f status Str "Execution state: resolved, timeout, network-error")
  (:f facts-count Int64 "Count of discrete facts extracted")
  (:f facts (List Str) "List of resolved facts or snippets")
  (:f duration-ms Int64 "Network roundtrip latency in milliseconds"))

(df make-network-task [(id Str) (kind NetworkTaskKind) (query Str) (target Str) (timeout Int64)] -> NetworkTaskRequest
  :d "Constructs NetworkTaskRequest record"
  (NetworkTaskRequest
    :task-id id
    :kind kind
    :query query
    :target-url target
    :timeout-sec timeout))

(df execute-network-task [(req NetworkTaskRequest)] -> NetworkTaskOutcome
  :d "Simulates deterministic resolution of network task"
  (let [(tid (.-task-id req))]
    (mt (.-kind req)
      ((task-web-search)
       (NetworkTaskOutcome
         :task-id tid
         :status "resolved"
         :facts-count 2
         :facts (list (str "Search result for " (.-query req)) "API specification documented at target")
         :duration-ms 120))
      ((task-doc-crawl)
       (NetworkTaskOutcome
         :task-id tid
         :status "resolved"
         :facts-count 1
         :facts (list (str "Scraped documentation from " (.-target-url req)))
         :duration-ms 240))
      ((task-api-query)
       (NetworkTaskOutcome
         :task-id tid
         :status "resolved"
         :facts-count 1
         :facts (list "HTTP 200 OK")
         :duration-ms 85))
      ((task-mesh-broadcast)
       (NetworkTaskOutcome
         :task-id tid
         :status "resolved"
         :facts-count 1
         :facts (list "Broadcast acknowledged by 3 mesh peers")
         :duration-ms 45)))))

(df format-network-outcome-asn [(outcome NetworkTaskOutcome)] -> Str
  :d "Renders high-density ASN summary of network task outcome"
  (str "(:network-outcome :id \"" (.-task-id outcome) "\" :status \"" (.-status outcome) "\" :facts " (string-from-int64 (.-facts-count outcome)) " :latency-ms " (string-from-int64 (.-duration-ms outcome)) ")"))
