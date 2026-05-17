;;; test-mcp-list-items.el --- Tests for mcp--list-items -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--list-items', the shared helper behind every
;; `mcp-(async|sync)-list-*' wrapper.  Parameters are `connection',
;; `method', `key-name', `slot-name', `callback', `error-callback', and
;; `syncp'.  In practice the first four are linked — there are exactly
;; four valid (method, key-name, slot-name) triples, one per endpoint.
;;
;; Tests use pairwise coverage across the independent dimensions:
;;
;;   endpoint   ∈ {tools, prompts, resources, templates}
;;   callback   ∈ {yes, no}
;;   error-cb   ∈ {yes, no}
;;   syncp      ∈ {async, sync}
;;
;; Exhaustive is 4*2*2*2 = 32; pairwise covers every 2-way interaction
;; in 8 cases.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

(defun mcp-test--list-items-endpoint (endpoint)
  "Return (METHOD KEY-NAME SLOT-NAME) for ENDPOINT.
ENDPOINT is one of `tools', `prompts', `resources', `templates'."
  (pcase endpoint
    ('tools     (list :tools/list :tools '-tools))
    ('prompts   (list :prompts/list :prompts '-prompts))
    ('resources (list :resources/list :resources '-resources))
    ('templates (list :resources/templates/list :resourceTemplates '-template-resources))))

