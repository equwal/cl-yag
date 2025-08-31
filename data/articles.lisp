;; MIND: The tilde character "~" must be escaped like this '~~' to use it as a literal.

(defvar *config*
  (list
   :webmaster       "Your autor name here"
   :title           "Your website's title."
   :description     "Yet another website on the net"
   :url             "https://my.website/~~user/"        ;; the trailing slash is mandatory! RSS links will fail without it. Notice the '~~' to produce a literal '~'
   :rss-item-number 10                                  ;; limit total amount of items in RSS feed to 10
   :date-format "%DayNumber %MonthName %Year"           ;; format for date %DayNumber %DayName %MonthNumber %MonthName %Year
   :default-converter :markdown2
   :html   t                                            ;; 't' to enable export to a html website / 'nil' to disable
   :gopher t                                            ;; 't' to enable export to a gopher website / 'nil' to disable
   :gopher-path      "/user"                            ;; absolute path of your gopher directory
   :gopher-server    "my.website"                       ;; hostname of the gopher server
   :gopher-port      "70"                               ;; tcp port of the gopher server, 70 usually
   :gopher-format "[~d|~a|~a|~a|~a]~%"                  ;; menu format (geomyidae)
   :gopher-index "index.gph"                            ;; menu file   (geomyidae)
   ;; :gopher-format "~d~a	~a	~a	~a~%"   ;; menu format (gophernicus and others)
   ;; :gopher-index "gophermap"                         ;; menu file (gophernicus and others)
   ))

;; Define Your Webpage

(converter :name :markdown  :extension ".md"  :command "peg-markdown -t html -o %OUT data/%IN")
(converter :name :markdown2 :extension ".md"  :command "multimarkdown -t html -o %OUT data/%IN")
(converter :name :org-mode  :extension ".org"
	   :command (concatenate 'string
				 "emacs data/%IN --batch --eval '(with-temp-buffer (org-mode) "
				 "(insert-file \"%IN\") (org-html-export-as-html nil nil nil t)"
				 "(princ (buffer-string)))' --kill | tee %OUT"))

;; Define your articles and their display-order on the website below.
;; Display Order is 'lifo', i.e. the top entry in this list gets displayed as the topmost entry.
;; 
;; An Example Of A Minimal Definition:
;; (post :id "4" :date "2015-12-31" :title "Happy new year" :tag "news")

;; An Example Of A Definitions With Options:
;; (post :id "4" :date "2015-05-04" :title "The article title" :tag "news" :author "Me" :tiny "Short description for home page")
;;
;; A Note On Keywords:
;; :author  can be omitted.   If so, it's value gets replaced by the value of :webmaster.
;; :tiny    can be omitted.   If so, the article's full text gets displayed on the all-articles view. (most people don't want this.)


(post :title "test"
      :id "t" :date "20171214" :tag "cl-yag" :converter :org-mode)

;; CSS
(post :title "CSS For cl-yag"
      :id "css" :date "20171202" :tag "cl-yag"
      :author "lambda" :tiny "Read more")

;; README
(post :title "README"
      :id "README" :date "20171202" :tag "cl-yag"
      :author "lambda" :tiny "Read cl-yag's README")

;; 1
(post :title "My first post"
      :id "1" :date "20160429" :tag "pony"
      :tiny "This is the first message" :author "Solène")
