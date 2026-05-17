;;; test-mcp-generate-tool-call-args.el --- Tests for mcp--generate-tool-call-args -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--generate-tool-call-args'.  Pairs caller-supplied
;; positional args with the tool's schema properties, filling missing
;; trailing args from each property's `:default' and silently dropping
;; ones with no default.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-generate-tool-call-args-all-supplied ()
  "When the caller supplies one arg per property, every value passes through."
  (let ((result (mcp--generate-tool-call-args
                 '("/tmp/foo" "body")
                 '(:path (:type "string") :content (:type "string")))))
    (should (equal '(:path "/tmp/foo" :content "body") result))))

(ert-deftest test-mcp-generate-tool-call-args-default-fills-missing-trailing ()
  "Missing trailing args get their property's `:default'."
  (let ((result (mcp--generate-tool-call-args
                 '("/tmp/foo")
                 '(:path (:type "string")
                   :encoding (:type "string" :default "utf-8")))))
    (should (equal '(:path "/tmp/foo" :encoding "utf-8") result))))

(ert-deftest test-mcp-generate-tool-call-args-default-only ()
  "Zero caller args with a default fills both from `:default'."
  (let ((result (mcp--generate-tool-call-args
                 '()
                 '(:host (:type "string" :default "localhost")
                   :port (:type "number" :default 8080)))))
    (should (equal '(:host "localhost" :port 8080) result))))

(ert-deftest test-mcp-generate-tool-call-args-extra-args-ignored ()
  "Caller args longer than `properties' have the extras silently dropped
because `cl-mapcar' truncates to the partitioned-properties length."
  (let ((result (mcp--generate-tool-call-args
                 '("a" "b" "extra")
                 '(:x (:type "string") :y (:type "string")))))
    (should (equal '(:x "a" :y "b") result))))

;;; Boundary cases

(ert-deftest test-mcp-generate-tool-call-args-missing-arg-no-default-dropped ()
  "A missing arg with no `:default' is silently dropped — `when-let*'
fails and contributes nothing to the result plist."
  (let ((result (mcp--generate-tool-call-args
                 '()
                 '(:required-key (:type "string")))))
    (should (null result))))

(ert-deftest test-mcp-generate-tool-call-args-empty-args-empty-properties ()
  "Both empty -> empty plist."
  (should (null (mcp--generate-tool-call-args '() '()))))

(ert-deftest test-mcp-generate-tool-call-args-default-used-only-when-arg-nil ()
  "A nil arg in the supplied list also triggers the default fallback —
the function's check is `(if value value default)', so nil means use default."
  (let ((result (mcp--generate-tool-call-args
                 '(nil)
                 '(:k (:type "string" :default "fallback")))))
    (should (equal '(:k "fallback") result))))

;;; test-mcp-generate-tool-call-args.el ends here
