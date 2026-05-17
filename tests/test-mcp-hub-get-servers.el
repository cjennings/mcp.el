;;; test-mcp-hub-get-servers.el --- Tests for mcp-hub-get-servers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub-get-servers'.  Walks `mcp-hub-servers' (the
;; user's configured alist) and returns a per-server plist showing the
;; current state: name + status only for stopped servers, or
;; connection-type + tools + resources + prompts + roots + status when
;; the server is connected.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; Normal cases

(ert-deftest test-mcp-hub-get-servers-no-config-returns-empty ()
  "Empty `mcp-hub-servers' alist yields an empty list."
  (mcp-test-with-clean-connections
    (let ((mcp-hub-servers nil))
      (should (null (mcp-hub-get-servers))))))

(ert-deftest test-mcp-hub-get-servers-configured-but-not-connected ()
  "A server in the configuration but absent from `mcp-server-connections'
appears with :status `stop' and no other fields."
  (mcp-test-with-clean-connections
    (let ((mcp-hub-servers '(("demo" . (:command "echo")))))
      (let ((result (mcp-hub-get-servers)))
        (should (= 1 (length result)))
        (should (string= "demo" (plist-get (car result) :name)))
        (should (eq 'stop (plist-get (car result) :status)))
        (should-not (plist-member (car result) :type))))))

(ert-deftest test-mcp-hub-get-servers-connected-server-has-all-fields ()
  "A connected server returns a plist carrying its type, status, tools,
resources, template-resources, prompts, and roots."
  (mcp-test-with-clean-connections
    (let ((mcp-hub-servers '(("demo" . (:command "echo"))))
          (conn (mcp-test-make-fake-connection
                 :status 'connected
                 :tools [(:name "t1")]
                 :resources [(:uri "x://r")]
                 :template-resources nil
                 :prompts [(:name "p1")]
                 :roots '("/tmp"))))
      (puthash "demo" conn mcp-server-connections)
      (let ((entry (car (mcp-hub-get-servers))))
        (should (eq 'connected (plist-get entry :status)))
        (should (eq 'http (plist-get entry :type)))
        (should (equal [(:name "t1")] (plist-get entry :tools)))
        (should (equal [(:uri "x://r")] (plist-get entry :resources)))
        (should (equal [(:name "p1")] (plist-get entry :prompts)))
        (should (equal '("/tmp") (plist-get entry :roots)))))))

;;; Boundary cases

(ert-deftest test-mcp-hub-get-servers-mixed-connected-and-stopped ()
  "When some servers are connected and others aren't, each entry has
the right shape independently."
  (mcp-test-with-clean-connections
    (let ((mcp-hub-servers '(("up" . (:command "x"))
                             ("down" . (:command "y")))))
      (puthash "up" (mcp-test-make-fake-connection :status 'connected)
               mcp-server-connections)
      (let ((entries (mcp-hub-get-servers)))
        (should (eq 'connected (plist-get (nth 0 entries) :status)))
        (should (eq 'stop (plist-get (nth 1 entries) :status)))))))

(ert-deftest test-mcp-hub-get-servers-preserves-configured-order ()
  "The result list mirrors the order of `mcp-hub-servers'."
  (mcp-test-with-clean-connections
    (let ((mcp-hub-servers '(("alpha" . (:command "a"))
                             ("beta"  . (:command "b"))
                             ("gamma" . (:command "c")))))
      (let ((entries (mcp-hub-get-servers)))
        (should (equal '("alpha" "beta" "gamma")
                       (mapcar (lambda (e) (plist-get e :name)) entries)))))))

;;; test-mcp-hub-get-servers.el ends here
