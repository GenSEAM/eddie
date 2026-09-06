(module asl-agent/vmm
  :d "Prompt Virtual Memory Manager (VMM) and segmented context slot hygiene."
  :x [ContextSlot VmmSlot VmmState
      slot-invariants slot-receipts slot-pinned slot-working
      make-vmm-slot make-vmm-state
      vmm-load-knowledge vmm-offload-knowledge
      vmm-compact vmm-render-prompt]
  :i [])

(dfe ContextSlot
  (:c slot-invariants [] "Slot 1: Immutable Invariants (zero eviction priority)")
  (:c slot-receipts [] "Slot 2: Semantic Receipts Ledger (compact 1-line stubs)")
  (:c slot-pinned [] "Slot 3: Pinned Domain Slot (Paged ephemeral JIT types)")
  (:c slot-working [] "Slot 4: Working Frame (Active task and local AST slices)"))

(dfs VmmSlot
  (:f slot-id ContextSlot "Context slot category")
  (:f payload Str "Serialized slot contents")
  (:f tokens I64 "Token count occupied by slot")
  (:f is-pinned Bool "True if slot is immune from budget eviction"))

(dfs VmmState
  (:f slots (List VmmSlot) "All 4 segmented context slots")
  (:f max-tokens I64 "Total context window token budget ceiling")
  (:f used-tokens I64 "Current total tokens across all slots"))

(df make-vmm-slot [(id ContextSlot) (payload Str) (tokens I64) (pinned Bool)] -> VmmSlot
  :d "Constructs a VMM context slot record."
  (VmmSlot
    :slot-id id
    :payload payload
    :tokens tokens
    :is-pinned pinned))

(df make-vmm-state [(invariants-text Str) (max-tokens I64)] -> VmmState
  :d "Initializes the 4-slot Prompt VMM with Slot 1 (invariants) immutable and pinned."
  (let [(toks-inv (/ (len invariants-text) 4))
        (s1 (VmmSlot :slot-id (slot-invariants) :payload invariants-text :tokens toks-inv :is-pinned true))
        (s2 (VmmSlot :slot-id (slot-receipts) :payload "" :tokens 0 :is-pinned false))
        (s3 (VmmSlot :slot-id (slot-pinned) :payload "" :tokens 0 :is-pinned false))
        (s4 (VmmSlot :slot-id (slot-working) :payload "" :tokens 0 :is-pinned false))]
    (VmmState
      :slots (list s1 s2 s3 s4)
      :max-tokens max-tokens
      :used-tokens toks-inv)))

(df vmm-load-knowledge [(state VmmState) (target Str) (spec Str)] -> VmmState
  :d "JIT hydrates external library interface stubs into Slot 3 (pinned knowledge)."
  (let [(slots (.-slots state))
        (s1 (get slots 0))
        (s2 (get slots 1))
        (s4 (get slots 3))
        (toks (/ (len spec) 4))
        (s3-updated (VmmSlot :slot-id (slot-pinned) :payload spec :tokens toks :is-pinned false))
        (total-toks (+ (+ (.-tokens s1) (.-tokens s2)) (+ toks (.-tokens s4))))]
    (VmmState
      :slots (list s1 s2 s3-updated s4)
      :max-tokens (.-max-tokens state)
      :used-tokens total-toks)))

(df vmm-offload-knowledge [(state VmmState) (target Str) (anchor Str)] -> VmmState
  :d "Wipes Slot 3 and mints a compact 12-token semantic receipt in Slot 2."
  (let [(slots (.-slots state))
        (s1 (get slots 0))
        (s2 (get slots 1))
        (s4 (get slots 3))
        (receipt (str "(:receipt :target \"" target "\" :action \"validated-schema\" :anchor \"" anchor "\")"))
        (s2-payload (if (== (len (.-payload s2)) 0)
                      receipt
                      (str (.-payload s2) "\n" receipt)))
        (s2-toks (/ (len s2-payload) 4))
        (s2-updated (VmmSlot :slot-id (slot-receipts) :payload s2-payload :tokens s2-toks :is-pinned false))
        (s3-cleared (VmmSlot :slot-id (slot-pinned) :payload "" :tokens 0 :is-pinned false))
        (total-toks (+ (+ (.-tokens s1) s2-toks) (.-tokens s4)))]
    (VmmState
      :slots (list s1 s2-updated s3-cleared s4)
      :max-tokens (.-max-tokens state)
      :used-tokens total-toks)))

(df vmm-compact [(state VmmState)] -> VmmState
  :d "Evicts Slot 3 under budget pressure while guaranteeing Slot 1 (invariants) is preserved."
  (let [(slots (.-slots state))
        (s1 (get slots 0))
        (s2 (get slots 1))
        (s4 (get slots 3))
        (s3-cleared (VmmSlot :slot-id (slot-pinned) :payload "" :tokens 0 :is-pinned false))
        (total-toks (+ (+ (.-tokens s1) (.-tokens s2)) (.-tokens s4)))]
    (VmmState
      :slots (list s1 s2 s3-cleared s4)
      :max-tokens (.-max-tokens state)
      :used-tokens total-toks)))

(df vmm-render-prompt [(state VmmState)] -> Str
  :d "Stitches all 4 slots into a compact prompt string."
  (let [(slots (.-slots state))
        (s1 (get slots 0))
        (s2 (get slots 1))
        (s3 (get slots 2))
        (s4 (get slots 3))]
    (str "=== INVARIANTS ===\n" (.-payload s1) "\n"
         "=== RECEIPTS ===\n" (.-payload s2) "\n"
         "=== DOMAIN KNOWLEDGE ===\n" (.-payload s3) "\n"
         "=== WORKING FRAME ===\n" (.-payload s4))))
