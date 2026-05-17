;;; test-mcp-make-text-tool.el --- Tests for mcp-make-text-tool -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-make-text-tool'.  The function reads a tool
;; definition from a connection stored in `mcp-server-connections' and
;; returns a plist describing a tool that wraps it — name, description,
;; async flag, args, and a generated :function closure.
;;
;; These tests verify the SHAPE of the result and the lookup paths
;; (server-not-connected, tool-not-found).  Exercising the inner closure
;; would call into the JSON-RPC transport and belongs in Tier 3.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

(defun mcp-test--make-tools-list ()
  "Return a tool-list shape mcp-make-text-tool expects in `mcp--tools'."
  (list
   (list :name "echo"
         :description "Echo back the input."
         :inputSchema
         (list :properties '(:text (:type "string" :description "Text to echo"))
               :required '("text")))
   (list :name "shout"
         :description "Echo, but loudly."
         :inputSchema
         (list :properties '(:text (:type "string")
                             :level (:type "string" :default "loud"))
               :required '("text")))))

;;; Normal cases

(ert-deftest test-mcp-make-text-tool-returns-plist-with-tool-name ()
  "Looked-up tool surfaces as the `:name' on the returned plist."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (let ((result (mcp-make-text-tool "demo" "echo")))
        (should result)
        (should (string= "echo" (plist-get result :name)))))))

(ert-deftest test-mcp-make-text-tool-passes-description-through ()
  "Tool description is copied into the returned plist."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (should (string= "Echo back the input."
                       (plist-get (mcp-make-text-tool "demo" "echo")
                                  :description))))))

(ert-deftest test-mcp-make-text-tool-args-parsed-from-input-schema ()
  "The :args field is built from the schema via `mcp--parse-tool-args'."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (let* ((result (mcp-make-text-tool "demo" "shout"))
             (args (plist-get result :args)))
        (should (= 2 (length args)))
        ;; First arg (text) is required: no :optional.
        (should (string= "text" (plist-get (nth 0 args) :name)))
        (should-not (plist-member (nth 0 args) :optional))
        ;; Second arg (level) is optional and carries through :default.
        (should (string= "level" (plist-get (nth 1 args) :name)))
        (should (eq t (plist-get (nth 1 args) :optional)))
        (should (string= "loud" (plist-get (nth 1 args) :default)))))))

(ert-deftest test-mcp-make-text-tool-async-flag-defaults-to-nil ()
  "Without ASYNCP, :async is nil and :function is a non-async closure."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (let ((result (mcp-make-text-tool "demo" "echo")))
        (should-not (plist-get result :async))
        (should (functionp (plist-get result :function)))))))

(ert-deftest test-mcp-make-text-tool-async-flag-set-when-asyncp ()
  "With ASYNCP non-nil, :async is t."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (let ((result (mcp-make-text-tool "demo" "echo" t)))
        (should (eq t (plist-get result :async)))
        (should (functionp (plist-get result :function)))))))

;;; Error / edge cases

(ert-deftest test-mcp-make-text-tool-no-connection-returns-nil ()
  "Server name absent from `mcp-server-connections' -> nil."
  (mcp-test-with-clean-connections
    (should-not (mcp-make-text-tool "nope" "echo"))))

(ert-deftest test-mcp-make-text-tool-tool-not-found-returns-nil ()
  "Connection exists but the named tool isn't in `mcp--tools' -> nil."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection
                 :tools (mcp-test--make-tools-list))))
      (puthash "demo" conn mcp-server-connections)
      (should-not (mcp-make-text-tool "demo" "never-existed")))))

;;; test-mcp-make-text-tool.el ends here
