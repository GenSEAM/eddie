(module asl-agent/pty-test
  :d "Unit test verification suite for zero-LLM PTY stream bypass, ANSI filtering, sparklines, and quarantine."
  :x [test-strip-ansi-colors
      test-pty-stream-bypass
      test-sparkline-quantization-bounds
      test-sparkline-compression-and-downsampling
      test-quarantined-thought-logging
      test-pointer-offload-and-deref
      run-tests]
  :i [(pty :a pty)])

(df test-strip-ansi-colors [] -> Bool
  :d "Verifies ANSI escape sequence stripping across standard color, attribute, and cursor sequences."
  (do
    (assert (= (pty/strip-ansi-escapes "\u001b[31mRed Text\u001b[0m") "Red Text") "Stripping 16-color ANSI codes yields plain text")
    (assert (= (pty/strip-ansi-escapes "\u001b[1mBold\u001b[0m \u001b[2mDim\u001b[0m") "Bold Dim") "Stripping bold and dim ANSI attributes yields clean text")
    (assert (string-contains? (pty/strip-ansi-escapes "\u001b[2K\rLoading...\u001b[1A") "Loading...") "Stripping cursor movement retains printable characters")
    (assert (= (pty/strip-ansi-escapes "Pure ASL Output") "Pure ASL Output") "Plain text without ANSI is preserved verbatim")
    (assert (= (pty/strip-ansi-escapes "") "") "Empty string returns empty stripped result")
    true))

(df test-pty-stream-bypass [] -> Bool
  :d "Verifies zero-LLM direct PTY stream bypass metadata generation and formatting."
  (let [(res (pty/pty-stream-bypass "\u001b[32mBuild completed in 1.2s\u001b[0m" 0 1200))
        (res-fail (pty/pty-stream-bypass "\u001b[31mFatal: compilation aborted\u001b[0m" 1 450))
        (fmt (pty/format-pty-result (pty/make-pty-result 0 500 120 "Build succeeded")))]
    (do
      (assert (= (.-exit-code res) 0) "Successful PTY bypass preserves zero exit code")
      (assert (= (.-duration-ms res) 1200) "PTY bypass accurately records wall-clock duration")
      (assert (> (.-bytes-streamed res) 0) "PTY bypass measures positive streamed bytes")
      (assert (string-contains? (.-summary res) "cleanly") "Summary records clean completion")
      (assert (= (.-exit-code res-fail) 1) "Failed PTY bypass preserves error exit code")
      (assert (string-contains? (.-summary res-fail) "exit code 1") "Summary contains failed exit code descriptor")
      (assert (string-contains? fmt "(:pty-result :exit-code 0") "Formatted PTY result contains valid S-expression tag")
      (assert (string-contains? fmt ":bytes-streamed 120") "Formatted PTY result contains streamed byte metric")
      true)))

(df test-sparkline-quantization-bounds [] -> Bool
  :d "Verifies 8-level Unicode sparkline quantization lower, upper, and intermediate bounds."
  (do
    (assert (= (pty/quantize-sparkline-point 0) " ") "Zero metric quantizes to lowest sparkline block level 0")
    (assert (= (pty/quantize-sparkline-point -10) " ") "Negative metric clamps to lowest sparkline block level 0")
    (assert (= (pty/quantize-sparkline-point 100) "█") "100 percent metric quantizes to full sparkline block level 7")
    (assert (= (pty/quantize-sparkline-point 150) "█") "Metric above 100 clamps to full sparkline block level 7")
    (assert (= (pty/quantize-sparkline-point 15) "▂") "15 percent metric quantizes to level 1 block")
    (assert (= (pty/quantize-sparkline-point 50) "▅") "50 percent metric quantizes to level 4 block")
    (assert (= (pty/quantize-sparkline-point 75) "▇") "75 percent metric quantizes to level 6 block")
    (assert (= (pty/sparkline-glyph 0) " ") "Glyph for level 0 is lower one eighth block")
    (assert (= (pty/sparkline-glyph 7) "█") "Glyph for level 7 is full block")
    true))

