;;; test-mcp-resolve-value.el --- Tests for mcp--resolve-value -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp--resolve-value'.  The function resolves a value in
;; three modes: function -> call it, bound symbol -> its value, otherwise
;; -> the value itself.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;; Top-level declaration so the let in `test-mcp-resolve-value-bound-symbol'
;; creates a dynamic binding; `boundp' / `symbol-value' look at the dynamic
;; binding stack, not lexical scope.
(defvar mcp-test--secret nil
  "Test-only dynamic variable used by `test-mcp-resolve-value-bound-symbol'.")

;;; Normal cases

(ert-deftest test-mcp-resolve-value-plain-string ()
  "Plain string returns itself."
  (should (string= "hello" (mcp--resolve-value "hello"))))

(ert-deftest test-mcp-resolve-value-plain-integer ()
  "Plain integer returns itself."
  (should (= 42 (mcp--resolve-value 42))))

(ert-deftest test-mcp-resolve-value-function ()
  "Function is funcalled with no args; result is its return value."
  (cl-letf (((symbol-function 'mcp-test--produce) (lambda () "produced")))
    (should (string= "produced" (mcp--resolve-value #'mcp-test--produce)))))

(ert-deftest test-mcp-resolve-value-lambda ()
  "Lambda is funcalled and its return value is returned."
  (should (string= "lambdic" (mcp--resolve-value (lambda () "lambdic")))))

(ert-deftest test-mcp-resolve-value-bound-symbol ()
  "Bound (dynamic) symbol returns its symbol-value."
  (let ((mcp-test--secret "from-binding"))
    (should (string= "from-binding" (mcp--resolve-value 'mcp-test--secret)))))

;;; Boundary cases

(ert-deftest test-mcp-resolve-value-nil ()
  "nil falls through the cond — result is nil."
  (should (null (mcp--resolve-value nil))))

(ert-deftest test-mcp-resolve-value-empty-string ()
  "Empty string is truthy and returned as-is."
  (should (string= "" (mcp--resolve-value ""))))

(ert-deftest test-mcp-resolve-value-zero ()
  "Zero is truthy in Emacs Lisp and returns itself."
  (should (= 0 (mcp--resolve-value 0))))

(ert-deftest test-mcp-resolve-value-t ()
  "Symbol t is bound; its symbol-value (also t) is returned."
  (should (eq t (mcp--resolve-value 't))))

;;; Error / edge cases

(ert-deftest test-mcp-resolve-value-unbound-symbol-returns-symbol ()
  "Unbound symbol does not match symbolp+boundp; cond falls through to
return the symbol itself (because the symbol is truthy)."
  (let ((sym (make-symbol "mcp-test--never-bound")))
    (should-not (boundp sym))
    (should (eq sym (mcp--resolve-value sym)))))

;;; test-mcp-resolve-value.el ends here
