;; View → User provided icons is icon bar 3:
;; (horizontal (link texmacs-extra-icons)).
;; >> is the spring. A string is the visible label. A pixmap is not.

(menu-bind cheat-sheet
  ("Ctrl+Space twice, then again: word, then parent" (noop))
  ("Ctrl+G: clear selection" (noop))
  ---
  ("Image width 0.6par, height empty: keep aspect" (noop)))

(menu-bind bvoqs-files-menu
  ("my-init-texmacs.scm"
   (load-browse-buffer
    (url-resolve "$TEXMACS_HOME_PATH/progs/my-init-texmacs.scm" "r")))
  ("my-init-buffer.scm"
   (load-browse-buffer
    (url-resolve "$TEXMACS_HOME_PATH/progs/my-init-buffer.scm" "r")))
  ---
  ("bvoqs-package.ts"
   (load-browse-buffer
    (url-resolve "$TEXMACS_HOME_PATH/packages/bvoqs-package.ts" "r")))
  ("bvoqs-beamer.ts"
   (load-browse-buffer
    (url-resolve "$TEXMACS_HOME_PATH/styles/bvoqs-beamer.ts" "r")))
  ("bvoqs-exam.ts"
   (load-browse-buffer
    (url-resolve "$TEXMACS_HOME_PATH/styles/bvoqs-exam.ts" "r"))))

(menu-bind texmacs-extra-icons
  >>
  (=> (balloon (icon "tm_open.xpm") "Open a personal file")
      (link bvoqs-files-menu))
  (=> (balloon "Cheatsheet" "Cheat sheet")
      (link cheat-sheet)))
