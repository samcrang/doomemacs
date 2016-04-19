;;; module-cc.el --- C, C++, and Objective-C

(use-package cmake-mode
  :mode "CMakeLists\\.txt$"
  :config
  (require 'company-cmake)
  (define-company-backend! cmake-mode (cmake yasnippet)))

(use-package glsl-mode :mode ("\\.glsl\\'" "\\.vert\\'" "\\.frag\\'" "\\.geom\\'"))

(use-package cuda-mode :mode "\\.cuh?$")

(use-package cc-mode
  :defines (c-syntactic-context)
  :functions (c-toggle-electric-state c-toggle-auto-newline
              c-skip-comments-and-strings c-forward-sws c-end-of-macro
              c-font-lock-invalid-string csharp-log c-font-lock-declarators
              c-get-lang-constant c-forward-keyword-clause
              c-fontify-recorded-types-and-refs c-forward-type imenu--split
              c-backward-sws c-determine-limit c-beginning-of-decl-1)
  :commands (c-mode c++-mode objc-mode java-mode)
  :init
  (associate! objc-mode :match "\\.mm$")
  (add-hook 'c-initialization-hook 'narf|init-c/c++-settings)
  (add-hook 'c++-mode-hook 'highlight-numbers-mode)
  (add-hook 'c++-mode-hook 'narf|init-c++-C11-highlights)
  :config
  (setq c-tab-always-indent nil
        c-electric-flag nil)

  (map! :map c-mode-base-map
        (:localleader :nv ";" 'narf/append-semicolon))

  (define-text-object! "<" "<" ">")
  (sp-local-pair '(c-mode c++-mode) "<" ">" :when '(narf/sp-point-is-template-p narf/sp-point-after-include-p))
  (sp-with-modes '(c-mode c++-mode objc-mode java-mode)
    (sp-local-pair "/*" "*/" :post-handlers '(("||\n[i]" "RET") ("| " "SPC")))
    ;; Doxygen blocks
    (sp-local-pair "/**" "*/" :post-handlers '(("||\n[i]" "RET") ("||\n[i]" "SPC")))
    (sp-local-pair "/*!" "*/" :post-handlers '(("||\n[i]" "RET") ("[d-1]< | " "SPC"))))

  (add-hook! (c-mode c++-mode objc-mode)
    (electric-indent-local-mode +1)
    (setq electric-indent-chars '(?\n ?})))

  ;; C/C++
  (advice-add 'c-lineup-arglist :around 'narf/c-lineup-arglist)
  (defun narf/c-lineup-arglist (orig-fun &rest args)
    "Improve indentation of continued C++11 lambda function opened as argument."
    (if (and (eq major-mode 'c++-mode)
             (ignore-errors
               (save-excursion
                 (goto-char (c-langelem-pos langelem))
                 ;; Detect "[...](" or "[...]{". preceded by "," or "(",
                 ;;   and with unclosed brace.
                 (looking-at ".*[(,][ \t]*\\[[^]]*\\][ \t]*[({][^}]*$"))))
        0                           ; no additional indent
      (apply orig-fun args)))

  ;; C++ header files
  (push `(,(lambda () (and (f-ext? buffer-file-name "h")
                      (or (f-exists? (f-swap-ext buffer-file-name "cpp"))
                          (awhen (car-safe (projectile-get-other-files (buffer-file-name) (projectile-current-project-files)))
                            (f-ext? it "cpp")))))
          . c++-mode)
        magic-mode-alist)

  ;; Obj-C
  (push `(,(lambda () (and (f-ext? buffer-file-name "h")
                      (re-search-forward "@\\<interface\\>" magic-mode-regexp-match-limit t)))
          . objc-mode)
        magic-mode-alist)

  (use-package irony
    :config
    (setq irony-server-install-prefix (concat narf-temp-dir "/irony/"))
    (push "-std=c++11" irony-additional-clang-options)

    (require 'irony-eldoc)

    (require 'flycheck-irony)
    (flycheck-irony-setup)

    (require 'company-irony)
    (require 'company-irony-c-headers)
    (define-company-backend! c-mode    (irony-c-headers irony))
    (define-company-backend! c++-mode  (irony-c-headers irony))
    (define-company-backend! objc-mode (irony-c-headers irony))

    ;; some c-mode dervied modes wrongfully trigger these hooks (like php-mode)
    (add-hook! (c-mode c++-mode ojbc-mode)
      (when (memq major-mode '(c-mode c++-mode objc-mode))
        (flycheck-mode +1)
        (irony-mode +1)
        (eldoc-mode +1)
        (irony-eldoc +1)))))

(provide 'module-cc)
;;; module-cc.el ends here
