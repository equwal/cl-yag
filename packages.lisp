
(in-package :cl-yag-system)

(defpackage #:html-generator
   (:use #:cl)
   (:export #:create-html-site
            #:generate-rss-html))

(defpackage #:gopher-generator
   (:use #:cl)
   (:export #:create-gopher-hole
            #:generate-rss-gopher))

(defpackage #:cl-yag
   (:use #:cl)
   (:import-from #:html-generator

                 #:create-html-site
                 #:generate-rss-html)
   (:import-from #:gopher-generator

                 #:create-gopher-hole
                 #:generate-rss-gopher)
   (:export #:generate-site))
