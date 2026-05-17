;;; test-mcp-parse-tool-call-result.el --- Tests for mcp--parse-tool-call-result -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--parse-tool-call-result'.  Extracts `:text'
;; entries from the `:content' list of an MCP tool-call response,
;; concatenating them with newlines and skipping non-text content.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-parse-tool-call-result-single-text ()
  "A single text content entry returns just its text (no separator)."
  (should (string= "hello"
                   (mcp--parse-tool-call-result
                    '(:content ((:type "text" :text "hello")))))))

(ert-deftest test-mcp-parse-tool-call-result-multiple-texts-joined-with-newline ()
  "Multiple text entries are joined with a literal newline."
  (should (string= "a\nb\nc"
                   (mcp--parse-tool-call-result
                    '(:content ((:type "text" :text "a")
                                (:type "text" :text "b")
                                (:type "text" :text "c")))))))

(ert-deftest test-mcp-parse-tool-call-result-skips-non-text-content ()
  "Image (or other non-text) content entries are filtered out."
  (should (string= "only-text"
                   (mcp--parse-tool-call-result
                    '(:content ((:type "image" :data "binary-blob")
                                (:type "text" :text "only-text")))))))

;;; Boundary cases

(ert-deftest test-mcp-parse-tool-call-result-empty-content ()
  "Empty `:content' list yields the empty string."
  (should (string= "" (mcp--parse-tool-call-result '(:content ())))))

(ert-deftest test-mcp-parse-tool-call-result-missing-content-key ()
  "Plist without `:content' yields the empty string (plist-get returns nil)."
  (should (string= "" (mcp--parse-tool-call-result '()))))

(ert-deftest test-mcp-parse-tool-call-result-empty-text ()
  "An empty text entry contributes the empty string, not nil."
  (should (string= ""
                   (mcp--parse-tool-call-result
                    '(:content ((:type "text" :text "")))))))

(ert-deftest test-mcp-parse-tool-call-result-only-non-text ()
  "Content list of only non-text entries yields the empty string."
  (should (string= ""
                   (mcp--parse-tool-call-result
                    '(:content ((:type "image" :data "x")
                                (:type "audio" :data "y")))))))

;;; test-mcp-parse-tool-call-result.el ends here
