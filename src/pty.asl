(module asl-agent/pty
  :d "Zero-LLM direct PTY stream bypass, ANSI filtering, Unicode sparkline telemetry, and context quarantine."
  :x [PtyResult
      AnsiState
      ThoughtEntry
      PtyPointer
      make-pty-result
      format-pty-result
      is-ansi-terminator?
      strip-ansi-escapes
      pty-stream-bypass
      sparkline-glyph
      quantize-sparkline-point
      average-list
      downsample-helper
      downsample-metrics
      render-sparkline
      compress-metrics-sparkline
      make-thought-entry
      format-thought-entry
      quarantine-thought
      make-pty-pointer
      format-pty-pointer
      should-offload-payload?
      estimate-token-savings
      format-pointer-deref]
  :i [])

(dfs PtyResult
  (:f exit-code I64 "Process execution exit status code")
  (:f duration-ms I64 "Wall clock elapsed time in milliseconds")
  (:f bytes-streamed I64 "Total bytes streamed to terminal presentation")
  (:f summary Str "Compact execution summary for model attention"))

(dfs AnsiState
  (:f in-esc I64 "Escape parser state: 0 normal, 1 saw ESC, 2 in CSI")
  (:f acc Str "Accumulator for stripped output"))

(dfs ThoughtEntry
  (:f turn-id I64 "Interaction turn sequence identifier")
  (:f tokens I64 "Token footprint count of reasoning step")
  (:f content Str "Quarantined intermediate reasoning content"))

(dfs PtyPointer
  (:f id Str "Content-addressed hash identifier")
  (:f action Str "Pointer action descriptor (offload or deref)")
  (:f bytes I64 "Payload size in bytes")
  (:f tokens-saved I64 "Estimated token savings")
  (:f summary Str "Semantic summary of offloaded payload"))

(df make-pty-result [(exit-code I64) (duration-ms I64) (bytes-streamed I64) (summary Str)] -> PtyResult
  :d "Constructs a structured PTY execution result."
  (PtyResult
    :exit-code exit-code
    :duration-ms duration-ms
    :bytes-streamed bytes-streamed
    :summary summary))

(df format-pty-result [(res PtyResult)] -> Str
  :d "Formats a PtyResult record into a canonical S-expression."
  (str "(:pty-result :exit-code " (string-from-int64 (.-exit-code res))
       " :duration-ms " (string-from-int64 (.-duration-ms res))
       " :bytes-streamed " (string-from-int64 (.-bytes-streamed res))
       " :summary \"" (.-summary res) "\")"))

(df is-ansi-terminator? [(c Str)] -> Bool
  :d "Tests if character terminates an ANSI CSI escape sequence."
  (string-contains? "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz@~" c))

(df strip-ansi-escapes [(raw Str)] -> Str
  :d "Strips ANSI terminal escape sequences from raw PTY stream."
  (let [(chars (string-chars raw))
        (final-st (fold (fn [(st AnsiState) (c Str)] -> AnsiState
                          (let [(mode (.-in-esc st))
                                (acc (.-acc st))]
                            (if (= mode 0)
                              (if (= c "\u001b")
                                (AnsiState :in-esc 1 :acc acc)
                                (AnsiState :in-esc 0 :acc (str acc c)))
                              (if (= mode 1)
                                (if (= c "[")
                                  (AnsiState :in-esc 2 :acc acc)
                                  (AnsiState :in-esc 0 :acc acc))
                                (if (= mode 2)
                                  (if (is-ansi-terminator? c)
                                    (AnsiState :in-esc 0 :acc acc)
                                    (AnsiState :in-esc 2 :acc acc))
                                  (AnsiState :in-esc 0 :acc acc))))))
                        (AnsiState :in-esc 0 :acc "")
                        chars))]
    (.-acc final-st)))

(df pty-stream-bypass [(raw-terminal-stream Str) (exit-code I64) (duration-ms I64)] -> PtyResult
  :d "Direct PTY stream bypass emitting structured metadata without LLM context pollution."
  (let [(clean (strip-ansi-escapes raw-terminal-stream))
        (bytes (string-length raw-terminal-stream))
        (summary (if (= exit-code 0)
                   "PTY stream completed cleanly"
                   (str "PTY stream failed with exit code " (string-from-int64 exit-code))))]
    (PtyResult
      :exit-code exit-code
      :duration-ms duration-ms
      :bytes-streamed bytes
      :summary summary)))

(df sparkline-glyph [(level I64)] -> Str
  :d "Maps a quantized level 0-7 to its corresponding Unicode sparkline block glyph."
  (if (<= level 0) " "
    (if (= level 1) "▂"
      (if (= level 2) "▃"
        (if (= level 3) "▄"
          (if (= level 4) "▅"
            (if (= level 5) "▆"
              (if (= level 6) "▇"
                "█"))))))))

