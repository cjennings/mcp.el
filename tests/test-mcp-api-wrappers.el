;;; test-mcp-api-wrappers.el --- Tests for mcp-{call-tool,get-prompt,read-resource} -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for the public sync + async API wrappers in mcp.el:
;;
;; - `mcp-call-tool', `mcp-async-call-tool'
;; - `mcp-get-prompt', `mcp-async-get-prompt'
;; - `mcp-read-resource', `mcp-async-read-resource'
;;
;; Plus the `mcp-(async|sync)-list-(tools|prompts|resources|resource-templates)'
;; wrappers — those are thin call-throughs to `mcp--list-items', so a
;; representative sample is enough; the heavy lifting is in
;; `test-mcp-list-items.el'.
;;
;; Each test stubs `jsonrpc-request' or `jsonrpc-async-request' at the
;; jsonrpc.el boundary and verifies the method, params, and callback
;; plumbing the wrapper produces.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; --- mcp-call-tool / mcp-async-call-tool ---

(ert-deftest test-mcp-call-tool-sends-tools-call-with-name-and-arguments ()
  "Sync call-tool dispatches `:tools/call' with the supplied name and
arguments, and returns whatever jsonrpc-request returns."
  (let (seen-method seen-params)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params)
                 '(:content ((:type "text" :text "ok"))))))
      (let ((result (mcp-call-tool (mcp-test-make-fake-connection)
                                   "echo" '(:text "hello"))))
        (should (eq :tools/call seen-method))
        (should (string= "echo" (plist-get seen-params :name)))
        (should (equal '(:text "hello") (plist-get seen-params :arguments)))
        (should (equal '(:content ((:type "text" :text "ok"))) result))))))

(ert-deftest test-mcp-call-tool-empty-arguments-uses-empty-hash ()
  "When arguments is nil, an empty hash table is sent instead so the
JSON serializer emits `{}' rather than `null'."
  (let (seen-params)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn _m params &rest _)
                 (setq seen-params params) nil)))
      (mcp-call-tool (mcp-test-make-fake-connection) "ping" nil)
      (should (hash-table-p (plist-get seen-params :arguments))))))

(ert-deftest test-mcp-async-call-tool-fires-callback-on-success ()
  "Async call-tool's :success-fn calls the user's CALLBACK with the
response payload."
  (let ((received nil))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn) '(:content "ok")))))
      (mcp-async-call-tool (mcp-test-make-fake-connection)
                           "echo" '(:text "x")
                           (lambda (res) (setq received res))
                           (lambda (_ _) (error "should not error"))))
    (should (equal '(:content "ok") received))))

(ert-deftest test-mcp-async-call-tool-fires-error-callback-on-error ()
  "Async call-tool's :error-fn calls the user's ERROR-CALLBACK with
code and message."
  (let ((received nil))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :error-fn)
                          '(:code 42 :message "nope")))))
      (mcp-async-call-tool (mcp-test-make-fake-connection)
                           "echo" '(:text "x")
                           (lambda (_) (error "should not succeed"))
                           (lambda (c m) (setq received (list c m)))))
    (should (equal '(42 "nope") received))))

;;; --- mcp-get-prompt / mcp-async-get-prompt ---

(ert-deftest test-mcp-get-prompt-sends-prompts-get ()
  "Sync get-prompt dispatches `:prompts/get' with name + arguments."
  (let (seen-method seen-params)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params)
                 '(:messages []))))
      (mcp-get-prompt (mcp-test-make-fake-connection) "summarize" '(:max 100))
      (should (eq :prompts/get seen-method))
      (should (string= "summarize" (plist-get seen-params :name)))
      (should (equal '(:max 100) (plist-get seen-params :arguments))))))

(ert-deftest test-mcp-async-get-prompt-fires-callback ()
  "Async get-prompt fires the user CALLBACK on success."
  (let ((received nil))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn) '(:messages [])))))
      (mcp-async-get-prompt (mcp-test-make-fake-connection) "summarize" nil
                            (lambda (res) (setq received res))
                            (lambda (_ _) nil))
      (should (equal '(:messages []) received)))))

;;; --- mcp-read-resource / mcp-async-read-resource ---

(ert-deftest test-mcp-read-resource-sends-resources-read-with-uri ()
  "Sync read-resource sends `:resources/read' with `:uri'."
  (let (seen-method seen-params)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params)
                 '(:contents []))))
      (mcp-read-resource (mcp-test-make-fake-connection) "file:///x")
      (should (eq :resources/read seen-method))
      (should (string= "file:///x" (plist-get seen-params :uri))))))

(ert-deftest test-mcp-async-read-resource-fires-callback ()
  "Async read-resource fires the user CALLBACK with the result."
  (let ((received nil))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn)
                          '(:contents ((:text "body")))))))
      (mcp-async-read-resource (mcp-test-make-fake-connection) "x://a"
                               (lambda (res) (setq received res))
                               (lambda (_ _) nil))
      (should (equal '(:contents ((:text "body"))) received)))))

;;; --- Representative list-* wrappers ---
;;;
;;; The full pairwise matrix lives in test-mcp-list-items.el; here we
;;; just verify each public wrapper passes the right (method, key,
;;; slot) triple to `mcp--list-items'.

(ert-deftest test-mcp-async-list-tools-dispatches-tools-list ()
  (let (seen-method)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method &rest _) (setq seen-method method) nil)))
      (mcp-async-list-tools (mcp-test-make-fake-connection))
      (should (eq :tools/list seen-method)))))

(ert-deftest test-mcp-async-list-prompts-dispatches-prompts-list ()
  (let (seen-method)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method &rest _) (setq seen-method method) nil)))
      (mcp-async-list-prompts (mcp-test-make-fake-connection))
      (should (eq :prompts/list seen-method)))))

(ert-deftest test-mcp-async-list-resources-dispatches-resources-list ()
  (let (seen-method)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method &rest _) (setq seen-method method) nil)))
      (mcp-async-list-resources (mcp-test-make-fake-connection))
      (should (eq :resources/list seen-method)))))

(ert-deftest test-mcp-async-list-resource-templates-dispatches-templates-list ()
  (let (seen-method)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method &rest _) (setq seen-method method) nil)))
      (mcp-async-list-resource-templates (mcp-test-make-fake-connection))
      (should (eq :resources/templates/list seen-method)))))

(ert-deftest test-mcp-sync-list-tools-routes-through-mcp--list-items-sync ()
  "Sync wrapper calls jsonrpc-request (not jsonrpc-async-request)."
  (let (sync-called)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn _m _p &rest _) (setq sync-called t)
                 '(:tools ((:name "t1")))))
              ((symbol-function 'jsonrpc-async-request)
               (lambda (&rest _) (error "should not call async"))))
      (mcp-sync-list-tools (mcp-test-make-fake-connection))
      (should sync-called))))

;;; test-mcp-api-wrappers.el ends here
