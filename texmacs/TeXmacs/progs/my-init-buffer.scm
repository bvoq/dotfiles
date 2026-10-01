;; New documents use the dotfiles package. Existing files keep their own style list.
(when (buffer-newly-created? (current-buffer))
  (set-style-list (append (get-style-list) '("dotfiles")))
  (buffer-pretend-saved (current-buffer)))
