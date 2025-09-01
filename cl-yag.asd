(defsystem cl-yag
  :name "cl-yag"
  :author "Solene Rapenne"
  :version "0.1"
  :maintainer "Spenser Truex <truex@equwal.com>"
  :license "GNU GPLv3.0"
  :description "Simple Static Site Generator for arbitrary files and targets."
  :serial t
  :components ((:file "packages")
               (:file "generators-util")
               (:file "generators/html")
               (:file "generators/gopher")
               (:file "generators/gemini")
               (:file "generator-aux-pre")
               (:file "data/articles")
               (:file "generator-aux")
               ))
