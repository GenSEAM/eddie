(module asl-agent-tests/model-router-test
  :d "Dual-polarity test suite for model routing matrix, role-based model dispatch, and local offline fallback."
  :x [test-model-routing-by-role
      test-model-offline-fallback
      test-format-route-decision
      run-tests]
  :i [(model_router :a router)])

(df test-model-routing-by-role [] -> Bool
  :d "Verifies that task roles map to designated models with explicit capability profiles."
  (let [(m (router/default-routing-matrix))
        (ep-design (router/resolve-model-for-role (router/role-design) m false))
        (ep-coding (router/resolve-model-for-role (router/role-coding) m false))
        (ep-review (router/resolve-model-for-role (router/role-review) m false))]
    (assert (= (.-model-id ep-design) "gemini-2.5-flash") "c-router-pos-001: design model is flash")
    (assert (= (.-model-id ep-coding) "gemma-4-31b-it") "c-router-pos-001: coding model is gemma")
    (assert (= (.-model-id ep-review) "gemini-2.5-pro") "c-router-pos-001: review model is pro")
    (assert (not (= (.-model-id ep-review) "unknown")) "c-router-pos-001: review model not unknown")
    true))

(df test-model-offline-fallback [] -> Bool
  :d "Verifies offline flag forces immediate fallback to verified local SLM endpoint."
  (let [(m (router/default-routing-matrix))
        (ep-offline (router/resolve-model-for-role (router/role-review) m true))]
    (assert (.-is-local ep-offline) "c-router-neg-001: offline endpoint is local")
    (assert (not (= (.-model-id ep-offline) "gemini-2.5-pro")) "c-router-neg-001: offline not cloud pro")
    true))

(df test-format-route-decision [] -> Bool
  :d "Verifies routing decision summary formatting renders role and budget telemetry."
  (let [(m (router/default-routing-matrix))
        (ep-review (router/resolve-model-for-role (router/role-review) m false))
        (report (router/format-route-decision (router/role-review) ep-review))]
    (assert (string-contains? report "Role [review]") "route decision contains role")
    (assert (not (= report "")) "route decision not empty")
    true))

(df run-tests [] -> Bool
  :d "Executes all model router test functions."
  (and (test-model-routing-by-role)
       (and (test-model-offline-fallback)
            (test-format-route-decision))))
