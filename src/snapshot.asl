(module asl-agent/snapshot
  :d "Git-mergeable textual snapshot engine for deterministic state and intent persistence."
  :x [SnapshotKind SnapshotEntity SnapshotGraph
      kind-req kind-decision kind-invariant kind-edge
      make-entity make-graph
      format-entity parse-kind
      serialize-graph deserialize-graph
      diff-graphs]
  :i [])

(dfe SnapshotKind
  (:c kind-req [] "Functional or non-functional requirement")
  (:c kind-decision [] "Architectural decision record with rationale")
  (:c kind-invariant [] "Immutable negative rule or boundary ceiling")
  (:c kind-edge [] "Relational link tuple between entities"))

(dfs SnapshotEntity
  (:f id Str "Unique deterministic entity identifier e.g. req:001, dec:sqlite")
  (:f kind SnapshotKind "Category of recorded entity")
  (:f payload Str "Concise textual description or relation")
  (:f anchor Str "Source file and line reference e.g. src/db.asl:42"))

(dfs SnapshotGraph
  (:f entities (List SnapshotEntity) "Line-oriented, deterministic entity list")
  (:f version Str "Schema version identifier e.g. v1.0"))

(df make-entity [(id Str) (kind SnapshotKind) (payload Str) (anchor Str)] -> SnapshotEntity
  :d "Constructs a snapshot entity record."
  (SnapshotEntity
    :id id
    :kind kind
    :payload payload
    :anchor anchor))

(df make-graph [(entities (List SnapshotEntity)) (version Str)] -> SnapshotGraph
  :d "Constructs a snapshot graph instance."
  (SnapshotGraph
    :entities entities
    :version version))

(df parse-kind [(tag Str)] -> SnapshotKind
  :d "Parses a string tag into a SnapshotKind."
  (cond
    ((== tag "req") (kind-req))
    ((== tag "decision") (kind-decision))
    ((== tag "invariant") (kind-invariant))
    (true (kind-edge))))

(df format-entity [(entity SnapshotEntity)] -> Str
  :d "Formats a snapshot entity into a single-line S-expression."
  (let [(k (case (.-kind entity)
             ((kind-req) "req")
             ((kind-decision) "decision")
             ((kind-invariant) "invariant")
             ((kind-edge) "edge")))]
    (str "(:entity :id \"" (.-id entity) "\" :kind :" k " :payload \"" (.-payload entity) "\" :anchor \"" (.-anchor entity) "\")")))

(df serialize-graph [(graph SnapshotGraph)] -> Str
  :d "Serializes a snapshot graph into deterministic, sorted line-oriented S-expressions."
  (let [(ents (.-entities graph))]
    (cond
      ((= (list-length ents) 0) ";; .eddie/snapshot.asn (empty)")
      ((= (list-length ents) 1) (format-entity (get ents 0)))
      (true
       (let [(e0 (format-entity (get ents 0)))
             (e1 (format-entity (get ents 1)))]
         (if (<= (.-id (get ents 0)) (.-id (get ents 1)))
           (str e0 "\n" e1)
           (str e1 "\n" e0)))))))

(df extract-quoted-field [(line Str) (tag Str)] -> Str
  (let [(idx (string-index-of line tag))]
    (if (option-some? idx)
      (let [(after (option-or (string-slice line (+ (option-unwrap idx) (string-length tag)) (string-length line)) ""))
            (q-idx (string-index-of after "\""))]
        (if (option-some? q-idx)
          (option-or (string-slice after 0 (option-unwrap q-idx)) "")
          ""))
      "")))

(df extract-kind-field [(line Str)] -> SnapshotKind
  (let [(idx (string-index-of line ":kind :"))]
    (if (option-some? idx)
      (let [(after (option-or (string-slice line (+ (option-unwrap idx) 7) (string-length line)) ""))
            (sp-idx (string-index-of after " "))]
        (let [(k-str (if (option-some? sp-idx) (option-or (string-slice after 0 (option-unwrap sp-idx)) after) after))]
          (parse-kind k-str)))
      (kind-req))))

(df parse-entity-line [(line Str)] -> (Option SnapshotEntity)
  (let [(trimmed (string-trim line))]
    (if (string-starts-with? trimmed "(:entity")
      (let [(id (extract-quoted-field trimmed ":id \""))
            (kind (extract-kind-field trimmed))
            (payload (extract-quoted-field trimmed ":payload \""))
            (anchor (extract-quoted-field trimmed ":anchor \""))]
        (some (SnapshotEntity :id id :kind kind :payload payload :anchor anchor)))
      (none))))

(df deserialize-graph [(content Str)] -> SnapshotGraph
  :d "Parses serialized snapshot content into a structured SnapshotGraph."
  (let [(trimmed (string-trim content))]
    (if (= (string-length trimmed) 0)
      (SnapshotGraph :entities (list) :version "v1.0")
      (let [(lines (string-split trimmed "\n"))
            (ents (fold (fn [(acc (List SnapshotEntity)) (line Str)] -> (List SnapshotEntity)
                          (mt (parse-entity-line line)
                            ((some e) (list-append acc (list e)))
                            ((none) acc)))
                        (list)
                        lines))]
        (SnapshotGraph :entities ents :version "v1.0")))))

(df diff-graphs [(old-graph SnapshotGraph) (new-graph SnapshotGraph)] -> I64
  :d "Computes number of entity additions between two snapshot graphs."
  (- (list-length (.-entities new-graph)) (list-length (.-entities old-graph))))
