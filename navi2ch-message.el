;;; navi2ch-message.el --- write message module for navi2ch

;; Copyright (C) 2000 by Navi2ch Project

;; Author: Taiki SUGAWARA <taiki@users.sourceforge.net>
;; Keywords: network, 2ch

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Code:
(provide 'navi2ch-message)
(defvar navi2ch-message-ident "$Id$")

(eval-when-compile (require 'cl))

(require 'navi2ch)

(defvar navi2ch-message-aa-map nil)
(unless navi2ch-message-aa-map
  (let ((map (make-sparse-keymap "Type ? for further options")))
    ;; define-key $B$G(B t $B$K%^%C%W$G$-$J$$$N$G!#!#!#(B
    (navi2ch-set-keymap-default-binding map 'navi2ch-message-self-insert-aa)
    (define-key map "?" 'navi2ch-message-insert-aa)
    (setq navi2ch-message-aa-map map)))

(defvar navi2ch-message-mode-map nil)
(unless navi2ch-message-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map navi2ch-global-map)
    (define-key map "\C-c\C-c" 'navi2ch-message-send-message)
    (define-key map "\C-c\C-k" 'navi2ch-message-exit)
    (define-key map "\C-c\C-y" 'navi2ch-message-cite-original)
    (define-key map "\C-cy" 'navi2ch-message-cite-original-from-number)
    (define-key map "\C-c\C-i" 'navi2ch-message-insert-backup)
    (define-key map "\C-c\C-b" 'navi2ch-base64-insert-file)
    (define-key map "\et" 'navi2ch-toggle-offline)
    (define-key map navi2ch-message-aa-prefix-key navi2ch-message-aa-map)
    (setq navi2ch-message-mode-map map)))

(defvar navi2ch-message-mode-menu-spec
  '("Message"
    ["Toggle offline" navi2ch-toggle-offline]
    ["Send message" navi2ch-message-send-message]
    ["Cancel" navi2ch-message-exit]
    ["Cite message" navi2ch-message-cite-original]))

(defvar navi2ch-message-buffer-name "*navi2ch message*")
(defvar navi2ch-message-backup-buffer-name "*navi2ch message backup*")
(defvar navi2ch-message-current-article-buffer nil)
(defvar navi2ch-message-current-article nil)
(defvar navi2ch-message-current-board nil)
(defvar navi2ch-message-new-message-p nil)
(defvar navi2ch-message-window-configuration nil)
(defvar navi2ch-message-header-separator "----------------\n")

(defvar navi2ch-message-paragraph-separate
  (concat (regexp-quote navi2ch-message-header-separator) "\\|"
	  ">\\|"			; $B0zMQ(B
	  "[ \t]*$")			; $B6u9T(B
  "*`navi2ch-message-mode' $B$G;HMQ$5$l$k(B `paragraph-separate'$B!#(B")

(defvar navi2ch-message-paragraph-start
  navi2ch-message-paragraph-separate
  "*`navi2ch-message-mode' $B$G;HMQ$5$l$k(B `paragraph-start'$B!#(B")

(defun navi2ch-message-write-message (board article &optional new sage)
  (if (and (get-buffer navi2ch-message-buffer-name)
	   (or navi2ch-message-always-pop-message
	       (not (navi2ch-message-kill-message))))
      (navi2ch-message-pop-message-buffer)
    (setq navi2ch-message-window-configuration
	  (current-window-configuration))
    (delete-other-windows)
    (split-window-vertically)
    (other-window 1)
    (setq navi2ch-message-current-article article)
    (setq navi2ch-message-current-board board)
    (setq navi2ch-message-new-message-p new)
    (setq navi2ch-message-current-article-buffer
	  (if new nil (current-buffer)))
    (switch-to-buffer (get-buffer-create navi2ch-message-buffer-name))
    (navi2ch-message-mode)
    (erase-buffer)
    (navi2ch-message-insert-header new sage)
    (navi2ch-set-mode-line-identification)
    (run-hooks 'navi2ch-message-setup-message-hook)
    (when sage
      (run-hooks 'navi2ch-message-setup-sage-message-hook))))

(defun navi2ch-message-pop-message-buffer ()
  (interactive)
  (let ((buf (get-buffer navi2ch-message-buffer-name)))
    (when buf
      (cond ((get-buffer-window buf)
             (select-window (get-buffer-window buf)))
            (buf
             (setq navi2ch-message-window-configuration
                   (current-window-configuration))
             (delete-other-windows)
             (split-window-vertically)
             (other-window 1)
             (switch-to-buffer navi2ch-message-buffer-name))))))

(defun navi2ch-message-insert-backup ()
  (interactive)
  (when (get-buffer navi2ch-message-backup-buffer-name)
    (let ((inhibit-read-only t))
      (erase-buffer))
    (insert-buffer navi2ch-message-backup-buffer-name)))

(defun navi2ch-message-insert-header (new sage)
  (and sage (setq sage "sage"))
  (when new
    (insert "Subject: \n"))
  (insert "From: "
	  (or (cdr (assq 'name navi2ch-message-current-article))
	      (cdr (assoc (cdr (assq 'id navi2ch-message-current-board))
			  navi2ch-message-user-name-alist))
	      navi2ch-message-user-name "") "\n"
	  "Mail: "
	  (or sage
	      (cdr (assq 'mail navi2ch-message-current-article))
	      navi2ch-message-mail-address "")
	  "\n"
	  (navi2ch-propertize navi2ch-message-header-separator
			      'read-only t
			      'front-sticky t 'rear-nonsticky t)))

(defun navi2ch-message-cleanup-message ()
  (save-excursion
    (when navi2ch-message-cleanup-trailing-whitespace
      (goto-char (point-min))
      (when (re-search-forward navi2ch-message-header-separator nil t)
	(while (re-search-forward "[ \t]+$" nil t)
	  (replace-match ""))))
    (when navi2ch-message-cleanup-trailing-newline
      (goto-char (point-min))
      (if (re-search-forward "[ \t\n]+\\'" nil t)
	  (replace-match "")))))

(defun navi2ch-message-send-message ()
  (interactive)
  (when (or (not navi2ch-message-ask-before-send)
            (y-or-n-p "send message?"))
    (run-hooks 'navi2ch-message-before-send-hook)
    (navi2ch-message-cleanup-message)
    (save-excursion
      (let (subject from mail message)
        (goto-char (point-min))
        (when navi2ch-message-new-message-p
	  (re-search-forward "^Subject: ?\\(.*\\)" nil t)
          (setq subject (match-string 1)))
        (re-search-forward "^From: ?\\(.*\\)")
        (setq from (match-string 1))
        (when navi2ch-message-remember-user-name
          (setq navi2ch-message-user-name from))
        (when (not navi2ch-message-new-message-p)
          (navi2ch-message-set-name from))
        (re-search-forward "^Mail: ?\\(.*\\)")
        (setq mail (match-string 1))
	(when (not navi2ch-message-new-message-p)
	  (navi2ch-message-set-mail mail))
        (forward-line 2)
        (setq message (buffer-substring-no-properties (point) (point-max)))
        (let ((buffer (current-buffer))
	      (inhibit-read-only t))
          (save-excursion
            (set-buffer (get-buffer-create
                         navi2ch-message-backup-buffer-name))
	    (erase-buffer)
	    (insert-buffer buffer)
            (bury-buffer)))
	(when navi2ch-message-trip
	  (setq from (concat from "#" navi2ch-message-trip)))
	(let ((board navi2ch-message-current-board)
	      (article navi2ch-message-current-article)
	      result)
	  ; $B"-(Bresult$B$r8E$$;EMM$KLa$7$?!#(Bspid$B$O!"(Bnavi2ch-multibbs.el$B$N(B
	  ; $B"-(B   navi2ch-2ch-send-message $B$G=hM}$9$k!#(B
	  (setq result (navi2ch-multibbs-send-message
			from mail message subject board article))
	  (when result
	    (message "waiting new message...")
	    (sleep-for navi2ch-message-wait-time)
	    (message "%s%s" (current-message) "done")
	    (save-excursion
	      (if navi2ch-message-new-message-p
		  (progn
		    (set-buffer navi2ch-board-buffer-name)
		    (navi2ch-board-sync))
		(when (buffer-live-p navi2ch-message-current-article-buffer)
		  (set-buffer navi2ch-message-current-article-buffer)
		  (navi2ch-article-sync navi2ch-message-force-sync))))))))
    (run-hooks 'navi2ch-message-after-send-hook)
    (navi2ch-message-exit 'after-send)))

(defun navi2ch-message-set-name (name)
  (save-excursion
    (if (buffer-live-p navi2ch-message-current-article-buffer)
	(set-buffer navi2ch-message-current-article-buffer)
      (navi2ch-article-view-article navi2ch-message-current-board
				    navi2ch-message-current-article
				    nil))
    (setq navi2ch-article-current-article
	  (navi2ch-put-alist 'name name
			     navi2ch-article-current-article))))

(defun navi2ch-message-set-mail (mail)
  (let ((case-fold-search t))
    (unless (string-match "sage" mail)
      (save-excursion
	(if (buffer-live-p navi2ch-message-current-article-buffer)
	    (set-buffer navi2ch-message-current-article-buffer)
	  (navi2ch-article-view-article navi2ch-message-current-board
					navi2ch-message-current-article
					nil))
	(setq navi2ch-article-current-article
	      (navi2ch-put-alist 'mail mail
				 navi2ch-article-current-article))))))

(defun navi2ch-message-cite-original (&optional arg)
  "$B0zMQ$9$k(B"
  (interactive "P")
  (navi2ch-message-cite-original-from-number
   (save-excursion
     (set-buffer (navi2ch-article-current-buffer))
     (navi2ch-article-get-current-number))
   arg))

(defun navi2ch-message-cite-original-from-number (num &optional arg)
  "$BHV9f$rA*$s$G!"0zMQ$9$k!#(B"
  (interactive "ninput number: \nP")
  (let (same msg board article)
    (save-excursion
      (set-buffer (navi2ch-article-current-buffer))
      (setq msg (cdr (assq 'data (navi2ch-article-get-message num))))
      (setq article navi2ch-article-current-article)
      (setq board navi2ch-article-current-board)
      (setq same (and (string-equal (cdr (assq 'id board))
				    (cdr (assq 'id navi2ch-message-current-board)))
		      (string-equal (cdr (assq 'artid article))
				    (cdr (assq 'artid navi2ch-message-current-article))))))
    (if same
	(insert ">>" (number-to-string num) "\n")
      (insert (navi2ch-article-to-url board article num num nil) "\n"))
    (unless arg
      (set-mark (point))
      (let ((point (point)))
	(insert msg "\n")
	(string-rectangle point (point) navi2ch-message-cite-prefix)))))

(defun navi2ch-message-exit (&optional after-send)
  (interactive)
  (run-hooks 'navi2ch-message-exit-hook)
  (when (navi2ch-message-kill-message after-send)
    ;; $B$`$%!"(Bset-window-configuration $B$r;H$&$H%+!<%=%k0LCV$,JQ$K$J$k$s$+$$!)(B
    (set-window-configuration navi2ch-message-window-configuration)
    (when (and (not navi2ch-message-new-message-p)
               after-send)
      (if (buffer-live-p navi2ch-message-current-article-buffer)
	  (set-buffer navi2ch-message-current-article-buffer)
	(navi2ch-article-view-article navi2ch-message-current-board
				      navi2ch-message-current-article
				      navi2ch-message-force-sync))
      (navi2ch-article-load-number))))

(defun navi2ch-message-kill-message (&optional no-ask)
  (when (or no-ask
	    (not navi2ch-message-ask-before-kill)
	    (y-or-n-p "kill current message?"))
    (kill-buffer navi2ch-message-buffer-name)
    t))

(easy-menu-define navi2ch-message-mode-menu
  navi2ch-message-mode-map
  "Menu used in navi2ch-message"
  navi2ch-message-mode-menu-spec)

(defun navi2ch-message-setup-menu ()
  (easy-menu-add navi2ch-message-mode-menu))

(defun navi2ch-message-fill-paragraph (arg)
  (interactive)
  (let ((before (point)))
    (save-excursion
      (forward-paragraph)
      (or (bolp) (newline 1))
      (let ((end (point))
	    (beg (progn (backward-paragraph) (point))))
	(when (eq beg (point-min))
	  (forward-line 3)
	  (setq beg (point)))
	(goto-char before)
	(fill-region-as-paragraph beg end arg)
	t))))

(defun navi2ch-message-mode ()
  "\\{navi2ch-message-mode-map}"
  (interactive)
  (kill-all-local-variables)
  (setq major-mode 'navi2ch-message-mode)
  (setq mode-name "Navi2ch Message")
  (set (make-local-variable 'fill-paragraph-function)
       'navi2ch-message-fill-paragraph)
  (set (make-local-variable 'paragraph-separate)
       navi2ch-message-paragraph-separate)
  (set (make-local-variable 'paragraph-start)
       navi2ch-message-paragraph-start)
  (set (make-local-variable 'auto-fill-inhibit-regexp)
       "^[A-Z][^: \n\t]+:")		; $B%X%C%@(B
  (use-local-map navi2ch-message-mode-map)
  (navi2ch-message-setup-menu)
  (run-hooks 'navi2ch-message-mode-hook)
  (force-mode-line-update))

(defun navi2ch-message-self-insert-aa ()
  "$B:G8eF~NO$7$?%-!<$K$7$?$,$C$F(B AA $B$rF~NO$9$k!#(B"
  (interactive)
  (let ((char last-command-char) aa)
    (if (and (navi2ch-char-valid-p char)
	     (setq aa (cdr (assoc (string last-command-char)
				  (append navi2ch-message-aa-alist
					  navi2ch-message-aa-default-alist)))))
	(insert aa)
    (ding))))

(defun navi2ch-message-insert-aa-list ()
  (let ((aa-width navi2ch-message-popup-aa-width)
	(nl nil))
    (dolist (elt (append navi2ch-message-aa-alist
			 navi2ch-message-aa-default-alist))
      (let* ((key (car elt))
	     (val (cdr elt))
	     string width)
	(when (and (stringp key) (stringp val))
	  (setq string (format "%s: %s" (key-description key) val)
		width (string-width string))
	  (if (> width aa-width)
	      (setq string (concat (truncate-string-to-width string
							     (- aa-width 3))
				   "...")))
	  (insert (truncate-string-to-width string aa-width nil ?\ )
		  (if nl "\n" " "))
	  (setq nl (not nl)))))))

(defun navi2ch-message-popup-aa-list ()
  "aa $B$N%j%9%H$rI=<($9$k!#(B"
  (interactive)
  (let ((buffer (get-buffer-create "*AA List*"))
	(continue t)
	c)
    (unwind-protect
	(save-window-excursion
	  (with-current-buffer buffer
	    (erase-buffer)
	    (navi2ch-message-insert-aa-list)
	    (goto-char (point-min))
	    (pop-to-buffer (current-buffer))
	    (while continue
	      (setq c (navi2ch-read-char
		       "Type key for AA (or SPC forward, DEL back): "))
	      (cond
	       ((memq c '(?\  ?\C-v))
		(ignore-errors (scroll-up)))
	       ((memq c '(?\C-h ?\177))
		(ignore-errors (scroll-down)))
	       ((eq c ?\C-l)
		(recenter))
	       (t (setq continue nil)))))
	  c)
      (if (bufferp buffer)
	  (kill-buffer buffer)))))

(defun navi2ch-message-insert-aa ()
  "aa $B$rF~NO$9$k!#(B"
  (interactive)
  (let* ((char (navi2ch-message-popup-aa-list))
	 (aa (cdr (assoc (char-to-string char)
			 (append navi2ch-message-aa-alist
				 navi2ch-message-aa-default-alist)))))
    (if (stringp aa)
	(insert aa)
      (ding))))

(run-hooks 'navi2ch-message-load-hook)
;;; navi2ch-message.el ends here
