(module asl-agent/test-computer-use
  :d "Unit verification test suite for Spoken Computer Control, Chrome DevTools Protocol, and macOS Accessibility Bridge"
  :x [test-spatial-box-and-action-creation
      test-cdp-payload-formatting
      test-accessibility-payload-formatting
      test-safety-barrier-and-confirmation
      run-all-computer-use-tests]
  :i [(computer_use :a cu)])

(df test-spatial-box-and-action-creation [] -> Bool
  (let [(box (cu/make-spatial-box 120 240 80 40))
        (act (cu/make-computer-action "act-1" (cu/substrate-browser) (cu/action-navigate) "window" "https://github.com" box false))]
    (assert (= (.-x box) 120) "box x coordinate matches")
    (assert (= (.-y box) 240) "box y coordinate matches")
    (assert (= (.-width box) 80) "box width matches")
    (assert (= (.-height box) 40) "box height matches")
    (assert (= (.-action-id act) "act-1") "action-id matches")
    (assert (cu/is-action-permitted? act) "non-destructive action is permitted")
    true))

(df test-cdp-payload-formatting [] -> Bool
  (let [(box (cu/make-spatial-box 100 200 50 20))
        (a-nav (cu/make-computer-action "a1" (cu/substrate-browser) (cu/action-navigate) "doc" "https://example.com" box false))
        (a-clk (cu/make-computer-action "a2" (cu/substrate-browser) (cu/action-click) "#btn" "click" box false))
        (a-typ (cu/make-computer-action "a3" (cu/substrate-browser) (cu/action-type) "input" "hello world" box false))
        (a-ins (cu/make-computer-action "a4" (cu/substrate-browser) (cu/action-inspect) "root" "" box false))
        (a-scr (cu/make-computer-action "a5" (cu/substrate-browser) (cu/action-screenshot) "viewport" "" box false))
        (p-nav (cu/format-cdp-payload a-nav))
        (p-clk (cu/format-cdp-payload a-clk))
        (p-typ (cu/format-cdp-payload a-typ))
        (p-ins (cu/format-cdp-payload a-ins))
        (p-scr (cu/format-cdp-payload a-scr))]
    (assert (string-contains? p-nav "Page.navigate") "cdp navigate payload")
    (assert (string-contains? p-nav "https://example.com") "cdp url target")
    (assert (string-contains? p-clk "Input.dispatchMouseEvent") "cdp click payload")
    (assert (string-contains? p-clk "\"x\":100") "cdp click x coordinate")
    (assert (string-contains? p-clk "\"y\":200") "cdp click y coordinate")
    (assert (string-contains? p-typ "Input.insertText") "cdp type payload")
    (assert (string-contains? p-typ "hello world") "cdp type text")
    (assert (string-contains? p-ins "Accessibility.getFullAXTree") "cdp inspect payload")
    (assert (string-contains? p-scr "Page.captureScreenshot") "cdp screenshot payload")
    true))

(df test-accessibility-payload-formatting [] -> Bool
  (let [(box (cu/make-spatial-box 50 80 400 300))
        (act (cu/make-computer-action "a-ax" (cu/substrate-desktop) (cu/action-click) "Slack" "focus" box false))
        (payload (cu/format-accessibility-payload act))]
    (assert (string-contains? payload ":ax-call") "contains ax-call tag")
    (assert (string-contains? payload ":target \"Slack\"") "contains desktop target")
    (assert (string-contains? payload ":action \"focus\"") "contains action operation")
    (assert (string-contains? payload ":x 50") "contains spatial box x")
    true))

(df test-safety-barrier-and-confirmation [] -> Bool
  (let [(box (cu/make-spatial-box 0 0 100 100))
        (act-danger (cu/make-computer-action "rm-1" (cu/substrate-terminal) (cu/action-click) "terminal" "drop database" box true))]
    (refute (cu/is-action-permitted? act-danger) "unconfirmed destructive action is forbidden")
    (let [(receipt-blocked (cu/execute-computer-action act-danger))]
      (assert (= (.-exit-code receipt-blocked) 1) "blocked action returns exit code 1")
      (assert (= (.-status receipt-blocked) "blocked-by-safety") "blocked status set")
      (let [(act-confirmed (cu/confirm-computer-action act-danger))]
        (assert (cu/is-action-permitted? act-confirmed) "confirmed action is permitted")
        (let [(receipt-ok (cu/execute-computer-action act-confirmed))
              (asn-repr (cu/format-computer-receipt-asn receipt-ok))]
          (assert (= (.-exit-code receipt-ok) 0) "confirmed action returns exit code 0")
          (assert (= (.-status receipt-ok) "success") "confirmed action executed successfully")
          (assert (string-contains? asn-repr ":status \"success\"") "asn receipt reflects success")
          (assert (string-contains? asn-repr ":exit 0") "asn receipt reflects exit code 0"))))
    true))

(df run-all-computer-use-tests [] -> Bool
  (do
    (test-spatial-box-and-action-creation)
    (test-cdp-payload-formatting)
    (test-accessibility-payload-formatting)
    (test-safety-barrier-and-confirmation)
    true))

(run-all-computer-use-tests)
