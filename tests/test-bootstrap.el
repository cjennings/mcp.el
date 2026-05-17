;;; test-bootstrap.el --- Common test initialization for mcp.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Craig Jennings

;; Author: Craig Jennings <c@cjennings.net>

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Shared initialization for all mcp.el test files.
;;
;; Usage: (require 'test-bootstrap (expand-file-name "test-bootstrap.el"))

;;; Code:

(when noninteractive
  (package-initialize))

(require 'ert)
(require 'jsonrpc)

;; Load mcp.el and mcp-hub.el from the parent directory.  Test files can
;; rely on every public symbol from either module being available without
;; their own require/load calls.
(load (expand-file-name "../mcp.el") nil t)
(load (expand-file-name "../mcp-hub.el") nil t)

(provide 'test-bootstrap)
;;; test-bootstrap.el ends here
