;;; test-mcp-parse-tool-args.el --- Tests for mcp--parse-tool-args -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--parse-tool-args'.  Takes a JSON-Schema-shaped
;; `properties' plist and a list of required argument names, returns
;; per-argument plists annotated with `:name' and (for arguments not in
;; required) `:optional t'.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Normal cases

(ert-deftest test-mcp-parse-tool-args-all-required ()
  "Every property listed in required produces a plist without :optional."
  (let* ((properties '(:path (:type "string" :description "path")
                       :content (:type "string" :description "content")))
         (required '("path" "content"))
         (result (mcp--parse-tool-args properties required)))
    (should (= 2 (length result)))
    (should (string= "path" (plist-get (nth 0 result) :name)))
    (should (string= "string" (plist-get (nth 0 result) :type)))
    (should (string= "path" (plist-get (nth 0 result) :description)))
    (should-not (plist-member (nth 0 result) :optional))
    (should (string= "content" (plist-get (nth 1 result) :name)))
    (should-not (plist-member (nth 1 result) :optional))))

(ert-deftest test-mcp-parse-tool-args-mixed-required-and-optional ()
  "Properties not in required get `:optional t'."
  (let* ((properties '(:path (:type "string")
                       :encoding (:type "string" :default "utf-8")))
         (required '("path"))
         (result (mcp--parse-tool-args properties required)))
    (should (= 2 (length result)))
    (should-not (plist-member (nth 0 result) :optional))
    (should (eq t (plist-get (nth 1 result) :optional)))))

(ert-deftest test-mcp-parse-tool-args-all-optional ()
  "Empty required list -> every entry gets `:optional t'."
  (let* ((properties '(:a (:type "string") :b (:type "number")))
         (result (mcp--parse-tool-args properties '())))
    (should (= 2 (length result)))
    (dolist (entry result)
      (should (eq t (plist-get entry :optional))))))

(ert-deftest test-mcp-parse-tool-args-strips-keyword-prefix-from-name ()
  "The `:foo' keyword becomes the string `foo' in `:name'."
  (let ((result (mcp--parse-tool-args '(:foo (:type "string")) '("foo"))))
    (should (string= "foo" (plist-get (car result) :name)))))

(ert-deftest test-mcp-parse-tool-args-splices-property-attributes ()
  "Attributes inside each property's value plist are spliced into the
result entry alongside `:name'."
  (let ((result (mcp--parse-tool-args
                 '(:n (:type "number" :description "count" :minimum 1))
                 '("n"))))
    (should (string= "n" (plist-get (car result) :name)))
    (should (string= "number" (plist-get (car result) :type)))
    (should (string= "count" (plist-get (car result) :description)))
    (should (= 1 (plist-get (car result) :minimum)))))

;;; Boundary cases

(ert-deftest test-mcp-parse-tool-args-empty-properties ()
  "Empty properties returns the empty list."
  (should (null (mcp--parse-tool-args '() '()))))

(ert-deftest test-mcp-parse-tool-args-single-property ()
  "Single property + matching required produces a single entry."
  (let ((result (mcp--parse-tool-args '(:x (:type "string")) '("x"))))
    (should (= 1 (length result)))
    (should (string= "x" (plist-get (car result) :name)))))

;;; test-mcp-parse-tool-args.el ends here
