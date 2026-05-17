;;; test-mcp-hub-prep-resource-text.el --- Tests for mcp-hub--prep-resource-text -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub--prep-resource-text' — the pure helper
;; extracted from `mcp-hub-detail--display-resource'.  Turns a
;; `resources/read' response into a single display string.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-hub-prep-resource-text-single-text-content ()
  "A single text content yields just its `:text' verbatim."
  (should (string= "hello"
                   (mcp-hub--prep-resource-text
                    '(:contents [(:text "hello")])))))

(ert-deftest test-mcp-hub-prep-resource-text-multiple-parts-joined ()
  "Multiple content parts are joined with `\\n---\\n'."
  (should (string= "one\n---\ntwo"
                   (mcp-hub--prep-resource-text
                    '(:contents [(:text "one") (:text "two")])))))

(ert-deftest test-mcp-hub-prep-resource-text-text-mime-not-prefixed ()
  "A `:text' with a `text/*' MIME type is rendered without a MIME prefix."
  (should (string= "body"
                   (mcp-hub--prep-resource-text
                    '(:contents [(:text "body" :mimeType "text/plain")])))))

(ert-deftest test-mcp-hub-prep-resource-text-non-text-mime-prefixed ()
  "A `:text' carrying a non-`text/' MIME type gets a `[MIME: …]\\n' prefix."
  (let ((result (mcp-hub--prep-resource-text
                 '(:contents [(:text "<svg/>" :mimeType "image/svg+xml")]))))
    (should (string-prefix-p "[MIME: image/svg+xml]\n" result))
    (should (string-match-p "<svg/>" result))))

;;; Boundary cases

(ert-deftest test-mcp-hub-prep-resource-text-blob-renders-summary ()
  "A blob content yields a `[Binary: …]' summary, not the bytes."
  (let ((result (mcp-hub--prep-resource-text
                 '(:contents [(:blob "aGVsbG8="
                               :mimeType "application/octet-stream")]))))
    (should (string-match-p "\\[Binary:" result))
    (should (string-match-p "application/octet-stream" result))))

(ert-deftest test-mcp-hub-prep-resource-text-blob-without-mime-defaults ()
  "A blob without `:mimeType' falls back to `application/octet-stream'."
  (let ((result (mcp-hub--prep-resource-text
                 '(:contents [(:blob "AAAA")]))))
    (should (string-match-p "application/octet-stream" result))))

(ert-deftest test-mcp-hub-prep-resource-text-contents-single-plist ()
  "When `:contents' is a single plist instead of a vector, it's wrapped
to a one-element vector and rendered as one part."
  (should (string= "single"
                   (mcp-hub--prep-resource-text
                    '(:contents (:text "single"))))))

;;; test-mcp-hub-prep-resource-text.el ends here
