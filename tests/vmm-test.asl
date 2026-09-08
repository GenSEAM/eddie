(module asl-agent/vmm-test
  :d "Unit tests for Prompt VMM segmented context slot hygiene."
  :x [test-vmm-initialization
      test-vmm-knowledge-lifecycle
      test-vmm-compact-preserves-invariants
      test-vmm-prompt-rendering
      run-tests]
  :i [(vmm :a vmm)])

"run: (run-tests)"

(df test-vmm-initialization [] -> Bool
  (let [(st (vmm/make-vmm-state "Never delete assertions" 4096))
        (slots (.-slots st))
        (s1 (get slots 0))]
    (assert (= (.-used-tokens st) 5) "used tokens matches initial count")
    (assert (.-is-pinned s1) "slot 0 is pinned")
    true))

(df test-vmm-knowledge-lifecycle [] -> Bool
  (let [(st0 (vmm/make-vmm-state "Root rules" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "zod@3.22" "interface ZodSchema { parse: (x: any) => any }"))
        (slots1 (.-slots st1))
        (s3-loaded (get slots1 2))
        (st2 (vmm/vmm-offload-knowledge st1 "zod@3.22" "src/schema.asl:12"))
        (slots2 (.-slots st2))
        (s3-cleared (get slots2 2))
        (s2-receipt (get slots2 1))]
    (assert (> (.-tokens s3-loaded) 0) "loaded tokens > 0")
    (assert (= (.-tokens s3-cleared) 0) "cleared tokens == 0")
    (assert (> (string-length (.-payload s2-receipt)) 0) "receipt payload non-empty")
    true))

(df test-vmm-compact-preserves-invariants [] -> Bool
  (let [(st0 (vmm/make-vmm-state "Root rules" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "react@19" "export function useState()"))
        (st2 (vmm/vmm-compact st1))
        (slots (.-slots st2))
        (s1 (get slots 0))
        (s3 (get slots 2))]
    (assert (= (.-payload s1) "Root rules") "slot 1 payload preserved")
    (assert (= (.-tokens s3) 0) "slot 3 tokens cleared after compact")
    true))

(df test-vmm-prompt-rendering [] -> Bool
  (let [(st (vmm/make-vmm-state "No foreign code" 4096))
        (prompt (vmm/vmm-render-prompt st))]
    (assert (>= (string-length prompt) 50) "rendered prompt length >= 50")
    true))

(df run-tests [] -> Bool
  (do
    (test-vmm-initialization)
    (test-vmm-knowledge-lifecycle)
    (test-vmm-compact-preserves-invariants)
    (test-vmm-prompt-rendering)
    true))
