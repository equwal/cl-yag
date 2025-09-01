
(in-package #:cl-yag)

(defun generate-rss-html(article)
  (format nil "~d~d-~d.html"
          (getf *config* :url)
          (date-format "%Year-%MonthNumber-%DayNumber"
                       (article-date article))
          (article-id article)))

(defun use-converter-to-html(filename &optional (converter-name nil))
  "Generate HTML file from source file using the converter associated with the post."
  (let* ((converter-object (getf *converters*
                                 (or converter-name
			             (getf *config* :default-converter))))
         (output           (converter-command converter-object))
         (src-file (format nil "~a~a" filename (converter-extension converter-object)))
         (dst-file (format nil "temp/data/~a.html" filename ))
         (full-src-file (format nil "data/~a" src-file)))
      ;; skip generating if the destination exists
      ;; and is more recent than source
      (unless (and
               (probe-file dst-file)
               (>=
                (file-write-date dst-file)
                (file-write-date full-src-file)))
        (ensure-directories-exist "temp/data/")
        (template "%IN" src-file)
        (template "%OUT" dst-file)
        (format t "~a~%" output)
        (uiop:run-program output))))

;; We do all the website
(defun create-html-site()

  ;; produce each article file
  (loop for article in *articles*
     do
     ;; use the article's converter to get html code of it
       (use-converter-to-html (article-id article) (article-converter article))

	(generate  (format nil "output/html/~d-~d.html"
			   (date-format "%Year-%MonthNumber-%DayNumber"
					(article-date article))
			   (article-id article))
		   (create-article article :tiny nil)
		   :title (concatenate 'string (getf *config* :title) " : " (article-title article))))

  ;; produce index.html
  (generate "output/html/index.html" (generate-semi-mainpage))

  ;; produce index-titles.html where there are only articles titles
  (generate "output/html/index-titles.html" (generate-semi-mainpage :no-text t))

  ;; produce index file for each tag
  (loop for tag in (articles-by-tag) do
       (generate (format nil "output/html/tag-~d.html" (getf tag :NAME))
		  (generate-tag-mainpage (getf tag :VALUE))))

  ;; generate rss gopher in html folder if gopher is t
  (when (getf *config* :gopher)
    (save-file "output/html/rss-gopher.xml" (generate-rss #'generate-rss-gopher)))

  ;;(generate-file-rss)
  (save-file "output/html/rss.xml" (generate-rss #'generate-rss-html)))

;; html generation of index homepage
(defun generate-semi-mainpage(&key (tiny t) (no-text nil))
  (apply #'concatenate 'string
         (loop for article in *articles* collect
              (create-article article :tiny tiny :no-text no-text))))
;; html generation of a tag homepage
(defun generate-tag-mainpage(articles-in-tag)
  (apply #'concatenate 'string
         (loop for article in *articles*
            when (member (article-id article) articles-in-tag :test #'equal)
            collect (create-article article :tiny t))))

;; return a html string
;; produce the code of a whole page with title+layout with the parameter as the content
(defun generate-layout(body &optional &key (title nil))
  (prepare "templates/layout.tpl"
	   (template "%%Title%%" (if title title (getf *config* :title)))
	   (template "%%Tags%%" (get-tag-list))
	   (template "%%Body%%" body)
	   output))

;; simplify the file saving by using the layout
(defmacro generate(name &body data)
  `(progn
     (save-file ,name (generate-layout ,@data))))


;; generates the html of only one article
;; this is called in a loop to produce the homepage
(defun create-article(article &optional &key (tiny t) (no-text nil))
  (prepare "templates/article.tpl"
	   (template "%%Author%%" (let ((author (article-author article)))
                                    (or author (getf *config* :webmaster))))
	   (template "%%Date%%"   (date-format (getf *config* :date-format)
					       (article-date article)))
           (template "%%Raw-Date%%" (article-rawdate article))
           (template "%%Title%%"  (article-title article))
           (template "%%Id%%"     (article-id article))
	   (template "%%Tags%%"   (get-tag-list-article article))
	   (template "%%Date-Url%%"  (date-format "%Year-%MonthNumber-%DayNumber"
						  (article-date article)))
	   (template "%%Text%%"   (if no-text
				      ""
                                      (if (and tiny (article-tiny article))
                                          (format nil "<p>~a</p>" (article-tiny article))
                                          (load-file (format nil "temp/data/~d.html" (article-id article))))))))

;; generates the html of the whole list of tags
(defun get-tag-list()
  (apply #'concatenate 'string
         (mapcar #'(lambda (item)
                     (prepare "templates/one-tag.tpl"
                              (template "%%Name%%" (getf item :name))))
                 (articles-by-tag))))

;; generates the html of the list of tags for an article
(defun get-tag-list-article(&optional article)
  (apply #'concatenate 'string
         (mapcar #'(lambda (item)
                     (prepare "templates/one-tag.tpl" (template "%%Name%%" item)))
                 (split-str (article-tag article)))))

;; generate the list of tags
(defun articles-by-tag()
  (let ((tag-list))
    (loop for article in *articles* do
	  (when (article-tag article) ;; we don't want an error if no tag
	    (loop for tag in (split-str (article-tag article)) do ;; for each word in tag keyword
		  (setf (getf tag-list (intern tag "KEYWORD")) ;; we create the keyword is inexistent and add ID to :value
			(list
			 :name tag
			 :value (push (article-id article) (getf (getf tag-list (intern tag "KEYWORD")) :value)))))))
    (loop for i from 1 to (length tag-list) by 2 collect ;; removing the keywords
	  (nth i tag-list))))