(df quantize-sparkline-point [(val I64)] -> Str
  :d "Quantizes a metric percentage (0-100) to an 8-level Unicode sparkline character."
  (if (<= val 0) " "
    (if (>= val 100) "█"
      (let [(level (/ (* val 8) 100))
            (clamped (if (> level 7) 7 level))]
        (sparkline-glyph clamped)))))

(df average-list [(xs (List I64))] -> I64
  :d "Computes the arithmetic mean of a list of integers."
  (let [(len (list-length xs))]
    (if (<= len 0) 0
      (/ (list-sum xs) len))))

(df downsample-helper [(metrics (List I64)) (bucket-size I64) (remaining I64) (offset I64)] -> (List I64)
  :d "Recursive helper for metric window downsampling."
  (if (<= remaining 0) (list)
    (let [(chunk (mt (list-slice metrics offset (+ offset bucket-size))
                   ((some xs) xs)
                   ((none) (list))))
          (avg (average-list chunk))
          (rest (downsample-helper metrics bucket-size (- remaining 1) (+ offset bucket-size)))]
      (list-cons avg rest))))

(df downsample-metrics [(metrics (List I64)) (target-points I64)] -> (List I64)
  :d "Downsamples a stream of metrics into a target number of averaged buckets."
  (let [(total (list-length metrics))]
    (if (or (<= total target-points) (<= target-points 0))
      metrics
      (let [(b-size (/ total target-points))]
        (if (<= b-size 0)
          metrics
          (downsample-helper metrics b-size target-points 0))))))

(df render-sparkline [(metrics (List I64))] -> Str
  :d "Renders a list of integer metrics into a contiguous Unicode sparkline string."
  (fold (fn [(acc Str) (m I64)] -> Str
          (str acc (quantize-sparkline-point m)))
        ""
        metrics))

(df compress-metrics-sparkline [(metrics (List I64)) (target-points I64)] -> Str
  :d "Compresses a metric series into a fixed-width Unicode sparkline."
  (render-sparkline (downsample-metrics metrics target-points)))

(df make-thought-entry [(turn-id I64) (tokens I64) (content Str)] -> ThoughtEntry
  :d "Constructs a quarantined thought record."
  (ThoughtEntry
    :turn-id turn-id
    :tokens tokens
    :content content))

(df format-thought-entry [(entry ThoughtEntry)] -> Str
  :d "Formats a ThoughtEntry as an append-only ASNL log line."
  (str "(:thought :turn-id " (string-from-int64 (.-turn-id entry))
       " :tokens " (string-from-int64 (.-tokens entry))
       " :content \"" (.-content entry) "\")"))

(df quarantine-thought [(turn-id I64) (content Str)] -> ThoughtEntry
  :d "Constructs and quarantines an intermediate Chain-of-Thought reasoning step."
  (let [(raw-toks (/ (string-length content) 4))
        (toks (if (< raw-toks 1) 1 raw-toks))]
    (ThoughtEntry
      :turn-id turn-id
      :tokens toks
      :content content)))

(df make-pty-pointer [(id Str) (action Str) (bytes I64) (tokens-saved I64) (summary Str)] -> PtyPointer
  :d "Constructs a perceptual pointer descriptor record."
  (PtyPointer
    :id id
    :action action
    :bytes bytes
    :tokens-saved tokens-saved
    :summary summary))

(df format-pty-pointer [(ptr PtyPointer)] -> Str
  :d "Formats a PtyPointer into a canonical S-expression descriptor token."
  (str "(:ptr :id \"" (.-id ptr)
       "\" :action \"" (.-action ptr)
       "\" :bytes " (string-from-int64 (.-bytes ptr))
       " :tokens-saved " (string-from-int64 (.-tokens-saved ptr))
       " :summary \"" (.-summary ptr) "\")"))

(df should-offload-payload? [(bytes I64)] -> Bool
  :d "Determines if payload byte length exceeds the 500-byte offloading threshold."
  (> bytes 500))

(df estimate-token-savings [(bytes I64)] -> I64
  :d "Calculates estimated token savings for offloaded payload."
  (let [(toks (/ bytes 4))]
    (if (< toks 1) 1 toks)))

(df format-pointer-deref [(id Str) (data Str)] -> Str
  :d "Formats a dereferenced perceptual pointer result."
  (str "(:ptr :action \"deref\" :id \"" id "\" :bytes " (string-from-int64 (string-length data)) " :data \"" data "\")"))
