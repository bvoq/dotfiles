;; View → User provided icons is icon bar 3:
;; (horizontal (link texmacs-extra-icons)).
;; >> is the spring. A string is the visible label. A pixmap is not.

(menu-bind cheat-sheet
  ("Alt+Up: focus up" (noop))
  ("Alt+Down: focus down" (noop))
  ("Cmd+Up: bring to front" (noop))
  ("Cmd+Down: send to back" (noop))
  ("Cmd+Shift+Up: step forward" (noop))
  ("Cmd+Shift+Down: step back" (noop))
  ("Cmd+Alt+V: unformatted paste" (noop)))

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
  ((balloon "One slide" "Turn off show all slides")
   (hide-other-slides))
  ((balloon "Swap left" "Swap this presentation with the one on the left")
   (screens-move #f))
  ((balloon "Swap right" "Swap this presentation with the one on the right")
   (screens-move #t))
  (=> (balloon (icon "tm_open.xpm") "Open a personal file")
      (link bvoqs-files-menu))
  (=> (balloon "Cheatsheet" "Cheat sheet")
      (link cheat-sheet)))

(menu-extend presentation-popup-menu
  ---
  ("One slide" (hide-other-slides)))

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


;; Slide swap: permute the current screens child with its sibling.
(define (screens-tree)
  (tree-innermost (lambda (t) (tree-is? t 'screens)) #t))

(define (screens-move forwards?)
  (and-with t (screens-tree)
    (let* ((i (tree-down-index t))
           (n (tree-arity t))
           (j (if forwards? (+ i 1) (- i 1))))
      (when (and (>= i 0) (< i n) (>= j 0) (< j n))
        (let* ((here (tree-ref t i))
               (rel (tree-cursor-path here))
               (child (tree-copy here)))
          (tree-remove! t i 1)
          (tree-insert! t j (list child))
          (if (list? rel)
              (apply tree-go-to (cons* t j rel))
              (tree-go-to t j :start))
          (tree-focus t)
          (notify-change 2))))))

;; Bug where you cannot unselect view all slides:
(define (expand-rendering? s)
  (in? s '("paper" "book" "panorama" "slideshow")))

(define (hide-other-slides)
  (for-each
   (lambda (t)
     (when (and (tree? t)
                (== (tree-arity t) 1)
                (tree-is? (tree-ref t 0) 'document))
       (tree-remove-node! t 0)
       (tree-assign-node! t 'screens)
       (let ((seen? #f))
         (for-each
          (lambda (c)
            (when (tree-func? c 'slide)
              (let ((here? (and (cursor-tree)
                                (tree-inside? (cursor-tree) c))))
                (when here? (set! seen? #t))
                (tree-assign-node! c (if here? 'shown 'hidden)))))
          (tree-children t))
         (when (not seen?)
           (and-with c (tree-ref t 0)
             (when (tree-func? c 'slide)
               (tree-assign-node! c 'shown)))))))
   (select (buffer-tree) '(:* slideshow)))
  (when (expand-rendering? (get-init-page-rendering))
    (init-page-rendering "screen"))
  (notify-change 2))


;; bvoqs-beamer's theme is metal. beamer still includes bluish, and the
;; theme menu reads the style list, which does not name that include.
(import-from (dynamic fold-edit) (generic document-style))

(tm-define (style-includes? x y)
  (:require (and (== x "bvoqs-beamer") (== y "metal")))
  #t)

(tm-define (current-beamer-theme)
  (:require (and (nnull? (get-style-list))
                 (== (car (get-style-list)) "bvoqs-beamer")
                 (not (list-find (cdr (get-style-list))
                                 (cut in? <> (beamer-themes))))))
  "metal")

;; True when a title body starts with the senf marker. concat and document
;; wrappers, and empty strings, are skipped. The marker expands to nothing.
(tm-define (bvoqs-senf-leading? t)
  (:secure #t)
  (cond ((tm-func? t 'senf) "true")
        ((and (tm-compound? t) (tm-in? t '(concat document)))
         (let loop ((i 0))
           (if (>= i (tm-arity t))
               "false"
               (let ((c (tm-ref t i)))
                 (if (and (tm-atomic? c) (== (tm->string c) ""))
                     (loop (+ i 1))
                     (bvoqs-senf-leading? c))))))
        (else "false")))

;; In-draw mode for keybindings
(define (in-draw?)
  (and (in-graphics?) (== (get-env "preamble") "false")))

(delayed
  (lazy-keyboard-force)
  (kbd-map
    ("A-up" (move-focus #f))
    ("A-down" (move-focus #t)))
  (kbd-map
    ("M-A-v" (clipboard-paste-import "verbatim" "primary")))
  (kbd-map
    (:mode in-draw?)
    ("M-up" (graphics-zmove 'foreground))
    ("M-down" (graphics-zmove 'background))
    ("M-S-up" (graphics-zmove 'closer))
    ("M-S-down" (graphics-zmove 'farther))))
