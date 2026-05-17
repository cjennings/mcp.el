;;; test-mcp-smoke.el --- Smoke test for the test pipeline -*- lexical-binding: t; -*-

;;; Commentary:
;; Single trivial test that exists to verify the test harness loads mcp.el
;; and mcp-hub.el via test-bootstrap.el.  Real coverage starts in the
;; per-topic test files alongside this one.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(ert-deftest test-mcp-smoke-mcp-loaded ()
  "mcp.el is loaded — the `mcp-server-connections' hash table is bound."
  (should (hash-table-p mcp-server-connections)))

(ert-deftest test-mcp-smoke-mcp-hub-loaded ()
  "mcp-hub.el is loaded — `mcp-hub-servers' is bound (default nil)."
  (should (boundp 'mcp-hub-servers)))

;;; test-mcp-smoke.el ends here
