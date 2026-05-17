;;; test-mcp-dispatchers.el --- Tests for mcp-request- and mcp-notification-dispatcher -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-request-dispatcher' and
;; `mcp-notification-dispatcher'.  The request dispatcher handles
;; `roots/list' against a stored connection's roots; the notification
;; dispatcher logs `notifications/message' events.  Unknown methods on
;; either side log via `message' without erroring.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; --- mcp-request-dispatcher: roots/list ---

(ert-deftest test-mcp-request-dispatcher-roots-list-string-roots ()
  "String roots are normalized to plists with :uri (file://) and :name."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :roots '("/tmp/project1" "/tmp/project2"))
             mcp-server-connections)
    (let* ((result (mcp-request-dispatcher "demo" 'roots/list nil))
           (roots (plist-get result :roots)))
      (should (vectorp roots))
      (should (= 2 (length roots)))
      ;; Each root becomes (:uri "file://<expanded>" :name "<basename>")
      (should (string-prefix-p "file://" (plist-get (aref roots 0) :uri)))
      (should (string-suffix-p "/tmp/project1" (plist-get (aref roots 0) :uri)))
      (should (string= "project1" (plist-get (aref roots 0) :name))))))

(ert-deftest test-mcp-request-dispatcher-roots-list-plist-roots ()
  "Plist roots pass through unchanged."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :roots '((:uri "file:///custom" :name "Custom")))
             mcp-server-connections)
    (let* ((result (mcp-request-dispatcher "demo" 'roots/list nil))
           (roots (plist-get result :roots)))
      (should (vectorp roots))
      (should (= 1 (length roots)))
      (should (equal '(:uri "file:///custom" :name "Custom")
                     (aref roots 0))))))

(ert-deftest test-mcp-request-dispatcher-roots-list-no-connection ()
  "Unknown server -> :roots is an empty vector."
  (mcp-test-with-clean-connections
    (let ((result (mcp-request-dispatcher "nope" 'roots/list nil)))
      (should (equal [] (plist-get result :roots))))))

(ert-deftest test-mcp-request-dispatcher-roots-list-empty-roots ()
  "Connection with no roots set -> :roots is an empty vector."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection :roots nil)
             mcp-server-connections)
    (let ((result (mcp-request-dispatcher "demo" 'roots/list nil)))
      (should (equal [] (plist-get result :roots))))))

(ert-deftest test-mcp-request-dispatcher-roots-list-mixed-types ()
  "Lists mixing strings and plists handle each per type."
  (mcp-test-with-clean-connections
    (puthash "demo" (mcp-test-make-fake-connection
                     :roots '("/tmp/string-root"
                              (:uri "file:///plist-root" :name "Plist")))
             mcp-server-connections)
    (let* ((result (mcp-request-dispatcher "demo" 'roots/list nil))
           (roots (plist-get result :roots)))
      (should (= 2 (length roots)))
      (should (string= "string-root" (plist-get (aref roots 0) :name)))
      (should (string= "Plist" (plist-get (aref roots 1) :name))))))

(ert-deftest test-mcp-request-dispatcher-unknown-method-no-error ()
  "Methods other than `roots/list' fall through to `message' — should
not error and should return nil (the message return value)."
  (mcp-test-with-clean-connections
    ;; Suppress message output.
    (cl-letf (((symbol-function 'message) #'ignore))
      (should-not (mcp-request-dispatcher "demo" 'unknown/method '(:foo 1))))))

;;; --- mcp-notification-dispatcher ---

(ert-deftest test-mcp-notification-dispatcher-message-notification ()
  "notifications/message with :level + :data logs without erroring.
The connection's :logging capability must be present for the log path
to fire, but the non-fire path also returns without error."
  (let ((logged nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (push (apply #'format fmt args) logged))))
      (let ((conn (mcp-test-make-fake-connection
                   :capabilities '(:logging t))))
        (mcp-notification-dispatcher
         conn "demo" 'notifications/message
         '(:level "info" :data "hello"))
        (should (cl-some (lambda (m) (string-match-p "hello" m)) logged))))))

(ert-deftest test-mcp-notification-dispatcher-unknown-method-no-error ()
  "Unknown notification method falls through to `message' — no error."
  (cl-letf (((symbol-function 'message) #'ignore))
    (let ((conn (mcp-test-make-fake-connection)))
      ;; Should not raise.
      (mcp-notification-dispatcher conn "demo" 'something/else nil)
      (should t))))

;;; test-mcp-dispatchers.el ends here
