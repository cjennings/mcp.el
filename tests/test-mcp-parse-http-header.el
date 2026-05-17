;;; test-mcp-parse-http-header.el --- Tests for mcp--parse-http-header -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--parse-http-header'.  Parses an HTTP response
;; header block into a plist keyed by downcased header names, plus a
;; `:response-code' entry extracted from the status line.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-parse-http-header-typical-response ()
  "Typical CRLF-separated headers produce a plist with `:response-code'
and lowercased keyword keys."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nServer: nginx\r\n")))
    (should (string= "200" (plist-get result :response-code)))
    (should (string= "text/html" (plist-get result :content-type)))
    (should (string= "nginx" (plist-get result :server)))))

(ert-deftest test-mcp-parse-http-header-lowercases-keys ()
  "Header keys are downcased before becoming keywords."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\r\nX-Custom-Header: foo\r\n")))
    (should (string= "foo" (plist-get result :x-custom-header)))
    (should-not (plist-member result :X-Custom-Header))))

(ert-deftest test-mcp-parse-http-header-values-with-colons ()
  "Only the FIRST colon splits the key/value, so values that contain
colons (e.g. `Mcp-Session-Id: abc:def') survive intact."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\r\nMcp-Session-Id: abc:def:ghi\r\n")))
    (should (string= "abc:def:ghi" (plist-get result :mcp-session-id)))))

(ert-deftest test-mcp-parse-http-header-trims-value-whitespace ()
  "Whitespace around the value is stripped."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\r\nContent-Type:    text/html   \r\n")))
    (should (string= "text/html" (plist-get result :content-type)))))

;;; Boundary cases

(ert-deftest test-mcp-parse-http-header-status-line-only ()
  "Header block with only a status line returns just `:response-code'."
  (let ((result (mcp--parse-http-header "HTTP/1.1 204 No Content\r\n")))
    (should (string= "204" (plist-get result :response-code)))))

(ert-deftest test-mcp-parse-http-header-non-200-status-codes ()
  "Status codes other than 200 are extracted unchanged."
  (should (string= "404" (plist-get
                          (mcp--parse-http-header "HTTP/1.1 404 Not Found\r\n")
                          :response-code)))
  (should (string= "500" (plist-get
                          (mcp--parse-http-header "HTTP/1.1 500 Server Error\r\n")
                          :response-code))))

(ert-deftest test-mcp-parse-http-header-lf-only-separator ()
  "Headers separated by `\\n' only (no carriage return) still parse,
because `mcp--parse-http-header' splits on `\\n' and trims each line."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\nContent-Type: text/html\n")))
    (should (string= "200" (plist-get result :response-code)))
    (should (string= "text/html" (plist-get result :content-type)))))

(ert-deftest test-mcp-parse-http-header-ignores-non-key-value-lines ()
  "Lines without a colon (blank, junk) contribute nothing — keys with
colons still parse correctly."
  (let ((result (mcp--parse-http-header
                 "HTTP/1.1 200 OK\r\n\r\nContent-Type: text/html\r\njunk-no-colon\r\n")))
    (should (string= "200" (plist-get result :response-code)))
    (should (string= "text/html" (plist-get result :content-type)))))

;;; Error / edge cases

(ert-deftest test-mcp-parse-http-header-empty-string-returns-nil ()
  "Empty input has no status-line second token, so `when-let*' returns nil."
  (should (null (mcp--parse-http-header ""))))

;;; test-mcp-parse-http-header.el ends here
