Correct. There are no Python modules. `progs` is Scheme only. Python is a plug-in session, so it belongs under Publishing, not under `progs`. The cheat sheet is your mnemonic, not a TeXmacs feature.

## progs

A module is a Scheme file. Scheme is how the editor is extended: commands, keymaps, and menus. Document markup stays in a `.ts` package.

```scheme
(texmacs-module (bvoq tools)
  (:use (generic document-edit)))

(kbd-map
  ("T h ." (make 'theorem)))
```

`menu-bind` defines or replaces a named menu. `menu-extend` appends, which is what a built-in bar needs. `tm-menu` is the dynamic form, `(tm-menu (name) ...)`, and can call `(former)`. `link` reuses a menu already bound. `(=> ...)` is a pulldown, `(-> ...)` a pull-right. `("label" action)` is a text entry. `---` is a separator. `(if pred ...)` and `(when pred ...)` include an entry only when the predicate holds. `(balloon widget "tip")` is the tooltip. `(icon "name.xpm")` is a pixmap button. `(noop)` does nothing. `(insert "text")` pastes. `(make 'strong)` inserts a tag.

A minimal text entry is `("Ctrl+G: clear selection" (noop))`. The string is the label. The form is the action. A balloon is only the hover tip.

### Special modules

Two files are loaded by TeXmacs itself, if they exist. They are not packages.

`progs/my-init-texmacs.scm` runs once, at startup, after `init-texmacs.scm`. Keymaps, menus, and the user-icons bar go here. Built-in menus are loaded lazily, so a stock menu may not exist yet. Extend it. Do not replace it.

`progs/my-init-buffer.scm` runs on every buffer, new or opened, after `init-buffer.scm`. Per-document policy only. Attach the user package to a new buffer and mark it clean, or an empty file asks to be saved:

```scheme
(when (buffer-newly-created? (current-buffer))
  (add-style-package "bvoqs-package")
  (buffer-pretend-saved (current-buffer)))
```

The string is the file stem. `packages/bvoqs-package.ts` is the package `"bvoqs-package"`. The source comment in that file, "bvoq's user comments.", is not the name. Without `buffer-newly-created?`, opening an old file rewrites its style list. `init-style` replaces the main style. `set-style-list` keeps the list and can append a package.

The user-icons bar is `texmacs-extra-icons`, bound from `my-init-texmacs.scm`, and shown by View → User provided icons. That menu item toggles icon bar 3. The editor fills the bar with `(horizontal (link texmacs-extra-icons))` on resume and on every menu update, so the link is live. `my-init-texmacs.scm` is `exec_file`'d once, after `init-texmacs.scm`. Plug-ins initialize before that file. A `menu-bind` of `texmacs-extra-icons` there replaces the empty bar. A later `menu-bind` of the same name replaces it again. Restart TeXmacs after editing the init file.

If a button only makes sense when the package is on the document, gate it with `(if (has-style-package? "bvoqs-package") ...)`. `has-style-package?` is true when the package is on the style list or pulled in by something that is. `style-has?` is the other predicate, for a d.t.d. name such as `"env-float-dtd"`.

The other three bars are extended, not replaced. `texmacs-main-icons` is file, edit, browse. `texmacs-mode-icons` follows the mode. `texmacs-focus-icons` follows the cyan tag. Add with `menu-extend`, and gate with `(if (in-math?) ...)`, `(if (in-graphics?) ...)`, or the package predicate.

### Cheat sheet

This is not built-in help. It is a private mnemonic, cooked up to remember commands: a pulldown of inert lines, linked from the user bar. It is not a paragraph on the bar.

```scheme
(menu-bind cheat-sheet
  ("Ctrl+Space twice, then again: word, then parent" (noop))
  ("Ctrl+G: clear selection" (noop))
  ---
  ("Image width 0.6par, height empty: keep aspect" (noop)))

(menu-bind texmacs-extra-icons
  >>
  (=> (balloon (icon "tm_open.xpm") "Open a personal file")
      (link bvoqs-files-menu))
  (=> (balloon "Cheatsheet" "Cheat sheet")
      (link cheat-sheet)))
```

A pixmap has no letters. `(icon "tm_help.xpm")` is a real pixmap, and an icon-only button is easy to miss: the bar looks like a short empty strip. The word on the bar is a string label. `(balloon "Cheatsheet" "Cheat sheet")` is that label plus the hover tip. `(=> "Cheatsheet" ...)` is the same pulldown without a tip. `(text "Cheatsheet")` is a menu item, not a label, and it is not a button. The fonted label is `(text <font> "Cheatsheet")`, two arguments.

`//` is a gap of 5. `///` is a gap of 15. Neither grows. `>>` is the spring that pushes the following items to the right. `>>>` is the same spring with a larger minimum. `===` is a vertical gap.

`load-browse-buffer` opens a url and switches to it when that buffer is already open. A url that starts with `$TEXMACS_HOME_PATH` is rooted, so it is not resolved against the current document. `url-resolve` with `"r"` turns it into the file. `load-document` opens a new window when the preference is one window per buffer. The open icon is `tm_open.xpm`, the same pixmap as Load a file. Its pulldown loads `progs/my-init-texmacs.scm`, `progs/my-init-buffer.scm`, `packages/bvoqs-package.ts`, `styles/bvoqs-beamer.ts`, and `styles/bvoqs-exam.ts`.

`styles/bvoqs-beamer.ts` and `styles/bvoqs-exam.ts` are principal styles. `<use-package|beamer|bvoqs-package>` and `<use-package|exam|bvoqs-package>` pull the built-in style and the package, so `has-style-package?` is true for a document that uses either style.

Test in Insert → Session → Scheme. A session dies on quit. Keep the forms in `my-init-texmacs.scm`.

## Publishing

Personal files are the default. To publish, move the extension into a plug-in. Unused subdirectories are omitted.

```text
plugins/pluginname/doc/pluginname.en.tm
plugins/pluginname/doc/pluginname-abstract.en.tm
plugins/pluginname/progs/init-pluginname.scm
plugins/pluginname/misc/pixmaps/
```

The init file is Scheme, and it must configure the plug-in, or it is not detected:

```scheme
(plugin-configure pluginname
  (:require #t))
```

`:require` is the load predicate. `#t` means always. Menus can live in that file or in another Scheme module it loads. The two `doc/` files are the help entry and its abstract. Packages and styles of the plug-in go in `plugins/pluginname/packages` and `plugins/pluginname/styles`.

Python is not a module language but for very extensive plugins you might need to add python as a dependency. Not recommended unless necessary.

### Shapes plugin

I want to in the future write a shapes plugin for large arrows, speech bubbles and more.

```scheme
(menu-extend graphics-insert-menu
  (if (in-graphics?)
      (-> "Shapes" (link bvoq-shapes-menu))))

(menu-extend graphics-insert-icons
  (if (in-graphics?)
      (=> (balloon (icon "bvoq-shape.xpm") "Shapes")
          (link bvoq-shapes-menu))))
```
