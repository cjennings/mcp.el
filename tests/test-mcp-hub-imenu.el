;;; test-mcp-hub-imenu.el --- Tests for mcp-hub-detail-imenu-index-function -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub-detail-imenu-index-function'.  Scans the
;; current buffer for `outline-1' and `outline-2' propertized text and
;; returns an imenu-shaped alist: top-level entries are sections,
;; nested entries are items inside the most recent section.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

(defun mcp-test--insert-outline (level text)
  "Insert TEXT into the current buffer propertized with `outline-1' or
`outline-2', then a newline.  LEVEL is 1 or 2."
  (insert (propertize text 'face (if (= level 1) 'outline-1 'outline-2)))
  (insert "\n"))

;;; Normal cases

(ert-deftest test-mcp-hub-imenu-empty-buffer-yields-empty-index ()
  "An empty buffer has no headings, so the index is nil."
  (with-temp-buffer
    (should (null (mcp-hub-detail-imenu-index-function)))))

(ert-deftest test-mcp-hub-imenu-single-section ()
  "One outline-1 heading produces one top-level entry."
  (with-temp-buffer
    (mcp-test--insert-outline 1 "Status:")
    (let ((index (mcp-hub-detail-imenu-index-function)))
      (should (= 1 (length index)))
      (should (string= "Status:" (car (car index)))))))

(ert-deftest test-mcp-hub-imenu-section-with-children-nests ()
  "An outline-1 heading followed by outline-2 items has the items
nested under the section's cdr."
  (with-temp-buffer
    (mcp-test--insert-outline 1 "Tools:")
    (mcp-test--insert-outline 2 "  • echo")
    (mcp-test--insert-outline 2 "  • shout")
    (let* ((index (mcp-hub-detail-imenu-index-function))
           (section (car index)))
      (should (string= "Tools:" (car section)))
      (should (listp (cdr section)))
      (should (= 2 (length (cdr section))))
      (should (string= "  • echo" (car (nth 0 (cdr section))))))))

;;; Boundary cases

(ert-deftest test-mcp-hub-imenu-multiple-sections-preserved ()
  "Multiple sections each appear as separate top-level entries, with
their respective children nested correctly."
  (with-temp-buffer
    (mcp-test--insert-outline 1 "Status:")
    (mcp-test--insert-outline 1 "Tools:")
    (mcp-test--insert-outline 2 "  • echo")
    (let ((index (mcp-hub-detail-imenu-index-function)))
      (should (= 2 (length index)))
      (should (member "Status:" (mapcar #'car index)))
      (should (member "Tools:" (mapcar #'car index))))))

;;; test-mcp-hub-imenu.el ends here
