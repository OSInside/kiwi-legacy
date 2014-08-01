;; For file names ending with kiwi use the nxml-mode
;; and locate the schemas in kiwi editing directory

(progn
    (add-to-list 'auto-mode-alist '("\\.kiwi" . nxml-mode))
    (eval-after-load 'rng-loc
        '(add-to-list 'rng-schema-locating-files "/usr/share/kiwi/editing/suse-start-kiwi-xmllocator.xml")))