(defun mcp-test--list-items-response (endpoint)
  "Return a canned JSON-RPC response plist for ENDPOINT.
Shape mirrors what the MCP spec returns from a `<endpoint>/list' call."
  (pcase endpoint
    ('tools     '(:tools ((:name "echo"))))
    ('prompts   '(:prompts ((:name "summarize"))))
    ('resources '(:resources ((:uri "x://r"))))
    ('templates '(:resourceTemplates ((:uriTemplate "x://{n}"))))))

(defun mcp-test--call-list-items (endpoint with-callback with-error-cb sync)
  "Invoke `mcp--list-items' for the given pairwise case.

Returns a plist with the recorded call data and the side-effect state:
  :method      — the JSON-RPC method seen by the stubbed transport
  :rpc-kind    — `async' or `sync'
  :slot-value  — the slot's value after the call resolved
  :callback-fired — t if the test's callback was invoked
  :error-callback-fired — t if the test's error callback was invoked"
  (cl-destructuring-bind (method key-name slot-name)
      (mcp-test--list-items-endpoint endpoint)
    (let* ((conn (mcp-test-make-fake-connection :status 'connected))
           (response (mcp-test--list-items-response endpoint))
           (cb-fired nil)
           (err-cb-fired nil)
           (callback (when with-callback (lambda (_c _items) (setq cb-fired t))))
           (error-callback (when with-error-cb (lambda (_c _m) (setq err-cb-fired t))))
           (rpc-method nil)
           (rpc-kind nil))
      (cl-letf (((symbol-function 'jsonrpc-async-request)
                 (lambda (_conn m _params &rest kwargs)
                   (setq rpc-method m rpc-kind 'async)
                   (when-let* ((success-fn (plist-get kwargs :success-fn)))
                     (funcall success-fn response))
                   nil))
                ((symbol-function 'jsonrpc-request)
                 (lambda (_conn m _params &rest _kwargs)
                   (setq rpc-method m rpc-kind 'sync)
                   response)))
        (mcp--list-items conn method key-name slot-name
                         callback error-callback
                         (when sync 'sync)))
      (list :method rpc-method
            :rpc-kind rpc-kind
            :slot-value (slot-value conn slot-name)
            :callback-fired cb-fired
            :error-callback-fired err-cb-fired))))

;;; Pairwise matrix — 8 cases covering every 2-way interaction across
;;; (endpoint, callback, error-cb, syncp).

(ert-deftest test-mcp-list-items-pairwise-1-tools-async-cb-ec ()
  "Pair 1: tools / async / callback yes / error-cb yes."
  (let ((r (mcp-test--call-list-items 'tools t t nil)))
    (should (eq :tools/list (plist-get r :method)))
    (should (eq 'async (plist-get r :rpc-kind)))
    (should (plist-get r :slot-value))
    (should (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-2-tools-sync-no-cbs ()
  "Pair 2: tools / sync / no callback / no error-cb."
  (let ((r (mcp-test--call-list-items 'tools nil nil t)))
    (should (eq :tools/list (plist-get r :method)))
    (should (eq 'sync (plist-get r :rpc-kind)))
    (should (plist-get r :slot-value))
    (should-not (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-3-prompts-async-cb-only ()
  "Pair 3: prompts / async / callback yes / no error-cb."
  (let ((r (mcp-test--call-list-items 'prompts t nil nil)))
    (should (eq :prompts/list (plist-get r :method)))
    (should (eq 'async (plist-get r :rpc-kind)))
    (should (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-4-prompts-sync-ec-only ()
  "Pair 4: prompts / sync / no callback / error-cb yes."
  (let ((r (mcp-test--call-list-items 'prompts nil t t)))
    (should (eq :prompts/list (plist-get r :method)))
    (should (eq 'sync (plist-get r :rpc-kind)))
    (should-not (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-5-resources-sync-both-cbs ()
  "Pair 5: resources / sync / callback yes / error-cb yes."
  (let ((r (mcp-test--call-list-items 'resources t t t)))
    (should (eq :resources/list (plist-get r :method)))
    (should (eq 'sync (plist-get r :rpc-kind)))
    (should (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-6-resources-async-no-cbs ()
  "Pair 6: resources / async / no callback / no error-cb."
  (let ((r (mcp-test--call-list-items 'resources nil nil nil)))
    (should (eq :resources/list (plist-get r :method)))
    (should (eq 'async (plist-get r :rpc-kind)))))

(ert-deftest test-mcp-list-items-pairwise-7-templates-sync-cb-only ()
  "Pair 7: templates / sync / callback yes / no error-cb."
  (let ((r (mcp-test--call-list-items 'templates t nil t)))
    (should (eq :resources/templates/list (plist-get r :method)))
    (should (eq 'sync (plist-get r :rpc-kind)))
    (should (plist-get r :callback-fired))))

(ert-deftest test-mcp-list-items-pairwise-8-templates-async-ec-only ()
  "Pair 8: templates / async / no callback / error-cb yes."
  (let ((r (mcp-test--call-list-items 'templates nil t nil)))
    (should (eq :resources/templates/list (plist-get r :method)))
    (should (eq 'async (plist-get r :rpc-kind)))))

;;; Directed tests — behaviors not captured by the matrix.

(ert-deftest test-mcp-list-items-async-error-fires-error-callback ()
  "When the async transport reports an error, the wrapped error-fn
calls the user's error-callback with code and message."
  (let* ((conn (mcp-test-make-fake-connection))
         (received nil))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :error-fn)
                          (list :code 500 :message "boom")))))
      (mcp--list-items conn :tools/list :tools '-tools
                       nil
                       (lambda (code msg) (setq received (list code msg)))
                       nil))
    (should (equal '(500 "boom") received))))

(ert-deftest test-mcp-list-items-response-missing-key-does-not-set-slot ()
  "If the response lacks the expected key (e.g. `:tools'), the success
path's `when-let*' short-circuits and the slot stays unchanged."
  (let ((conn (mcp-test-make-fake-connection)))
    (cl-letf (((symbol-function 'jsonrpc-async-request)
               (lambda (_conn _m _p &rest kwargs)
                 (funcall (plist-get kwargs :success-fn) '(:unrelated "field")))))
      (mcp--list-items conn :tools/list :tools '-tools nil nil nil))
    (should-not (slot-value conn '-tools))))

;;; test-mcp-list-items.el ends here
