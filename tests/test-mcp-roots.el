;;; test-mcp-roots.el --- Tests for the mcp-*-roots family -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-set-roots', `mcp-add-root', `mcp-remove-root',
;; `mcp-get-roots', and `mcp-on-shutdown'.  Each operates on a
;; connection stored in `mcp-server-connections'; the mutating variants
;; send a `notifications/roots/list_changed' notification to the server.
;;
;; `mcp-notify' is faked here — tests assert that the right notification
;; was queued without exercising the JSON-RPC transport itself.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

;;; --- mcp-set-roots ---

(ert-deftest test-mcp-set-roots-stores-new-roots-and-notifies ()
  "Setting roots writes them to the slot and queues a `list_changed'
notification."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection)))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-set-roots "demo" '("/tmp/one" "/tmp/two"))
        (should (equal '("/tmp/one" "/tmp/two") (mcp--roots conn)))
        (should (= 1 (length mcp-test-notify-log)))
        (let ((call (car mcp-test-notify-log)))
          (should (eq :notifications/roots/list_changed (nth 1 call))))))))

(ert-deftest test-mcp-set-roots-replaces-existing-roots ()
  "Calling set-roots twice replaces the previous list verbatim."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/old"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-set-roots "demo" '("/new"))
        (should (equal '("/new") (mcp--roots conn)))))))

(ert-deftest test-mcp-set-roots-no-connection-is-noop ()
  "set-roots on a missing server returns nil and does not notify."
  (mcp-test-with-clean-connections
    (mcp-test-with-fake-notify
      (should-not (mcp-set-roots "nope" '("/ignored")))
      (should (null mcp-test-notify-log)))))

;;; --- mcp-add-root ---

(ert-deftest test-mcp-add-root-appends-and-notifies ()
  "Adding a new root appends it to the list and notifies."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/a"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-add-root "demo" "/b")
        (should (equal '("/a" "/b") (mcp--roots conn)))
        (should (= 1 (length mcp-test-notify-log)))))))

(ert-deftest test-mcp-add-root-duplicate-is-noop ()
  "Adding a root that's already in the list skips both the setf and the
notification."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/a" "/b"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-add-root "demo" "/a")
        (should (equal '("/a" "/b") (mcp--roots conn)))
        (should (null mcp-test-notify-log))))))

(ert-deftest test-mcp-add-root-accepts-plist-root ()
  "A plist-shaped root (with :uri and :name) is appended verbatim."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/a"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-add-root "demo" '(:uri "file:///b" :name "B"))
        (should (equal '("/a" (:uri "file:///b" :name "B"))
                       (mcp--roots conn)))))))

(ert-deftest test-mcp-add-root-no-connection-is-noop ()
  "add-root on a missing server is a no-op."
  (mcp-test-with-clean-connections
    (mcp-test-with-fake-notify
      (should-not (mcp-add-root "nope" "/x"))
      (should (null mcp-test-notify-log)))))

;;; --- mcp-remove-root ---

(ert-deftest test-mcp-remove-root-removes-matching-and-notifies ()
  "Removing an existing root drops it from the list and notifies."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/a" "/b" "/c"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-remove-root "demo" "/b")
        (should (equal '("/a" "/c") (mcp--roots conn)))
        (should (= 1 (length mcp-test-notify-log)))))))

(ert-deftest test-mcp-remove-root-non-existent-still-notifies ()
  "Removing a root not in the list leaves the list unchanged but still
fires a notification — the current implementation does not branch on
\"actually removed\"."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/a"))))
      (puthash "demo" conn mcp-server-connections)
      (mcp-test-with-fake-notify
        (mcp-remove-root "demo" "/not-there")
        (should (equal '("/a") (mcp--roots conn)))
        (should (= 1 (length mcp-test-notify-log)))))))

(ert-deftest test-mcp-remove-root-no-connection-is-noop ()
  "remove-root on a missing server is a no-op."
  (mcp-test-with-clean-connections
    (mcp-test-with-fake-notify
      (should-not (mcp-remove-root "nope" "/x"))
      (should (null mcp-test-notify-log)))))

;;; --- mcp-get-roots ---

(ert-deftest test-mcp-get-roots-returns-current-roots ()
  "get-roots reads the connection's roots slot."
  (mcp-test-with-clean-connections
    (let ((conn (mcp-test-make-fake-connection :roots '("/x" "/y"))))
      (puthash "demo" conn mcp-server-connections)
      (should (equal '("/x" "/y") (mcp-get-roots "demo"))))))

(ert-deftest test-mcp-get-roots-no-connection-returns-nil ()
  "Missing server name yields nil."
  (mcp-test-with-clean-connections
    (should-not (mcp-get-roots "nope"))))

;;; --- mcp-on-shutdown ---

(ert-deftest test-mcp-on-shutdown-does-not-error ()
  "mcp-on-shutdown logs a `shutdown' message and returns the message
string.  Verified by capturing `message' output."
  (let ((captured nil))
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args)
                 (setq captured (apply #'format fmt args)))))
      (mcp-on-shutdown "demo")
      (should (string= "demo connection shutdown" captured)))))

;;; test-mcp-roots.el ends here
