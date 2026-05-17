;;; test-mcp-initialize.el --- Tests for mcp--initialize-message -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--initialize-message' and its async/sync
;; wrappers.  The helper sends an `initialize' request, then on success
;; destructures (protocolVersion, serverInfo, capabilities) out of the
;; response and forwards them to the caller's CALLBACK.  ERROR-CALLBACK
;; (when provided) receives (code, message) instead.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

(defvar mcp-test--init-response
  '(:protocolVersion "2024-11-05"
    :serverInfo (:name "demo-server" :version "1.0")
    :capabilities (:tools t :resources t))
  "Canned response returned by the stubbed transport.")

;;; Normal cases

(ert-deftest test-mcp-async-initialize-sends-initialize-with-client-info ()
  "Async initialize dispatches `:initialize' with a `:clientInfo' plist."
  (let (seen-method seen-params)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params)
                 nil)))
      (mcp-async-initialize-message (mcp-test-make-fake-connection)
                                    nil (lambda (&rest _) nil))
      (should (eq :initialize seen-method))
      (should (plist-member seen-params :clientInfo))
      (should (string= "mcp-emacs"
                       (plist-get (plist-get seen-params :clientInfo) :name))))))

(ert-deftest test-mcp-async-initialize-destructures-response-into-callback ()
  "On success, callback receives (protocolVersion, serverInfo, capabilities)."
  (let (received)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn)
                          mcp-test--init-response))))
      (mcp-async-initialize-message
       (mcp-test-make-fake-connection)
       nil
       (lambda (pv si caps) (setq received (list pv si caps))))
      (should (string= "2024-11-05" (nth 0 received)))
      (should (equal '(:name "demo-server" :version "1.0") (nth 1 received)))
      (should (equal '(:tools t :resources t) (nth 2 received))))))

(ert-deftest test-mcp-sync-initialize-uses-sync-transport ()
  "Sync initialize calls jsonrpc-request, not jsonrpc-async-request."
  (let (sync-called)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn _m _p &rest _)
                 (setq sync-called t)
                 mcp-test--init-response))
              ((symbol-function 'jsonrpc-async-request)
               (lambda (&rest _) (error "should not call async"))))
      (mcp-sync-initialize-message (mcp-test-make-fake-connection)
                                   nil (lambda (&rest _) nil))
      (should sync-called))))

;;; Boundary cases

(ert-deftest test-mcp-async-initialize-passes-timeout-from-server-start-time ()
  "The :timeout kwarg sent to jsonrpc-async-request equals
`mcp-server-start-time' — initialization gets a generous window."
  (let (seen-timeout)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (setq seen-timeout (plist-get kwargs :timeout))
                 nil)))
      (mcp-async-initialize-message (mcp-test-make-fake-connection)
                                    nil (lambda (&rest _) nil))
      (should (eq seen-timeout mcp-server-start-time)))))

;;; Error / edge cases

(ert-deftest test-mcp-async-initialize-error-fires-error-callback ()
  "When the transport reports an error and ERROR-CALLBACK is provided,
the error callback receives (code, message)."
  (let (received)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :error-fn)
                          '(:code 401 :message "unauthorized")))))
      (mcp-async-initialize-message
       (mcp-test-make-fake-connection)
       nil
       (lambda (&rest _) (error "should not succeed"))
       (lambda (c m) (setq received (list c m))))
      (should (equal '(401 "unauthorized") received)))))

(ert-deftest test-mcp-async-initialize-timeout-fires-error-callback ()
  "When the timeout-fn fires and ERROR-CALLBACK is provided,
the user gets (124, \"timeout\") — the canonical timeout signaling."
  (let (received)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :timeout-fn)))))
      (mcp-async-initialize-message
       (mcp-test-make-fake-connection)
       nil
       (lambda (&rest _) (error "should not succeed"))
       (lambda (c m) (setq received (list c m))))
      (should (equal '(124 "timeout") received)))))

;;; test-mcp-initialize.el ends here
