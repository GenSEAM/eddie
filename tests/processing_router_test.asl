(module asl-agent/test-processing-router
  :d "Unit verification test suite for Network Task Delegation and 4-Tier Latency Optimization Hierarchy"
  :x [test-network-task-execution-and-outcomes
      test-processing-tier-routing-hierarchy
      run-all-router-tests]
  :i [(network_tasks :a nt)
      (processing_router :a pr)])

(df test-network-task-execution-and-outcomes [] -> Bool
  (let [(req-search (nt/make-network-task "t1" (nt/task-web-search) "AgentScript" "https://google.com" 10))
        (req-crawl (nt/make-network-task "t2" (nt/task-doc-crawl) "specs" "https://docs.asl.dev" 15))
        (req-api (nt/make-network-task "t3" (nt/task-api-query) "healthcheck" "http://127.0.0.1:8080/health" 5))
        (req-mesh (nt/make-network-task "t4" (nt/task-mesh-broadcast) "ping" "mesh://swarm" 5))
        (res-search (nt/execute-network-task req-search))
        (res-crawl (nt/execute-network-task req-crawl))
        (res-api (nt/execute-network-task req-api))
        (res-mesh (nt/execute-network-task req-mesh))
        (asn-repr (nt/format-network-outcome-asn res-search))]
    (assert (= (.-status res-search) "resolved") "search task resolved")
    (assert (= (.-facts-count res-search) 2) "search yielded 2 facts")
    (assert (<= (.-duration-ms res-search) 150) "search latency within SLA")
    (assert (= (.-status res-crawl) "resolved") "crawl task resolved")
    (assert (= (.-facts-count res-crawl) 1) "crawl yielded 1 fact")
    (assert (= (.-status res-api) "resolved") "api task resolved")
    (assert (= (.-status res-mesh) "resolved") "mesh broadcast resolved")
    (assert (string-contains? asn-repr ":network-outcome") "asn contains network-outcome tag")
    (assert (string-contains? asn-repr ":facts 2") "asn reflects 2 facts")
    true))

(df test-processing-tier-routing-hierarchy [] -> Bool
  (let [(d-stop (pr/resolve-processing-tier "stop"))
        (d-cancel-ru (pr/resolve-processing-tier "отмена"))
        (d-audio (pr/resolve-processing-tier "озвучь статус"))
        (d-click (pr/resolve-processing-tier "кликни на кнопку"))
        (d-open (pr/resolve-processing-tier "open dashboard"))
        (d-cloud (pr/resolve-processing-tier "перепиши архитектуру компилятора"))
        (asn-d0 (pr/format-route-decision-asn d-stop))
        (asn-d1 (pr/format-route-decision-asn d-audio))
        (asn-d2 (pr/format-route-decision-asn d-click))
        (asn-d3 (pr/format-route-decision-asn d-cloud))]
    (assert (= (pr/tier-to-str (.-tier d-stop)) "tier-0-ast") "stop routed to tier 0")
    (assert (= (.-expected-latency-ms d-stop) 1) "tier 0 expected latency is 1ms")
    (assert (= (pr/tier-to-str (.-tier d-cancel-ru)) "tier-0-ast") "отмена routed to tier 0")
    (assert (= (pr/tier-to-str (.-tier d-audio)) "tier-1-audio") "озвучь routed to tier 1")
    (assert (= (.-expected-latency-ms d-audio) 18) "tier 1 expected latency is 18ms")
    (assert (= (pr/tier-to-str (.-tier d-click)) "tier-2-slm") "кликни routed to tier 2")
    (assert (= (pr/tier-to-str (.-tier d-open)) "tier-2-slm") "open routed to tier 2")
    (assert (= (.-expected-latency-ms d-click) 85) "tier 2 expected latency is 85ms")
    (assert (= (pr/tier-to-str (.-tier d-cloud)) "tier-3-cloud") "complex task routed to tier 3")
    (assert (= (.-expected-latency-ms d-cloud) 1200) "tier 3 expected latency is 1200ms")
    (assert (string-contains? asn-d0 "tier-0-ast") "asn reflects tier 0")
    (assert (string-contains? asn-d1 "tier-1-audio") "asn reflects tier 1")
    (assert (string-contains? asn-d2 "tier-2-slm") "asn reflects tier 2")
    (assert (string-contains? asn-d3 "tier-3-cloud") "asn reflects tier 3")
    true))

(df run-all-router-tests [] -> Bool
  (do
    (test-network-task-execution-and-outcomes)
    (test-processing-tier-routing-hierarchy)
    true))

(run-all-router-tests)
