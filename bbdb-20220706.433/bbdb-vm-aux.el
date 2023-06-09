;;; bbdb-vm-aux.el --- aux parts of BBDB interface to VM -*- lexical-binding: t -*-

;; Copyright (C) 1991, 1992, 1993 Jamie Zawinski <jwz@netscape.com>.
;; Copyright (C) 2010-2022 Roland Winkler <winkler@gnu.org>

;; This file is part of the Insidious Big Brother Database (aka BBDB),

;; BBDB is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; BBDB is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with BBDB.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;; This file contains auxiliary parts of the BBDB interface to VM.
;; See the BBDB info manual for documentation.

;;; Code:

(require 'bbdb)
(require 'bbdb-com)
(require 'bbdb-mua)

(when t     ;Don't require during compilation, since VM might not be installed!
  (require 'vm-autoloads)
  (require 'vm)
  (require 'vm-motion)
  (require 'vm-summary)
  (require 'vm-mime)
  (require 'vm-vars)
  (require 'vm-macro)
  (require 'vm-message)
  (require 'vm-misc))

(declare-function vm-su-from "vm-summary" (m))
(declare-function vm-su-to "vm-summary" (m))
(declare-function vm-su-to-names "vm-summary" (m))
(declare-function vm-su-full-name "vm-summary" (m))
(declare-function vm-add-message-labels "vm-undo" (string count))
(declare-function vm-decode-mime-encoded-words-in-string "vm-mime" (string))

(defvar vm-summary-uninteresting-senders)          ;In vm-vars
(defvar vm-summary-uninteresting-senders-arrow)    ;In vm-vars
(defvar vm-auto-folder-alist)                      ;In vm-vars
(defvar vm-virtual-folder-alist)                   ;In vm-vars
(defvar vm-folder-directory)                       ;In vm-vars
(defvar vm-primary-inbox)                          ;In vm-vars

;; By Alastair Burt <burt@dfki.uni-kl.de>
;; vm 5.40 and newer support a new summary format, %U<letter>, to call
;; a user-provided function.  Use "%-17.17UB" instead of "%-17.17F" to
;; have your VM summary buffers display BBDB's idea of the sender's full
;; name instead of the name (or lack thereof) in the message itself.

;; RW: this is a VM-specific version of `bbdb-mua-summary-unify'
;; which respects `vm-summary-uninteresting-senders'.

;;;###autoload
(defun vm-summary-function-B (m)
  "For VM message M return the BBDB name of the sender.
Respect `vm-summary-uninteresting-senders'."
  (if vm-summary-uninteresting-senders
        (if (let ((case-fold-search t))
              (string-match vm-summary-uninteresting-senders (vm-su-from m)))
            (concat vm-summary-uninteresting-senders-arrow
                    (or (bbdb/vm-alternate-full-name (vm-su-to m))
                        (vm-decode-mime-encoded-words-in-string
                         (vm-su-to-names m))))
          (or (bbdb/vm-alternate-full-name (vm-su-from m))
              (vm-su-full-name m)))
    (or (bbdb/vm-alternate-full-name (vm-su-from m))
        (vm-decode-mime-encoded-words-in-string (vm-su-full-name m)))))

(defun bbdb/vm-alternate-full-name (address)
  (if address
      (let* ((data (bbdb-extract-address-components address))
             (record (car (bbdb-message-search (car data) (cadr data)))))
        (if record
            (or (bbdb-record-xfield record 'mail-name)
                (bbdb-record-name record))))))



;;;###autoload
(defcustom bbdb/vm-auto-folder-headers '("From:" "To:" "CC:")
  "The headers used by `bbdb/vm-auto-folder'.
The order in this list is the order how matching will be performed."
  :group 'bbdb-mua-vm
  :type '(repeat (string :tag "header name")))

;;;###autoload
(defcustom bbdb/vm-auto-folder-field 'vm-folder
  "The xfield which `bbdb/vm-auto-folder' searches for."
  :group 'bbdb-mua-vm
  :type 'symbol)

;;;###autoload
(defcustom bbdb/vm-virtual-folder-field 'vm-virtual
  "The xfield which `bbdb/vm-virtual-folder' searches for."
  :group 'bbdb-mua-vm
  :type 'symbol)

;;;###autoload
(defcustom bbdb/vm-virtual-real-folders nil
  "Real folders used for defining virtual folders.
If nil use `vm-primary-inbox'."
  :group 'bbdb-mua-vm
  :type '(choice (const :tag "Use vm-primary-inbox" nil)
                 (repeat (string :tag "Real folder"))))

;;;###autoload
(defun bbdb/vm-auto-folder ()
  "Add entries to `vm-auto-folder-alist' for the records in BBDB.
For each record that has a `vm-folder' xfield, add an element
\(MAIL-REGEXP . FOLDER-NAME) to `vm-auto-folder-alist'.
The element gets added to the sublists of `vm-auto-folder-alist'
specified in `bbdb/vm-auto-folder-headers'.
MAIL-REGEXP matches the mail addresses of the BBDB record.
The value of the `vm-folder' xfield becomes FOLDER-NAME.
The `vm-folder' xfield is defined via `bbdb/vm-auto-folder-field'.

Add this function to `bbdb-before-save-hook' and your .vm."
  (interactive)
  (let ((records ; Collect BBDB records with a vm-folder xfield.
          (delq nil
                (mapcar (lambda (r)
                          (if (bbdb-record-xfield r bbdb/vm-auto-folder-field)
                              r))
                        (bbdb-records))))
         folder-list folder-name mail-regexp)
    ;; Add (MAIL-REGEXP . FOLDER-NAME) pair to this sublist of `vm-auto-folder-alist'
    (dolist (header bbdb/vm-auto-folder-headers)
      ;; create the folder-list in `vm-auto-folder-alist' if it does not exist
      (unless (setq folder-list (assoc header vm-auto-folder-alist))
        (push (list header) vm-auto-folder-alist)
        (setq folder-list (assoc header vm-auto-folder-alist)))
      (dolist (record records)
        ;; Ignore everything past a comma
        (setq folder-name (car (bbdb-record-xfield-split
                                record bbdb/vm-auto-folder-field))
              ;; quote all the mail addresses for the record and join them
              mail-regexp (regexp-opt (bbdb-record-mail record)))
        ;; In general, the values of xfields are strings (required for editing).
        ;; If we could set the value of `bbdb/vm-auto-folder-field' to a symbol,
        ;; it could be a function that is called with arg record to calculate
        ;; the value of folder-name.
        ;; (if (functionp folder-name)
        ;;     (setq folder-name (funcall folder-name record)))
        (unless (or (string= "" mail-regexp)
                    (assoc mail-regexp folder-list))
          ;; Convert relative into absolute file names using
          ;; `vm-folder-directory'.
          (unless (file-name-absolute-p folder-name)
            (setq folder-name (abbreviate-file-name
                               (expand-file-name folder-name
                                                 vm-folder-directory))))
          ;; nconc modifies the list in place
          (nconc folder-list (list (cons mail-regexp folder-name))))))))

;;;###autoload
(defun bbdb/vm-virtual-folder ()
  "Create `vm-virtual-folder-alist' according to the records in BBDB.
For each record that has a `vm-virtual' xfield, add or modify the
corresponding VIRTUAL-FOLDER-NAME element of `vm-virtual-folder-alist'.

  (VIRTUAL-FOLDER-NAME ((FOLDER-NAME ...)
                        (author-or-recipient MAIL-REGEXP)))

VIRTUAL-FOLDER-NAME is the first element of the `vm-virtual' xfield.
FOLDER-NAME ... are either the remaining elements of the `vm-virtual' xfield,
or `bbdb/vm-virtual-real-folders' or `vm-primary-inbox'.
MAIL-REGEXP matches the mail addresses of the BBDB record.
The `vm-virtual' xfield is defined via `bbdb/vm-virtual-folder-field'.

Add this function to `bbdb-before-save-hook' and your .vm."
  (interactive)
  (let (real-folders mail-regexp folder val tmp)
    (dolist (record (bbdb-records))
      (when (setq val (bbdb-record-xfield-split
                       record bbdb/vm-virtual-folder-field))
        (setq mail-regexp (regexp-opt (bbdb-record-mail record)))
        (unless (string= "" mail-regexp)
          (setq folder (car val)
                real-folders (mapcar
                              (lambda (f)
                                (if (file-name-absolute-p f) f
                                  (abbreviate-file-name
                                   (expand-file-name f vm-folder-directory))))
                              (or (cdr val) bbdb/vm-virtual-real-folders
                                  (list vm-primary-inbox)))
                ;; Either extend the definition of an already defined
                ;; virtual folder or define a new virtual folder
                tmp (or (assoc folder vm-virtual-folder-alist)
                        (car (push (list folder) vm-virtual-folder-alist)))
                tmp (or (assoc real-folders (cdr tmp))
                        (car (setcdr tmp (cons (list real-folders)
                                               (cdr tmp)))))
                tmp (or (assoc 'author-or-recipient (cdr tmp))
                        (car (setcdr tmp (cons (list 'author-or-recipient)
                                               (cdr tmp))))))
          (cond ((not (cdr tmp))
                 (setcdr tmp (list mail-regexp)))
                ((not (string-match (regexp-quote mail-regexp)
                                    (cadr tmp)))
                 (setcdr tmp (list (concat (cadr tmp) "\\|" mail-regexp))))))))))


;; RW: Adding custom labels to VM messages allows one to create,
;; for example, virtual folders.  The following code creates
;; the required labels in a rather simplistic way, checking merely
;; whether the sender's BBDB record uses a certain mail alias.
;; (Note that `bbdb/vm-virtual-folder' can achieve the same goal,
;; yet this requires a second xfield that must be kept up-to-date, too.)
;; To make auto labels yet more useful, the code could allow more
;; sophisticated schemes, too.  Are there real-world applications
;; for this?

;;; Howard Melman, contributed Jun 16 2000
(defcustom bbdb/vm-auto-add-label-list nil
  "List used by `bbdb/vm-auto-add-label' to automatically label VM messages.
Its elements may be strings used both as the xfield value to check for
and as the label to apply to the message.
If an element is a cons pair (VALUE . LABEL), VALUE is the xfield value
to search for and LABEL is the label to apply."
  :group 'bbdb-mua-vm
  :type 'list)

(defcustom bbdb/vm-auto-add-label-field bbdb-mail-alias-field
  "Xfields used by `bbdb/vm-auto-add-label' to automatically label messages.
This is either a single BBDB xfield or a list of xfields that
`bbdb/vm-auto-add-label' uses to check for labels to apply to a message.
Defaults to `bbdb-mail-alias-field' which defaults to `mail-alias'."
  :group 'bbdb-mua-vm
  :type '(choice symbol list))

;;;###autoload
(defun bbdb/vm-auto-add-label (record)
  "Automatically add labels to VM messages.
Add this to `bbdb-notice-record-hook' to check the messages noticed by BBDB.
If the value of `bbdb/vm-auto-add-label-field' in the sender's BBDB record
matches a value in `bbdb/vm-auto-add-label-list' then a VM label will be added
to the message.  Such VM labels can be used, e.g., to mark messages via
`vm-mark-matching-messages' or to define virtual folders via
`vm-create-virtual-folder'

Typically `bbdb/vm-auto-add-label-field' and `bbdb/vm-auto-add-label-list'
refer to mail aliases FOO used with multiple records.  This adds a label FOO
to all incoming messages matching FOO.  Then VM can create a virtual folder
for these messages.  The concept of combining multiple recipients of an
outgoing message in one mail alias thus gets extended to incoming messages
from different senders."
  ;; This could go into `vm-arrived-message-hook' to check messages only once.
  (if (eq major-mode 'vm-mode)
      (let* ((xvalues
              ;; Inspect the relevant fields of RECORD
              (append
               (mapcar (lambda (field)
                         (bbdb-record-xfield-split record field))
                       (cond ((listp bbdb/vm-auto-add-label-field)
                              bbdb/vm-auto-add-label-field)
                             ((symbolp bbdb/vm-auto-add-label-field)
                              (list bbdb/vm-auto-add-label-field))
                             (t (error "Bad value for bbdb/vm-auto-add-label-field"))))))
             ;; Collect the relevant labels from `bbdb/vm-auto-add-label-list'
             (labels
              (delq nil
                    (mapcar (lambda (l)
                              (cond ((stringp l)
                                     (if (member l xvalues)
                                         l))
                                    ((and (consp l)
                                          (stringp (car l))
                                          (stringp (cdr l)))
                                     (if (member (car l) xvalues)
                                         (cdr l)))
                                    (t
                                     (error "Malformed bbdb/vm-auto-add-label-list"))))
                            bbdb/vm-auto-add-label-list))))
        (if labels
            (vm-add-message-labels
             (mapconcat 'identity labels " ") 1)))))

(provide 'bbdb-vm-aux)

;;; bbdb-vm-aux.el ends here
