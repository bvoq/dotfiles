;; New, unnamed documents use the bvoqs package.
(when (not (buffer-has-name? (current-buffer)))
  (add-style-package "bvoqs-package")
    (buffer-pretend-saved (current-buffer)))
