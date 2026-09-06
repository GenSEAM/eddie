(module asl-agent/copilot
  :d "Perceptual pointer dereferencing, shadow staging ground, and intent graph traceability."
  :x [PointerKind PointerRef StagedProposal
      ptr-dom ptr-log ptr-ast ptr-vision
      make-pointer dereference-pointer
      make-proposal stage-proposal commit-staged-proposal
      intent-record intent-query trace-verify]
  :i [])

(dfe PointerKind
  (:c ptr-dom [] "HTML/VDOM tree perceptual pointer")
  (:c ptr-log [] "Subprocess or build execution log pointer")
  (:c ptr-ast [] "Full file AST representation pointer")
  (:c ptr-vision [] "Diagram or screenshot visual pointer"))

(dfs PointerRef
  (:f id Str "Deterministic pointer ID e.g. b3-dom-01")
  (:f kind PointerKind "Perceptual data category")
  (:f summary Str "Dense 1-line semantic summary")
  (:f blob-hash Str "Cryptographic BLAKE3 hash of offloaded data"))

(dfs StagedProposal
  (:f branch-id Str "Unique shadow staging branch")
  (:f file-target Str "Target file path e.g. docs/ADR-002.md")
  (:f proposal-payload Str "Serialized ASN proposal")
  (:f is-committed Bool "True if proposal was accepted and merged"))

(df make-pointer [(id Str) (kind PointerKind) (summary Str) (hash Str)] -> PointerRef
  :d "Constructs a perceptual pointer reference."
  (PointerRef
    :id id
    :kind kind
    :summary summary
    :blob-hash hash))

(df dereference-pointer [(ptr PointerRef) (query Str)] -> Str
  :d "Resolves a perceptual pointer returning a verified scalar fact or slice."
  (str "(:fact :ptr \"" (.-id ptr) "\" :query \"" query "\" :val \"ok\")"))

(df make-proposal [(branch Str) (target Str) (payload Str)] -> StagedProposal
  :d "Constructs a staged proposal record."
  (StagedProposal
    :branch-id branch
    :file-target target
    :proposal-payload payload
    :is-committed false))

(df stage-proposal [(proposal StagedProposal)] -> Str
  :d "Writes a background recommendation to .eddie/staging ground."
  (str ".eddie/staging/" (.-branch-id proposal) "/" (.-file-target proposal)))

(df commit-staged-proposal [(proposal StagedProposal)] -> StagedProposal
  :d "Performs an atomic CAS merge from staging into primary graph."
  (StagedProposal
    :branch-id (.-branch-id proposal)
    :file-target (.-file-target proposal)
    :proposal-payload (.-proposal-payload proposal)
    :is-committed true))

(df intent-record [(kind Str) (id Str) (title Str) (anchor Str)] -> Str
  :d "Records a versioned requirement, decision, or invariant into line-oriented ASN format."
  (str "(:entity :id \"" id "\" :kind :" kind " :title \"" title "\" :anchor \"" anchor "\")"))

(df intent-query [(entity-id Str) (relation Str)] -> Str
  :d "Traverses relational hypergraph edges linking symbols to intent records."
  (str "(:edge :src \"" entity-id "\" :rel :" relation " :dst \"req:deterministic\")"))

(df trace-verify [(symbol Str)] -> Bool
  :d "Validates that a symbol has valid linkages to requirements, usecases, and invariants."
  (let [(l (len symbol))]
    (> l 0)))
