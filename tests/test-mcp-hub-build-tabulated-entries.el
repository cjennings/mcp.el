;;; test-mcp-hub-build-tabulated-entries.el --- Tests for mcp-hub--build-tabulated-entries -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub--build-tabulated-entries' — the pure helper
;; extracted from `mcp-hub-update'.  Takes the per-server status plists
;; from `mcp-hub-get-servers' and returns a list of `(ID VECTOR)' rows
;; suitable for `tabulated-list-entries'.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(defun mcp-test--server-plist (&rest overrides)
  "Return a fresh server-status plist for testing.
Defaults match the `stop' state; OVERRIDES are merged on top.

Builds a new list via `list' (not a quoted literal) so subsequent
`plist-put' calls don't mutate shared state between tests."
  (let ((base (list :name "demo" :status 'stop)))
    (cl-loop for (k v) on overrides by #'cddr
             do (setq base (plist-put base k v)))
    base))

;;; Normal cases

(ert-deftest test-mcp-hub-build-tabulated-entries-empty-input ()
  "Empty server list yields an empty entries list."
  (should (null (mcp-hub--build-tabulated-entries '()))))

(ert-deftest test-mcp-hub-build-tabulated-entries-stopped-server-counts-nil ()
  "A stopped server's count columns are the literal string \"nil\"."
  (let* ((entries (mcp-hub--build-tabulated-entries
                   (list (mcp-test--server-plist))))
         (row (cadr (car entries))))
    (should (string= "demo" (aref row 0)))
    (should (string= "nil" (aref row 1))) ;; type
    (should (string= "stop" (aref row 2))) ;; status
    (should (string= "nil" (aref row 3))) ;; tools
    (should (string= "nil" (aref row 4))) ;; resources
    (should (string= "nil" (aref row 5))) ;; templates
    (should (string= "nil" (aref row 6))))) ;; prompts

(ert-deftest test-mcp-hub-build-tabulated-entries-connected-server-counts-numeric ()
  "A connected server's count columns format the lengths of each slot."
  (let* ((server (mcp-test--server-plist
                  :status 'connected
                  :type 'stdio
                  :tools [(:n "a") (:n "b") (:n "c")]
                  :resources [(:u "r1")]
                  :template-resources []
                  :prompts [(:n "p1") (:n "p2")]))
         (row (cadr (car (mcp-hub--build-tabulated-entries (list server))))))
    (should (string= "stdio" (aref row 1)))
    (should (string= "3" (aref row 3)))
    (should (string= "1" (aref row 4)))
    (should (string= "0" (aref row 5)))
    (should (string= "2" (aref row 6)))))

;;; Boundary cases

(ert-deftest test-mcp-hub-build-tabulated-entries-status-connected-face ()
  "`connected' status is propertized with the `success' face."
  (let* ((server (mcp-test--server-plist
                  :status 'connected :type 'http
                  :tools [] :resources [] :template-resources [] :prompts []))
         (row (cadr (car (mcp-hub--build-tabulated-entries (list server)))))
         (status-cell (aref row 2)))
    (should (eq 'success (get-text-property 0 'face status-cell)))))

(ert-deftest test-mcp-hub-build-tabulated-entries-status-error-face ()
  "`error' status is propertized with the `error' face."
  (let* ((server (mcp-test--server-plist :status 'error))
         (row (cadr (car (mcp-hub--build-tabulated-entries (list server)))))
         (status-cell (aref row 2)))
    (should (eq 'error (get-text-property 0 'face status-cell)))))

(ert-deftest test-mcp-hub-build-tabulated-entries-id-is-1-based ()
  "Row IDs are stringified 1-based indices."
  (let ((entries (mcp-hub--build-tabulated-entries
                  (list (mcp-test--server-plist :name "one")
                        (mcp-test--server-plist :name "two")
                        (mcp-test--server-plist :name "three")))))
    (should (equal '("1" "2" "3")
                   (mapcar #'car entries)))))

;;; test-mcp-hub-build-tabulated-entries.el ends here
