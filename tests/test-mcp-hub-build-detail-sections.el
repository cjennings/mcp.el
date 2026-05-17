;;; test-mcp-hub-build-detail-sections.el --- Tests for mcp-hub--build-detail-sections -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;;; Commentary:

;; Unit tests for `mcp-hub--build-detail-sections' — the pure helper
;; extracted from `mcp-hub-detail--render'.  Inspects an mcp connection
;; and produces a list of section plists keyed by `:kind' that the
;; renderer turns into buffer text.

;;; Code:

(require 'test-bootstrap (expand-file-name "test-bootstrap.el"))
(require 'testutil-fake-conn (expand-file-name "testutil-fake-conn.el"))

(defun mcp-test--section-of-kind (sections kind)
  "Find the section in SECTIONS with `:kind' equal to KIND, or nil."
  (cl-find-if (lambda (s) (eq kind (plist-get s :kind))) sections))

;;; Normal cases

(ert-deftest test-mcp-hub-build-detail-sections-status-always-present ()
  "The status section is always present, even on an otherwise-empty
connection."
  (let* ((conn (mcp-test-make-fake-connection))
         (sections (mcp-hub--build-detail-sections conn t))
         (status (mcp-test--section-of-kind sections 'status)))
    (should status)
    (should (eq t (plist-get status :running)))
    (should (eq 'http (plist-get status :connection-type)))))

(ert-deftest test-mcp-hub-build-detail-sections-running-flag-propagates ()
  "`running-p' nil shows up as `:running nil' in the status section."
  (let ((sections (mcp-hub--build-detail-sections
                   (mcp-test-make-fake-connection) nil)))
    (should-not (plist-get (mcp-test--section-of-kind sections 'status)
                           :running))))

(ert-deftest test-mcp-hub-build-detail-sections-server-info-present-when-set ()
  "When the connection has `mcp--server-info', a `server-info' section
appears with the info plist."
  (let* ((conn (mcp-test-make-fake-connection
                :server-info '(:name "demo-srv" :version "1.0")))
         (sections (mcp-hub--build-detail-sections conn t))
         (info-section (mcp-test--section-of-kind sections 'server-info)))
    (should info-section)
    (should (equal '(:name "demo-srv" :version "1.0")
                   (plist-get info-section :info)))))

;;; Boundary cases

(ert-deftest test-mcp-hub-build-detail-sections-empty-slots-skipped ()
  "Sections for absent / empty data are not emitted at all (the
renderer would otherwise insert empty headings)."
  (let ((sections (mcp-hub--build-detail-sections
                   (mcp-test-make-fake-connection) t)))
    (should-not (mcp-test--section-of-kind sections 'server-info))
    (should-not (mcp-test--section-of-kind sections 'tools))
    (should-not (mcp-test--section-of-kind sections 'resources))
    (should-not (mcp-test--section-of-kind sections 'template-resources))
    (should-not (mcp-test--section-of-kind sections 'prompts))
    (should-not (mcp-test--section-of-kind sections 'roots))))

(ert-deftest test-mcp-hub-build-detail-sections-tools-resources-prompts ()
  "Tools, resources, and prompts sections each appear when their slot
is populated, carrying the items verbatim."
  (let* ((conn (mcp-test-make-fake-connection
                :tools [(:name "t1")]
                :resources [(:uri "x://r")]
                :prompts [(:name "p1")]))
         (sections (mcp-hub--build-detail-sections conn t)))
    (should (equal [(:name "t1")]
                   (plist-get (mcp-test--section-of-kind sections 'tools) :items)))
    (should (equal [(:uri "x://r")]
                   (plist-get (mcp-test--section-of-kind sections 'resources) :items)))
    (should (equal [(:name "p1")]
                   (plist-get (mcp-test--section-of-kind sections 'prompts) :items)))))

(ert-deftest test-mcp-hub-build-detail-sections-roots-present-with-strings-and-plists ()
  "Roots — both string and plist shapes — pass through to the section's
`:items'."
  (let* ((conn (mcp-test-make-fake-connection
                :roots '("/tmp" (:uri "file:///x" :name "X"))))
         (sections (mcp-hub--build-detail-sections conn t))
         (roots (mcp-test--section-of-kind sections 'roots)))
    (should roots)
    (should (equal '("/tmp" (:uri "file:///x" :name "X"))
                   (plist-get roots :items)))))

(ert-deftest test-mcp-hub-build-detail-sections-order-stable ()
  "Sections are emitted in a stable order so the renderer's layout
matches the docstring's description."
  (let* ((conn (mcp-test-make-fake-connection
                :server-info '(:name "x")
                :tools [(:name "t")]
                :resources [(:uri "r")]
                :template-resources [(:uriTemplate "tpl")]
                :prompts [(:name "p")]
                :roots '("/")))
         (sections (mcp-hub--build-detail-sections conn t)))
    (should (equal '(status server-info tools resources
                     template-resources prompts roots)
                   (mapcar (lambda (s) (plist-get s :kind)) sections)))))

;;; test-mcp-hub-build-detail-sections.el ends here
