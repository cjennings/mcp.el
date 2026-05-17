;;; test-mcp-notify.el --- Tests for mcp-notify -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-notify'.  Thin wrapper around
;; `jsonrpc-connection-send' that omits `:id', producing a notification
;; rather than a request.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; Normal cases

(ert-deftest test-mcp-notify-sends-method-without-id ()
  "Notification carries `:method' but never `:id'."
  (let ((sent-args nil))
    (cl-letf (((symbol-function 'jsonrpc-connection-send)
               (lambda (_conn &rest args) (setq sent-args args))))
      (mcp-notify (mcp-test-make-fake-connection) :notifications/initialized)
      (should (eq :notifications/initialized (plist-get sent-args :method)))
      (should-not (plist-member sent-args :id)))))

(ert-deftest test-mcp-notify-omits-params-when-not-given ()
  "When PARAMS is omitted, `:params' is not present in the call."
  (let ((sent-args nil))
    (cl-letf (((symbol-function 'jsonrpc-connection-send)
               (lambda (_conn &rest args) (setq sent-args args))))
      (mcp-notify (mcp-test-make-fake-connection) :ping)
      (should sent-args)
      (should-not (plist-member sent-args :params)))))

(ert-deftest test-mcp-notify-includes-params-when-given ()
  "When PARAMS is supplied, it lands on the call as `:params'."
  (let ((sent-args nil))
    (cl-letf (((symbol-function 'jsonrpc-connection-send)
               (lambda (_conn &rest args) (setq sent-args args))))
      (mcp-notify (mcp-test-make-fake-connection)
                  :notifications/progress
                  '(:token "abc" :value 50))
      (should (equal '(:token "abc" :value 50)
                     (plist-get sent-args :params))))))

;;; Boundary cases

(ert-deftest test-mcp-notify-accepts-symbol-method ()
  "A non-keyword symbol method passes through to `:method' verbatim.
The downstream `jsonrpc-connection-send' sanitizes the string form."
  (let ((sent-args nil))
    (cl-letf (((symbol-function 'jsonrpc-connection-send)
               (lambda (_conn &rest args) (setq sent-args args))))
      (mcp-notify (mcp-test-make-fake-connection) 'roots/list_changed)
      (should (eq 'roots/list_changed (plist-get sent-args :method))))))

;;; test-mcp-notify.el ends here
