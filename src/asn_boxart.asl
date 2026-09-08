(module asl-agent/asn-boxart
  :d "Native ASN DAG and Tree renderer into Unicode Box-Art for terminal CLI"
  :x [BoxNode
      BoxEdge
      format-box-badge
      render-tree-boxart
      render-dag-boxart]
  :i [])

(dfs BoxNode
  (:f id Str "Node unique identifier")
  (:f title Str "Node human-readable title or label")
  (:f state Str "Status indicator: done, running, failed, queued, or blocked"))

(dfs BoxEdge
  (:f from Str "Source node identifier")
  (:f to Str "Target node identifier")
  (:f label (Option Str) "Optional relationship description"))

(df format-box-badge [(state Str) (text Str)] -> Str
  :d "Formats a status badge prefix for a node box label."
  (let [(icon (cond
                ((or (= state "done") (or (= state "passed") (= state "ok"))) "✓")
                ((or (= state "running") (or (= state "active") (= state "in-progress"))) "▶")
                ((or (= state "failed") (= state "error")) "✗")
                ((or (= state "blocked") (= state "waiting")) "⏸")
                (:else "•")))]
    (str "[" icon "] " text)))

(df render-tree-boxart [(root-title Str) (branches (List Str))] -> Str
  :d "Renders a hierarchical tree using clean Unicode box-drawing characters."
  (let [(n (list-length branches))]
    (if (= n 0)
      root-title
      (let [(body (fold (fn [(acc Str) (idx I64)] -> Str
                          (let [(branch (option-or (list-get branches idx) ""))
                                (is-last (= idx (- n 1)))
                                (connector (if is-last "└── " "├── "))]
                            (str acc "\n" connector branch)))
                        root-title
                        (list-range 0 n)))]
        body))))

(df render-node-box [(node BoxNode)] -> Str
  :d "Renders a single node enclosed in a Unicode box."
  (let [(badge (format-box-badge (.-state node) (str (.-id node) " : " (.-title node))))
        (pad-content (str "│ " badge " │"))
        (inner-len (+ (string-length badge) 2))
        (top-border (str "┌" (string-repeat "─" inner-len) "┐"))
        (bot-border (str "└" (string-repeat "─" inner-len) "┘"))]
    (str top-border "\n" pad-content "\n" bot-border)))

(df find-outgoing-edges [(edges (List BoxEdge)) (node-id Str)] -> (List BoxEdge)
  :d "Finds all directed edges starting from given node."
  (fold (fn [(acc (List BoxEdge)) (e BoxEdge)] -> (List BoxEdge)
          (if (= (.-from e) node-id)
            (list-append acc (list e))
            acc))
        (list)
        edges))

(df render-dag-boxart [(nodes (List BoxNode)) (edges (List BoxEdge))] -> Str
  :d "Renders a DAG sequence into connected Unicode box-art frames."
  (let [(n (list-length nodes))]
    (if (= n 0)
      ""
      (fold (fn [(acc Str) (idx I64)] -> Str
              (let [(cur-node (option-or (list-get nodes idx) (BoxNode :id "" :title "" :state "")))
                    (box-str (render-node-box cur-node))
                    (is-last (= idx (- n 1)))
                    (out-edges (find-outgoing-edges edges (.-id cur-node)))
                    (has-edge (> (list-length out-edges) 0))
                    (edge-opt (list-get out-edges 0))
                    (lbl-str (mt edge-opt
                               ((none) "")
                               ((some ed)
                                (mt (.-label ed)
                                  ((none) "")
                                  ((some l) (str " (" l ")"))))))
                    (connector (if (not is-last)
                                 (if has-edge
                                   (str "\n       │" lbl-str "\n       ▼\n")
                                   "\n\n")
                                 ""))]
                (if (string-empty? acc)
                  (str box-str connector)
                  (str acc box-str connector))))
            ""
            (list-range 0 n)))))