(df test-sparkline-compression-and-downsampling [] -> Bool
  :d "Verifies compressing metric series into fixed-width Unicode sparklines."
  (let [(series (list 0 25 50 75 100))
        (data100 (range 0 100))
        (downsampled (pty/downsample-metrics (range 0 100) 10))
        (spark (pty/compress-metrics-sparkline (range 0 100) 10))]
    (do
      (assert (= (pty/render-sparkline series) " ▃▅▇█") "Sparkline rendering converts raw sequence into block characters")
      (assert (= (list-length downsampled) 10) "Downsampling 100 points to 10 yields exactly 10 averaged buckets")
      (assert (<= (string-length spark) 30) "10-character Unicode sparkline takes <= 30 UTF-8 bytes")
      (assert (= (list-length (string-chars spark)) 10) "Compressed sparkline contains exactly 10 glyphs")
      true)))

(df test-quarantined-thought-logging [] -> Bool
  :d "Verifies quarantined Chain-of-Thought reasoning log records and ASNL formatting."
  (let [(th (pty/quarantine-thought 1 "Evaluating direct PTY stream bypass without LLM pollution"))
        (fmt (pty/format-thought-entry (pty/make-thought-entry 1 20 "Evaluating direct PTY stream bypass without LLM pollution")))]
    (do
      (assert (= (.-turn-id th) 1) "Thought entry retains interaction turn sequence ID")
      (assert (> (.-tokens th) 0) "Quarantined thought records positive token estimate")
      (assert (string-contains? (.-content th) "PTY stream bypass") "Thought retains reasoning text")
      (assert (string-contains? fmt "(:thought :turn-id 1") "Formatted thought matches canonical ASNL format")
      (assert (string-contains? fmt ":tokens ") "Formatted thought contains token metric field")
      (assert (string-contains? fmt ":content \"Evaluating") "Formatted thought contains escaped content field")
      true)))

(df test-pointer-offload-and-deref [] -> Bool
  :d "Verifies perceptual pointer offload threshold logic and S-expression descriptor roundtrips."
  (let [(ptr (pty/make-pty-pointer "b3-pty-001" "offload" 1200 300 "Terminal session execution log"))
        (tok (pty/format-pty-pointer (pty/make-pty-pointer "b3-pty-001" "offload" 1200 300 "Terminal session execution log")))
        (deref-tok (pty/format-pointer-deref "b3-pty-001" "(def x 10)"))]
    (do
      (assert (pty/should-offload-payload? 600) "Payloads > 500 bytes trigger offload recommendation")
      (assert (not (pty/should-offload-payload? 400)) "Payloads <= 500 bytes remain in context")
      (assert (= (.-id ptr) "b3-pty-001") "Pointer retains content-addressed hash ID")
      (assert (= (.-tokens-saved ptr) 300) "Pointer accurately records saved tokens")
      (assert (string-contains? tok "(:ptr :id \"b3-pty-001\"") "Formatted pointer token contains canonical S-expr tag")
      (assert (string-contains? tok ":action \"offload\"") "Formatted pointer token contains action tag")
      (assert (string-contains? tok ":tokens-saved 300") "Formatted pointer token contains token savings metric")
      (assert (string-contains? deref-tok "(:ptr :action \"deref\"") "Deref format contains action deref")
      (assert (string-contains? deref-tok ":data \"(def x 10)\"") "Deref format retains backing data payload")
      true)))

(df run-tests [] -> Bool
  :d "Executes all PTY stream bypass and context quarantine verification tests."
  (and (test-strip-ansi-colors)
       (and (test-pty-stream-bypass)
            (and (test-sparkline-quantization-bounds)
                 (and (test-sparkline-compression-and-downsampling)
                      (and (test-quarantined-thought-logging)
                           (test-pointer-offload-and-deref)))))))
