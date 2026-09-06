(module asl-eddie/policy-test
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
    (and (and (.-silent r-read) (.-silent r-test))
         (and (not (.-silent r-write)) (not (.-silent r-exec))))))

(df test-l1-guarded-mode [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-test (pol/check-autonomy-permission "test" "/workspace/tests/app-test.asl" m (pol/level-guarded)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-guarded)))
        (r-exec (pol/check-autonomy-permission "exec" "/workspace/bin/run" m (pol/level-guarded)))]
    (and (and (.-silent r-read) (.-silent r-test))
         (and (not (.-silent r-write)) (not (.-silent r-exec))))))

(df test-l2-fullauto-mode [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-read (pol/check-autonomy-permission "read" "/workspace/src/app.asl" m (pol/level-auto)))
        (r-write (pol/check-autonomy-permission "write" "/workspace/src/app.asl" m (pol/level-auto)))
        (r-exec (pol/check-autonomy-permission "exec" "/workspace/bin/run" m (pol/level-auto)))]
    (and (and (.-silent r-read) (.-silent r-write))
         (.-silent r-exec))))

(df test-sandbox-traversal-rejections [] -> Bool
  (let [(m (pol/make-manifest "/workspace" (list) "/tmp" false))
        (r-trav (pol/check-autonomy-permission "read" "/workspace/../etc/passwd" m (pol/level-auto)))
        (r-sys (pol/check-autonomy-permission "read" "/etc/shadow" m (pol/level-auto)))]
    (and (not (.-allowed r-trav))
         (not (.-allowed r-sys)))))

(df run-tests [] -> Bool
  (and (and (test-l0-ask-mode)
            (test-l1-guarded-mode))
       (and (test-l2-fullauto-mode)
            (test-sandbox-traversal-rejections))))
