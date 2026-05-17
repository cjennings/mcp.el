;;; test-mcp-server-running-p.el --- Tests for mcp--server-running-p -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--server-running-p'.  Reads
;; `mcp-server-connections' and returns non-nil unless the looked-up
;; connection's `mcp--status' is `stop' or `error'.  Returns nil for
;; unknown server names.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; Normal cases

(ert-deftest test-mcp-server-running-p-status-connected ()
  "A connection with status `connected' is running."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection :status 'connected)
             mcp-server-connections)
    (should (mcp--server-running-p "demo"))))

(ert-deftest test-mcp-server-running-p-status-stop ()
  "A connection with status `stop' is not running."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection :status 'stop)
             mcp-server-connections)
    (should-not (mcp--server-running-p "demo"))))

(ert-deftest test-mcp-server-running-p-status-error ()
  "A connection with status `error' is not running."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection :status 'error)
             mcp-server-connections)
    (should-not (mcp--server-running-p "demo"))))

;;; Boundary cases

(ert-deftest test-mcp-server-running-p-status-init ()
  "A connection in its initial `init' state is treated as running —
the predicate only excludes the terminal `stop' and `error' states."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection :status 'init)
             mcp-server-connections)
    (should (mcp--server-running-p "demo"))))

;;; Error / edge cases

(ert-deftest test-mcp-server-running-p-unknown-name-returns-nil ()
  "Unknown server name -> `gethash' yields nil -> when-let short-circuits."
  (mcp-test-with-clean-connections
    (should-not (mcp--server-running-p "no-such-server"))))

;;; test-mcp-server-running-p.el ends here
