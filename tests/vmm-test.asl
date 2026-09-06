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
    (and (== (.-used-tokens st) 5)
         (.-is-pinned s1))))

(df test-vmm-knowledge-lifecycle [] -> Bool
  (let [(st0 (vmm/make-vmm-state "Root rules" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "zod@3.22" "interface ZodSchema { parse: (x: any) => any }"))
        (slots1 (.-slots st1))
        (s3-loaded (get slots1 2))
        (st2 (vmm/vmm-offload-knowledge st1 "zod@3.22" "src/schema.asl:12"))
        (slots2 (.-slots st2))
        (s3-cleared (get slots2 2))
        (s2-receipt (get slots2 1))]
    (and (> (.-tokens s3-loaded) 0)
         (and (== (.-tokens s3-cleared) 0)
              (> (len (.-payload s2-receipt)) 0)))))

(df test-vmm-compact-preserves-invariants [] -> Bool
  (let [(st0 (vmm/make-vmm-state "Root rules" 4096))
        (st1 (vmm/vmm-load-knowledge st0 "react@19" "export function useState()"))
        (st2 (vmm/vmm-compact st1))
        (slots (.-slots st2))
        (s1 (get slots 0))
        (s3 (get slots 2))]
    (and (== (.-payload s1) "Root rules")
         (== (.-tokens s3) 0))))

(df test-vmm-prompt-rendering [] -> Bool
  (let [(st (vmm/make-vmm-state "No foreign code" 4096))
        (prompt (vmm/vmm-render-prompt st))]
    (>= (len prompt) 50)))

(df run-tests [] -> Bool
  (and (and (test-vmm-initialization)
            (test-vmm-knowledge-lifecycle))
       (and (test-vmm-compact-preserves-invariants)
            (test-vmm-prompt-rendering))))
