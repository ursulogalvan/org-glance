;;; org-glance.el --- org-mode traversing. Fast and convenient.

;; Copyright (C) 2018 Dmitry Akatov

;; Author: Dmitry Akatov <akatovda@yandex.com>
;; Created: 29 September, 2018
;; Version: 0.1

;; Keywords: org-mode tools
;; Homepage: https://github.com/rails-to-cosmos/org-glance

;; This file is not part of GNU Emacs.

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
;; This package allows you to manage bookmarks and travel around the
;; digital world with an org-mode power behind your shoulders.

;;; Code:

(require 's)
(require 'cl-lib)
(require 'org)
(require 'dash)

(defun org-glance (&rest args)
  "Use optional ARGS to customize your glancing blows:
- SCOPE :: org-file or SCOPE from org-map-entries (org.el)
- PROMPT :: completing read title (default: \"Glance: \")
- SEPARATOR :: completing read entry separator (default: \" → \")
- FILTER :: list or one filter of type lambda/symbol/string to specify entries in completing read.

  Possible default filters:
  - links :: keep entries with link in title
  - encrypted :: keep entries with :crypt: tag

  You can customize default filters by setting org-glance/default-filters variable.
- ACTION :: lambda to call on selected entry
  - if entry has an org-link in title, browse it
  - if entry has HANDLER property, read-eval it
- HANDLER :: property name to read-eval on select (default: \"HANDLER\")

\(fn [:scope SCOPE] [:prompt PROMPT] [:separator SEPARATOR] [:filter FILTER] [:action ACTION] [:handler HANDLER])"
  (let* ((scope     (or (plist-get args :scope)          nil))
         (scope*    (cond ((stringp scope) (list scope)) (t scope)))

         (user-filter (or (plist-get args :filter)       (lambda () t)))
         (filter-predicates (org-glance--filter-predicates user-filter))

         (outline-path-ignore (or (plist-get args :outline-path-ignore) nil))
         (handler   (or (plist-get args :handler)        "HANDLER"))
         (prompt    (or (plist-get args :prompt)         "Glance: "))
         (separator (or (plist-get args :separator)      " → "))
         (action    (or (plist-get args :action)         (lambda nil (org-glance--handle-entry handler)))))

    (cl-flet ((traverse ()
                        (let* ((mark (point-marker))
                               (title (s-join separator (-difference (org-get-outline-path t) outline-path-ignore))))
                          (when (every (lambda (fp) (if fp (funcall fp) nil)) filter-predicates)
                            (cons title mark)))))

      (org-glance/compl-map prompt (org-map-entries #'traverse nil scope*) action))))

(defun org-glance--handle-entry (handler)
  "Try to handle current org-entry:
1. If there is an org-link, browse it.
2. If not, call HANDLER."
  (cond ((org-match-line (format "^.*%s.*$" org-bracket-link-regexp)) (org-glance/follow-org-link-at-point))
        ((org-entry-get nil handler) (let ((action (read (org-entry-get nil handler))))
                                       (cond ((symbolp action) (read (macroexpand (list 'org-sbe (symbol-name action)))))
                                             (t (eval action)))))))

(defun org-glance/compl-map (prompt entries action)
  "PROMPT org-completing-read on ENTRIES and call ACTION on selected.
If there is only one entry, call ACTION without completing read.
If there is no entries, raise exception."
  (let* ((entries* (remove 'nil entries))
         (choice (cond ((= (length entries*) 1) (caar entries*))
                       ((= (length entries*) 0) (error "Empty set."))
                       (t (org-completing-read prompt entries*))))
         (marker (cdr (assoc-string choice entries*))))
    (org-goto-marker-or-bmk marker)
    (funcall action)))

(defun org-glance/follow-org-link-at-point ()
  "Browse org-link at point."
  (let ((link (buffer-substring-no-properties
               (save-excursion (org-beginning-of-line) (point))
               (save-excursion (org-end-of-line) (point))))
        (org-link-frame-setup (acons 'file 'find-file org-link-frame-setup)))
    (org-open-link-from-string link)))

(defvar org-glance/default-filters '((links . (lambda () (org-match-line (format "^.*%s.*$" org-bracket-link-regexp))))
                                     (encrypted . (lambda () (seq-intersection (list "crypt") (org-get-tags-at))))))

(defun org-glance--filter-predicates (filter)
  "Factorize FILTER into list of predicates. Acceptable FILTER values:
- list of symbols (possible default filters) and lambdas (custom filters)
- string name of default filter
- symbolic name of default filter
- lambda function with no params called on entry"
  (let* ((predicates (cond ((functionp filter) (list filter))
                           ((symbolp filter) (list (alist-get filter org-glance/default-filters)))
                           ((stringp filter) (list (alist-get (intern filter) org-glance/default-filters)))
                           ((listp filter) (loop for elt in filter
                                                 when (functionp elt) collect elt
                                                 when (symbolp elt)   collect (alist-get elt org-glance/default-filters)
                                                 when (stringp elt)   collect (alist-get (intern elt) org-glance/default-filters)))
                           (t (error "Unable to recognize filter.")))))
    predicates))

(provide 'org-glance)
;;; org-glance.el ends here
