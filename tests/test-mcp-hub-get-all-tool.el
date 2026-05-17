;;; test-mcp-hub-get-all-tool.el --- Tests for mcp-hub-get-all-tool -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub-get-all-tool'.  Walks `mcp-server-connections',
;; pulls tools off every connected server, and returns a flat list of
;; text-tool plists (one per `(server, tool-name)' pair).

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

(defun mcp-test--hub-tools-list (&rest names)
  "Return a tool-list shape suitable for the `mcp--tools' slot.
NAMES are the tool name strings to include."
  (mapcar (lambda (n)
            (list :name n
                  :description (format "tool %s" n)
                  :inputSchema (list :properties '(:x (:type "string"))
                                     :required '("x"))))
          names))

;;; Normal cases

(ert-deftest test-mcp-hub-get-all-tool-no-connections-empty ()
  "Empty `mcp-server-connections' yields an empty list."
  (mcp-test-with-clean-connections
    (should (null (mcp-hub-get-all-tool)))))

(ert-deftest test-mcp-hub-get-all-tool-one-server-flat-list ()
  "A single connected server contributes one entry per tool."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :status 'connected
                     :tools (mcp-test--hub-tools-list "a" "b" "c"))
             mcp-server-connections)
    (let ((all (mcp-hub-get-all-tool)))
      (should (= 3 (length all)))
      (should (member "a" (mapcar (lambda (t-) (plist-get t- :name)) all)))
      (should (member "b" (mapcar (lambda (t-) (plist-get t- :name)) all)))
      (should (member "c" (mapcar (lambda (t-) (plist-get t- :name)) all))))))

(ert-deftest test-mcp-hub-get-all-tool-multiple-servers-combined ()
  "Two connected servers combine their tool lists."
  (mcp-test-with-clean-connections
    (puthash "alpha" (mcp-test-make-fake-connection
                      :status 'connected
                      :tools (mcp-test--hub-tools-list "x"))
             mcp-server-connections)
    (puthash "beta"  (mcp-test-make-fake-connection
                      :status 'connected
                      :tools (mcp-test--hub-tools-list "y" "z"))
             mcp-server-connections)
    (should (= 3 (length (mcp-hub-get-all-tool))))))

;;; Boundary cases

(ert-deftest test-mcp-hub-get-all-tool-non-connected-server-skipped ()
  "A server present in the hash but with status != `connected' is skipped."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :status 'stop
                     :tools (mcp-test--hub-tools-list "a"))
             mcp-server-connections)
    (should (null (mcp-hub-get-all-tool)))))

(ert-deftest test-mcp-hub-get-all-tool-server-without-tools-skipped ()
  "A connected server whose `mcp--tools' is nil contributes nothing."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :status 'connected
                     :tools nil)
             mcp-server-connections)
    (should (null (mcp-hub-get-all-tool)))))

(ert-deftest test-mcp-hub-get-all-tool-categoryp-sets-category ()
  "With `:categoryp t', every returned tool carries `:category mcp-NAME'."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :status 'connected
                     :tools (mcp-test--hub-tools-list "a"))
             mcp-server-connections)
    (let ((tool (car (mcp-hub-get-all-tool :categoryp t))))
      (should (string= "mcp-demo" (plist-get tool :category))))))

;;; test-mcp-hub-get-all-tool.el ends here
