(module asl-agent/computer-use
  :d "Autonomous Computer Control: Spoken OS navigation, Chrome DevTools Protocol driver, macOS Accessibility bridge, and spatial bounding box grounding"
  :x [TargetSubstrate
      ComputerActionKind
      SpatialBoundingBox
      ComputerActionRequest
      ComputerActionReceipt
      substrate-browser
      substrate-desktop
      substrate-terminal
      action-navigate
      action-click
      action-type
      action-inspect
      action-screenshot
      make-spatial-box
      make-computer-action
      confirm-computer-action
      is-action-permitted?
      format-cdp-payload
      format-accessibility-payload
      execute-computer-action
      format-computer-receipt-asn]
  :i [(core/strings :a s)])

(dfe TargetSubstrate
  (:c substrate-browser [] "Browser substrate via Chrome DevTools Protocol")
  (:c substrate-desktop [] "Desktop substrate via macOS Accessibility API")
  (:c substrate-terminal [] "Terminal CLI execution via PTY"))

(dfe ComputerActionKind
  (:c action-navigate [] "Navigate to URL or open application")
  (:c action-click [] "Mouse click or element tap")
  (:c action-type [] "Keyboard typing or key combination")
  (:c action-inspect [] "Query accessibility tree or element hierarchy")
  (:c action-screenshot [] "Capture active window or spatial box"))

(dfs SpatialBoundingBox
  (:f x Int64 "Left coordinate in pixels")
  (:f y Int64 "Top coordinate in pixels")
  (:f width Int64 "Bounding box width in pixels")
  (:f height Int64 "Bounding box height in pixels"))

(dfs ComputerActionRequest
  (:f action-id Str "Unique action identifier")
  (:f substrate TargetSubstrate "Target operating system or browser substrate")
  (:f kind ComputerActionKind "Categorical action operation")
  (:f target-selector Str "CSS selector, AXNodeId, or window title")
  (:f payload Str "URL, input text, or execution parameters")
  (:f box SpatialBoundingBox "Spatial bounding box for visual grounding")
  (:f is-destructive Bool "True if action modifies persistent system state")
  (:f confirmed-by-user Bool "Safety confirmation flag from operator"))

(dfs ComputerActionReceipt
  (:f action-id Str "Executed action identifier")
  (:f exit-code Int64 "Process return code: 0 = successful execution")
  (:f status Str "Execution state: success, blocked-by-safety, failed")
  (:f observation Str "Observed state delta or sensory receipt")
  (:f duration-ms Int64 "Execution latency in milliseconds"))

(df make-spatial-box [(x Int64) (y Int64) (w Int64) (h Int64)] -> SpatialBoundingBox
  :d "Constructs SpatialBoundingBox record"
  (SpatialBoundingBox
    :x x
    :y y
    :width w
    :height h))

(df make-computer-action [(id Str) (sub TargetSubstrate) (kind ComputerActionKind) (selector Str) (payload Str) (box SpatialBoundingBox) (destructive Bool)] -> ComputerActionRequest
  :d "Constructs unconfirmed ComputerActionRequest"
  (ComputerActionRequest
    :action-id id
    :substrate sub
    :kind kind
    :target-selector selector
    :payload payload
    :box box
    :is-destructive destructive
    :confirmed-by-user false))

(df confirm-computer-action [(action ComputerActionRequest)] -> ComputerActionRequest
  :d "Applies explicit operator confirmation to permit destructive execution"
  (ComputerActionRequest
    :action-id (.-action-id action)
    :substrate (.-substrate action)
    :kind (.-kind action)
    :target-selector (.-target-selector action)
    :payload (.-payload action)
    :box (.-box action)
    :is-destructive (.-is-destructive action)
    :confirmed-by-user true))

(df is-action-permitted? [(action ComputerActionRequest)] -> Bool
  :d "Safety barrier: destructive actions are strictly blocked unless confirmed by user"
  (if (.-is-destructive action)
    (.-confirmed-by-user action)
    true))

(df format-cdp-payload [(action ComputerActionRequest)] -> Str
  :d "Formats Chrome DevTools Protocol JSON command"
  (mt (.-kind action)
    ((action-navigate) (str "{\"id\":1,\"method\":\"Page.navigate\",\"params\":{\"url\":\"" (.-payload action) "\"}}"))
    ((action-click) (str "{\"id\":2,\"method\":\"Input.dispatchMouseEvent\",\"params\":{\"type\":\"mousePressed\",\"x\":" (string-from-int64 (.-x (.-box action))) ",\"y\":" (string-from-int64 (.-y (.-box action))) ",\"button\":\"left\",\"clickCount\":1}}"))
    ((action-type) (str "{\"id\":3,\"method\":\"Input.insertText\",\"params\":{\"text\":\"" (.-payload action) "\"}}"))
    ((action-inspect) "{\"id\":4,\"method\":\"Accessibility.getFullAXTree\",\"params\":{}}")
    ((action-screenshot) "{\"id\":5,\"method\":\"Page.captureScreenshot\",\"params\":{}}")))

(df format-accessibility-payload [(action ComputerActionRequest)] -> Str
  :d "Formats macOS Accessibility AXUIElement S-expression command"
  (str "(:ax-call :target \"" (.-target-selector action) "\" :action \"" (.-payload action) "\" :box (:x " (string-from-int64 (.-x (.-box action))) " :y " (string-from-int64 (.-y (.-box action))) "))"))

(df execute-computer-action [(action ComputerActionRequest)] -> ComputerActionReceipt
  :d "Simulates deterministic execution gate verifying safety barriers"
  (if (not (is-action-permitted? action))
    (ComputerActionReceipt
      :action-id (.-action-id action)
      :exit-code 1
      :status "blocked-by-safety"
      :observation "Destructive operation blocked pending operator confirmation"
      :duration-ms 0)
    (ComputerActionReceipt
      :action-id (.-action-id action)
      :exit-code 0
      :status "success"
      :observation (str "Executed action on " (.-target-selector action))
      :duration-ms 18)))

(df format-computer-receipt-asn [(r ComputerActionReceipt)] -> Str
  :d "Renders high-density ASN receipt for computer control action"
  (str "(:action-receipt :id \"" (.-action-id r) "\" :status \"" (.-status r) "\" :exit " (string-from-int64 (.-exit-code r)) " :latency-ms " (string-from-int64 (.-duration-ms r)) ")"))
