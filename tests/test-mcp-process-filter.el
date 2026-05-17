;;; test-mcp-process-filter.el --- Tests for mcp--process-filter -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--process-filter'.  The filter handles three
;; flavors of inbound data — stdio (newline-delimited JSON), HTTP
;; non-SSE (chunked sized blocks), and SSE (Server-Sent Events with
;; \r\n\r\n separators) — and reassembles partial messages across
;; chunks.
;;
;; These tests cover the stdio paths plus the recursive-call guard;
;; full SSE chunk reassembly is out of scope and would need traffic
;; fixtures captured from a real MCP server.  See the proposal in
;; .ai/sessions/ for the deferred integration-test sketch.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; Normal cases — stdio

(ert-deftest test-mcp-process-filter-stdio-single-message-dispatches ()
  "A complete newline-terminated JSON line is parsed and dispatched."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (mcp--process-filter
     proc
     "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"tools\":[]}}\n")
    (should (= 1 (length received)))
    (let ((msg (car received)))
      (should (string= "2.0" (plist-get msg :jsonrpc)))
      (should (eq 1 (plist-get msg :id)))
      (should (plist-member msg :result)))))

(ert-deftest test-mcp-process-filter-stdio-multiple-messages-in-one-chunk ()
  "Two newline-delimited messages arriving in one chunk dispatch twice."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (mcp--process-filter
     proc
     (concat "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":1}\n"
             "{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":2}\n"))
    (should (= 2 (length received)))
    ;; received is most-recent-first (push order)
    (should (eq 2 (plist-get (nth 0 received) :id)))
    (should (eq 1 (plist-get (nth 1 received) :id)))))

(ert-deftest test-mcp-process-filter-stdio-each-msg-carries-raw-json ()
  "Each dispatched plist carries the raw JSON text under `:jsonrpc-json'."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (let ((raw "{\"jsonrpc\":\"2.0\",\"id\":7,\"result\":\"x\"}"))
      (mcp--process-filter proc (concat raw "\n"))
      (should (string-match-p "\"id\":7" (plist-get (car received) :jsonrpc-json))))))

;;; Boundary cases — partial-message reassembly

(ert-deftest test-mcp-process-filter-stdio-partial-message-buffered ()
  "An incomplete JSON line (no closing brace yet) is buffered into
`jsonrpc-pending' and not dispatched."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (mcp--process-filter proc "{\"jsonrpc\":\"2.0\",\"id\":1,")
    (should (null received))
    (let ((pending (process-get proc 'jsonrpc-pending)))
      (should (buffer-live-p pending))
      (with-current-buffer pending
        (should (string-match-p "\"id\":1" (buffer-string)))))))

(ert-deftest test-mcp-process-filter-stdio-completes-buffered-partial ()
  "Sending the rest of the partial line completes the message and
dispatches it on the second call."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (mcp--process-filter proc "{\"jsonrpc\":\"2.0\",\"id\":1,")
    (should (null received))
    (mcp--process-filter proc "\"result\":42}\n")
    (should (= 1 (length received)))
    (should (eq 42 (plist-get (car received) :result)))))

;;; Error / edge cases

(ert-deftest test-mcp-process-filter-stdio-empty-string-is-noop ()
  "Empty input neither dispatches nor crashes."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (mcp--process-filter proc "")
    (should (null received))))

(ert-deftest test-mcp-process-filter-stdio-malformed-json-does-not-crash ()
  "Genuinely malformed JSON (`json-parse-error') is warned about and
discarded; no dispatch."
  (mcp-test-with-process-filter-fixture (proc conn received)
    ;; `jsonrpc--warn' falls through to `message'.  Silence it.
    (cl-letf (((symbol-function 'jsonrpc--warn) #'ignore))
      (mcp--process-filter proc "{not valid json}\n"))
    (should (null received))))

;;; Recursive-call guard

(ert-deftest test-mcp-process-filter-recursive-call-reschedules ()
  "When `mcp--in-process-filter' is bound non-nil, the filter
re-schedules itself via `run-at-time' instead of recursing."
  (mcp-test-with-process-filter-fixture (proc conn received)
    (let ((scheduled nil))
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (when _repeat fn &rest args)
                   (setq scheduled (list when fn args)))))
        (let ((mcp--in-process-filter t))
          (mcp--process-filter proc "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":1}\n"))
        (should scheduled)
        (should (eq 0 (nth 0 scheduled)))
        (should (eq #'mcp--process-filter (nth 1 scheduled))))
      ;; Recursion-guard path takes precedence — nothing dispatched on this call.
      (should (null received)))))

;;; test-mcp-process-filter.el ends here
