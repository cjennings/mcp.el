;;; test-mcp-log-and-ping.el --- Tests for mcp--set-log-level and mcp-async-ping -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--set-log-level' (and its async/sync wrappers)
;; plus `mcp-async-ping'.  Both speak the same JSON-RPC pattern as the
;; list-items helper — stub jsonrpc.el at the boundary and check the
;; outgoing method, params, and callback plumbing.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; --- mcp--set-log-level ---

(ert-deftest test-mcp-async-set-log-level-sends-logging-setlevel ()
  "Async set-log-level dispatches `:logging/setLevel' over async transport."
  (let (seen-method seen-params seen-kind)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params seen-kind 'async)
                 nil))
              ((symbol-function 'jsonrpc-request)
               (lambda (&rest _) (error "should not call sync"))))
      (mcp-async-set-log-level (mcp-test-make-fake-connection) 'debug)
      (should (eq :logging/setLevel seen-method))
      (should (eq 'async seen-kind))
      ;; `:level' is formatted from the symbol via %s.
      (should (string= "debug" (plist-get seen-params :level))))))

(ert-deftest test-mcp-sync-set-log-level-uses-sync-transport ()
  "Sync set-log-level dispatches over sync transport (jsonrpc-request)."
  (let (seen-kind)
    (cl-letf (((symbol-function 'jsonrpc-request)
               (lambda (_conn _m _p &rest _) (setq seen-kind 'sync) t))
              ((symbol-function 'jsonrpc-async-request)
               (lambda (&rest _) (error "should not call async"))))
      (mcp-sync-set-log-level (mcp-test-make-fake-connection) 'warning)
      (should (eq 'sync seen-kind)))))

(ert-deftest test-mcp-set-log-level-async-success-logs-message ()
  "Success path messages \"[mcp] setLevel success: …\"."
  (let (captured)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn) '(:ok t))))
              ((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq captured (apply #'format fmt args)))))
      (mcp-async-set-log-level (mcp-test-make-fake-connection) 'info)
      (should (string-match-p "setLevel success" captured)))))

(ert-deftest test-mcp-set-log-level-async-error-logs-server-error ()
  "Error path messages the server's code and message."
  (let (captured)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :error-fn)
                          '(:code 7 :message "denied"))))
              ((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq captured (apply #'format fmt args)))))
      (mcp-async-set-log-level (mcp-test-make-fake-connection) 'info)
      (should (string-match-p "denied" captured))
      (should (string-match-p "7" captured)))))

(ert-deftest test-mcp-set-log-level-level-symbol-formatted-as-string ()
  "The level is sent as a string regardless of the symbol passed in."
  (let (seen-level)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m params &rest _)
                 (setq seen-level (plist-get params :level)) nil)))
      (mcp-async-set-log-level (mcp-test-make-fake-connection) 'emergency)
      (should (stringp seen-level))
      (should (string= "emergency" seen-level)))))

;;; --- mcp-async-ping ---

(ert-deftest test-mcp-async-ping-sends-ping-method ()
  "mcp-async-ping dispatches `:ping' with nil params."
  (let (seen-method seen-params)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn method params &rest _)
                 (setq seen-method method seen-params params) nil)))
      (mcp-async-ping (mcp-test-make-fake-connection))
      (should (eq :ping seen-method))
      (should-not seen-params))))

(ert-deftest test-mcp-async-ping-success-logs ()
  "Successful ping logs \"[mcp] ping success: …\"."
  (let (captured)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn) '(:pong t))))
              ((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq captured (apply #'format fmt args)))))
      (mcp-async-ping (mcp-test-make-fake-connection))
      (should (string-match-p "ping success" captured)))))

(ert-deftest test-mcp-async-ping-passes-timeout-from-connection ()
  "The :timeout kwarg sent to jsonrpc-async-request comes from the
connection's `mcp--timeout' slot."
  (let (seen-timeout)
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (setq seen-timeout (plist-get kwargs :timeout))
                 nil)))
      (mcp-async-ping (mcp-test-make-fake-connection :timeout 42))
      (should (eq 42 seen-timeout)))))

;;; test-mcp-log-and-ping.el ends here
