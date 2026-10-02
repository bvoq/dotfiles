;; New documents use the bvoqs package. Existing files keep their own style list.
(when (buffer-newly-created? (current-buffer))
  (add-style-package "bvoqs-package")
  (buffer-pretend-saved (current-buffer)))
