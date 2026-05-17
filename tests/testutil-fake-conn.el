;;; testutil-fake-conn.el --- Fake-connection helpers for mcp.el tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Shared fixtures for unit tests that need an `mcp-http-process-connection'
;; instance but no live process.  `mcp-http-process-connection's
;; `initialize-instance :around' method sets `jsonrpc--process' to nil
;; explicitly, which lets us construct one without a backing process.
;;
;; Three things live in here:
;;
;; - `mcp-test-make-fake-connection' — construct a populated instance
;; - `mcp-test-with-clean-connections' — run a body with `mcp-server-connections'
;;   temporarily empty; the prior contents are restored on exit
;; - `mcp-test-with-fake-notify' — replace `mcp-notify' with a recorder that
;;   appends each call to a list, accessible inside the body as
;;   `mcp-test-notify-log'

;;; Code:

(require 'cl-lib)

;; Loaded transitively when test files require test-bootstrap.
(declare-function make-instance "eieio")
(declare-function clrhash "subr")
(declare-function copy-hash-table "subr")
(declare-function maphash "subr")
(declare-function puthash "subr")

(defun mcp-test-make-fake-connection (&rest overrides)
  "Construct an `mcp-http-process-connection' suitable for unit tests.

The connection is initialized with sensible defaults for every required
slot, plus :connection-type set to `http'.  No real process is started:
`mcp-http-process-connection's `initialize-instance :around' method
explicitly sets `jsonrpc--process' to nil.

OVERRIDES is a plist of slot accessors (without the `mcp--' prefix) to
values; each override is applied after construction via the matching
`setf' form.  Example:

  (mcp-test-make-fake-connection :status \\='connected
                                 :tools [(:name \"foo\")]
                                 :roots \\='(\"/tmp\"))

Slot names accepted by OVERRIDES match the `mcp--<name>' accessors:
`status', `capabilities', `server-info', `prompts', `tools',
`resources', `template-resources', `roots', `host', `port', `path',
`tls', `token', `headers', `sse', `endpoint', `session-id'."
  (let ((conn (make-instance 'mcp-http-process-connection
                             :connection-type 'http
                             :host "test.example"
                             :port 0
                             :path "/"
                             :tls nil
                             :token nil
                             :initial-callback nil
                             :prompts-callback nil
                             :tools-callback nil
                             :resources-callback nil
                             :resources-templates-callback nil
                             :error-callback nil)))
    (cl-loop for (slot value) on overrides by #'cddr
             for setter = (intern (format "mcp--%s" (substring (symbol-name slot) 1)))
             do (eval `(setf (,setter ',conn) ',value) t))
    conn))

(defmacro mcp-test-with-clean-connections (&rest body)
  "Run BODY with `mcp-server-connections' empty, restoring it afterward.

Useful for tests that depend on a fresh hash table — set up the
connections you need inside BODY, run assertions, and the hash is
restored on exit (even if BODY signals)."
  (declare (indent 0) (debug t))
  (let ((saved (make-symbol "saved")))
    `(let ((,saved (copy-hash-table mcp-server-connections)))
       (unwind-protect
           (progn (clrhash mcp-server-connections) ,@body)
         (clrhash mcp-server-connections)
         (maphash (lambda (k v) (puthash k v mcp-server-connections)) ,saved)))))

(defmacro mcp-test-with-fake-notify (&rest body)
  "Run BODY with `mcp-notify' replaced by a recording stub.

Inside BODY, the dynamic variable `mcp-test-notify-log' is bound to a
list of (CONNECTION METHOD PARAMS) for every call made through
`mcp-notify' — most-recent first, accessible via `nreverse' for source
order."
  (declare (indent 0) (debug t))
  `(let ((mcp-test-notify-log '()))
     (cl-letf (((symbol-function 'mcp-notify)
                (lambda (connection method &optional params)
                  (push (list connection method params) mcp-test-notify-log)
                  nil)))
       ,@body)))

(defvar mcp-test-notify-log nil
  "Dynamic binding active inside `mcp-test-with-fake-notify'.
Each call to the faked `mcp-notify' pushes (CONNECTION METHOD PARAMS)
onto this list (most-recent first).")

(defmacro mcp-test-with-process-filter-fixture (vars &rest body)
  "Bind (PROC CONN RECEIVED) within BODY.

PROC is a live `make-pipe-process' with its own buffer.  CONN is an mcp
connection switched into stdio mode and attached via
`process-put proc \\='jsonrpc-connection'.  RECEIVED is a list (most-recent
first) that records every JSON plist passed to the stubbed
`jsonrpc-connection-receive'.

`timer-activate' is stubbed to run the timer's function inline with its
args so dispatch is synchronous — tests can assert on RECEIVED right
after the filter returns.

Process and buffers are torn down on exit (including the `jsonrpc-pending'
buffer when the filter created one)."
  (declare (indent 1) (debug t))
  (cl-destructuring-bind (proc-var conn-var received-var) vars
    `(let* ((,received-var '())
            (,proc-var (make-pipe-process
                        :name "mcp-test-pipe"
                        :buffer (generate-new-buffer-name " *mcp-test*")
                        :noquery t))
            (,conn-var (mcp-test-make-fake-connection :status 'connected)))
       (setf (mcp--connection-type ,conn-var) 'stdio)
       (process-put ,proc-var 'jsonrpc-connection ,conn-var)
       (unwind-protect
           (cl-letf (((symbol-function 'jsonrpc-connection-receive)
                      (lambda (_conn msg)
                        (push msg ,received-var)))
                     ((symbol-function 'timer-activate)
                      (lambda (timer)
                        (apply (timer--function timer)
                               (timer--args timer)))))
             ,@body)
         (when (and (process-live-p ,proc-var)) (delete-process ,proc-var))
         (when-let* ((pending (process-get ,proc-var 'jsonrpc-pending))
                     ((buffer-live-p pending)))
           (kill-buffer pending))
         (when (buffer-live-p (process-buffer ,proc-var))
           (kill-buffer (process-buffer ,proc-var)))))))

(provide 'testutil-fake-conn)
;;; testutil-fake-conn.el ends here
