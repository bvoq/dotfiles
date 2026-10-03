;; View → User provided icons is icon bar 3:
;; (horizontal (link texmacs-extra-icons)).
;; >> is the spring. A string is the visible label. A pixmap is not.

(menu-bind cheat-sheet
  ("Alt+Up: focus up" (noop))
  ("Alt+Down: focus down" (noop)))

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

;; The cyan box is the first ancestor focus_search does not skip. The
;; immediate parent is usually one of these, so stepping has to walk past
;; them. set-manual-focus-path does not repaint; THE_FOCUS is 2.
(define (focus-skip? t)
  (or (not t)
      (tree-is-buffer? t)
      (tree-atomic? t)
      (tree-in? t '(document concat tformat table row cell
                    shown hidden shared slide
                    with-screen-color mc-field live-io*))))

(define (focus-step t down?)
  (and t
       (let loop ((u (if down? (tree-down t) (tree-outer t))))
         (and u
              (if (focus-skip? u)
                  (loop (if down? (tree-down u) (tree-outer u)))
                  u)))))

(define (move-focus down?)
  (and-with t (focus-tree)
    (and-with u (focus-step t down?)
      (tree-focus u)
      (notify-change 2))))

(delayed
  (lazy-keyboard-force)
  (kbd-map
    ("A-up" (move-focus #f))
    ("A-down" (move-focus #t))))
