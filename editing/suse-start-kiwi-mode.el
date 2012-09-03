(setq auto-mode-alist
(cons '("\\.\\(xml\\|kiwi\\|xsl\\|rng\\|xhtml\\)\\'" . nxml-mode)
auto-mode-alist))

(eval-after-load 'rng-loc
'(add-to-list 'rnc-schema-locating-files "/usr/share/kiwi/editing/suse-start-kiwi-xmllocator.xml"))
