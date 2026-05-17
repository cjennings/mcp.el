;;; test-mcp-parse-http-url.el --- Tests for mcp--parse-http-url -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--parse-http-url'.  Parses an HTTP(S) URL into a
;; plist with `:tls', `:host', `:port', and `:path'.  Non-HTTP schemes
;; return nil.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-parse-http-url-http-with-port-and-path ()
  "HTTP URL with explicit port and path parses to all four fields."
  (let ((result (mcp--parse-http-url "http://example.com:8080/api/v1")))
    (should (null (plist-get result :tls)))
    (should (string= "example.com" (plist-get result :host)))
    (should (= 8080 (plist-get result :port)))
    (should (string= "/api/v1" (plist-get result :path)))))

(ert-deftest test-mcp-parse-http-url-https-with-port-and-path ()
  "HTTPS URL with explicit port and path marks `:tls' as t."
  (let ((result (mcp--parse-http-url "https://example.com:8443/mcp")))
    (should (eq t (plist-get result :tls)))
    (should (string= "example.com" (plist-get result :host)))
    (should (= 8443 (plist-get result :port)))
    (should (string= "/mcp" (plist-get result :path)))))

(ert-deftest test-mcp-parse-http-url-default-port-http ()
  "HTTP URL without an explicit port defaults to port 80."
  (let ((result (mcp--parse-http-url "http://example.com/")))
    (should (null (plist-get result :tls)))
    (should (= 80 (plist-get result :port)))))

(ert-deftest test-mcp-parse-http-url-default-port-https ()
  "HTTPS URL without an explicit port defaults to port 443."
  (let ((result (mcp--parse-http-url "https://example.com/")))
    (should (eq t (plist-get result :tls)))
    (should (= 443 (plist-get result :port)))))

;;; Boundary cases

(ert-deftest test-mcp-parse-http-url-ipv4-host ()
  "IPv4 literal host is preserved as the `:host' string."
  (let ((result (mcp--parse-http-url "http://127.0.0.1:8000/sse")))
    (should (string= "127.0.0.1" (plist-get result :host)))
    (should (= 8000 (plist-get result :port)))
    (should (string= "/sse" (plist-get result :path)))))

(ert-deftest test-mcp-parse-http-url-localhost ()
  "`localhost' hostname is preserved verbatim."
  (let ((result (mcp--parse-http-url "http://localhost:8000/")))
    (should (string= "localhost" (plist-get result :host)))))

(ert-deftest test-mcp-parse-http-url-trailing-slash-only ()
  "URL whose path is only `/' parses with `:path' = `/'."
  (let ((result (mcp--parse-http-url "http://host.example/")))
    (should (string= "/" (plist-get result :path)))))

;;; Error / edge cases

(ert-deftest test-mcp-parse-http-url-ftp-scheme-returns-nil ()
  "Non-HTTP scheme returns nil — only http/https are recognized."
  (should (null (mcp--parse-http-url "ftp://example.com/file"))))

(ert-deftest test-mcp-parse-http-url-file-scheme-returns-nil ()
  "`file://' scheme returns nil."
  (should (null (mcp--parse-http-url "file:///etc/passwd"))))

;;; test-mcp-parse-http-url.el ends here
