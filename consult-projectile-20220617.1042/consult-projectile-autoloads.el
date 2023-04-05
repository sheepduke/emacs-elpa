;;; consult-projectile-autoloads.el --- automatically extracted autoloads  -*- lexical-binding: t -*-
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "consult-projectile" "consult-projectile.el"
;;;;;;  (0 0 0 0))
;;; Generated autoloads from consult-projectile.el

(autoload 'consult-projectile-switch-to-buffer "consult-projectile" "\
Swith to a project buffer using `consult'." t nil)

(autoload 'consult-projectile-find-dir "consult-projectile" "\
Jump to a project's directory using `consult'." t nil)

(autoload 'consult-projectile-find-file "consult-projectile" "\
Jump to a project's file using `consult'." t nil)

(autoload 'consult-projectile-recentf "consult-projectile" "\
Show a list of recently visited files in a project using `consult'." t nil)

(autoload 'consult-projectile-switch-project "consult-projectile" "\
Switch to a projectile visted before using `consult'." t nil)

(autoload 'consult-projectile "consult-projectile" "\
Create a multi view with projectile integration.   Displays known projects when there are none or the buffers/files accociated with the project.

\(fn &optional SOURCES)" t nil)

(register-definition-prefixes "consult-projectile" '("consult-projectile-"))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; consult-projectile-autoloads.el ends here
