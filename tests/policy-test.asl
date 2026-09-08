(module asl-agent/policy-test
  :d "Unit tests for Autonomy Levels (L0/L1/L2) and capability sandboxing."
  :x [test-l0-ask-mode
      test-l1-guarded-mode
      test-l2-fullauto-mode
      test-sandbox-traversal-rejections
      run-tests]
  :i [(policy :a pol)])

"run: (run-tests)"

(df test-l0-ask-mode [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-ask)))
        (r-test (pol/check-autonomy-permission "test" "/workspace/tests/app-test.asl" m (pol/level-ask)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-ask)))
        (r-exec (pol/check-autonomy-permission "exec" "/workspace/bin/run" m (pol/level-ask)))]
    (assert (.-silent r-read) "L0 read is silent")
    (assert (.-silent r-test) "L0 test is silent")
    (assert (not (.-silent r-write)) "L0 write prompts user")
    (assert (not (.-silent r-exec)) "L0 exec prompts user")
    true))

(df test-l1-guarded-mode [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-test (pol/check-autonomy-permission "test" "/workspace/tests/app-test.asl" m (pol/level-guarded)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-exec (pol/check-autonomy-permission "exec" "/workspace/bin/run" m (pol/level-guarded)))]
    (assert (.-silent r-read) "L1 read is silent")
    (assert (.-silent r-test) "L1 test is silent")
    (assert (not (.-silent r-write)) "L1 write prompts user")
    (assert (not (.-silent r-exec)) "L1 exec prompts user")
    true))

(df test-l2-fullauto-mode [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-auto)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-auto)))
        (r-exec (pol/check-autonomy-permission "exec" "/workspace/bin/run" m (pol/level-auto)))]
    (assert (.-silent r-read) "L2 read is silent")
    (assert (.-silent r-write) "L2 write is silent")
    (assert (.-silent r-exec) "L2 exec is silent")
    true))

(df test-sandbox-traversal-rejections [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-trav (pol/check-autonomy-permission "read" "/workspace/../etc/passwd" m (pol/level-auto)))
        (r-sys (pol/check-autonomy-permission "read" "/etc/shadow" m (pol/level-auto)))]
    (assert (not (.-allowed r-trav)) "traversal is rejected")
    (assert (not (.-allowed r-sys)) "system file access is rejected")
    true))

(df run-tests [] -> Bool
  (do
    (test-l0-ask-mode)
    (test-l1-guarded-mode)
    (test-l2-fullauto-mode)
    (test-sandbox-traversal-rejections)
    true))
