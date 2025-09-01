(in-package :cl-yag)

(setf *articles* (reverse *articles*)
      *generators* (reverse *generators*))

(defun replace-all (string part replacement &key (test #'char=))
  "Replace all occurrences of PART with REPLACEMENT in STRING."
  (with-output-to-string (out)
    (loop with part-length = (length part)
       for old-pos = 0 then (+ pos part-length)
       for pos = (search part string
                         :start2 old-pos
                         :test test)
       do (write-string string out
                        :start old-pos
                        :end (or pos (length string)))
       when pos do (write-string replacement out)
       while pos)))

(defun split-str(text &optional (separator #\Space))
  "This function splits a string with separator and returns a list."
  (let ((text (concatenate 'string text (string separator))))
    (loop for char across text
       counting char into count
       when (char= char separator)
       collect
       ;; we look at the position of the left separator from right to left
         (let ((left-separator-position (position separator text :from-end t :end (- count 1))))
           (subseq text
                   ;; if we can't find a separator at the left of the current, then it's the start of
                   ;; the string
                   (if left-separator-position (+ 1 left-separator-position) 0)
                   (- count 1))))))


(defun date-format(format date)
  "Format a date using the given format string with template substitutions."
  (let ((output format))
    (template "%DayName"     (getf date :dayname))
    (template "%DayNumber"   (format nil "~2,'0d" (getf date :daynumber)))
    (template "%MonthName"   (getf date :monthname))
    (template "%MonthNumber" (format nil "~2,'0d" (getf date :monthnumber)))
    (template "%Year"        (write-to-string (getf date :year )))
    output))

(defun articles-by-tag()
  "Generate a list of tags with associated article IDs."
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

(defun get-tag-list-article(&optional article)
  "Generate HTML for the list of tags for a specific article."
  (apply #'concatenate 'string
         (mapcar #'(lambda (item)
                     (prepare "templates/one-tag.tpl" (template "%%Name%%" item)))
                 (split-str (article-tag article)))))

(defun get-tag-list()
  "Generate HTML for the complete list of all tags."
  (apply #'concatenate 'string
         (mapcar #'(lambda (item)
                     (prepare "templates/one-tag.tpl"
                              (template "%%Name%%" (getf item :name))))
                 (articles-by-tag))))

(defun create-article(article &optional &key (tiny t) (no-text nil))
  "Generate HTML for a single article. Called in a loop to produce the homepage."
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

(defun generate-layout(body &optional &key (title nil))
  "Return HTML string for a complete page with title and layout, using the parameter as content."
  (prepare "templates/layout.tpl"
	   (template "%%Title%%" (or title (getf *config* :title)))
	   (template "%%Tags%%" (get-tag-list))
	   (template "%%Body%%" body)
	   output))

(defun generate-semi-mainpage(&key (tiny t) (no-text nil))
  "Generate HTML for the index homepage."
  (apply #'concatenate 'string
         (loop for article in *articles* collect
              (create-article article :tiny tiny :no-text no-text))))

(defun generate-tag-mainpage(articles-in-tag)
  "Generate HTML for a tag-specific homepage."
  (apply #'concatenate 'string
         (loop for article in *articles*
            when (member (article-id article) articles-in-tag :test #'equal)
            collect (create-article article :tiny t))))

(defun generate-rss-item (fn)
  "Generate XML for RSS feed items."
  (apply #'concatenate 'string
         (loop for article in *articles*
            for i from 1 to (min (length *articles*) (getf *config* :rss-item-number))
            collect
              (prepare "templates/rss-item.tpl"
                       (template "%%Title%%" (article-title article))
                       (template "%%Description%%" (load-file (format nil "temp/data/~d.html" (article-id article))))
		       (template "%%Date%%" (format nil
						    (date-format "~a, %DayNumber ~a %Year 00:00:00 GMT"
								 (article-date article))
						    (subseq (getf (article-date article) :dayname) 0 3)
						    (subseq (getf (article-date article) :monthname) 0 3)))
                       (template "%%Url%%" (funcall fn article))))))


(defun generate-rss(fn)
  "Generate complete RSS XML data."
  (prepare "templates/rss.tpl"
	   (template "%%Description%%" (getf *config* :description))
	   (template "%%Title%%" (getf *config* :title))
	   (template "%%Url%%" (getf *config* :url))
	   (template "%%Items%%" (generate-rss-item fn))))

(defun generate-site()
  "Main function called when running the site generation tool."
  (loop for gen in *generators*
        do (if (getf *config* (generator-key gen))
             (funcall (generator-create-site-fn gen)))))

;; Note: generate-site is called manually or via `make`
