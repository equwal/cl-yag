;;;; GLOBAL VARIABLES

(defun quit ()
 "quit portably (ripped from Sharp-CLOCC)"
  #+abcl (ext:quit)
  #+allegro (excl:exit)
  #+clisp (ext:quit)
  #+cmu (ext:quit)
  #+cormanlisp (win32:exitprocess)
  #+ecl (ext:quit)
  #+gcl (lisp:bye)
  #+lispworks (lw:quit)
  #+lucid (lcl:quit)
  #+sbcl (sb-ext:quit)
  #-(or allegro clisp cmu cormanlisp gcl lispworks lucid sbcl)
  (error 'not-implemented :proc (list 'quit))
  )


(defparameter *articles* '())
(defparameter *converters* '())
(defparameter *days* '("Monday" "Tuesday" "Wednesday" "Thursday"
                       "Friday" "Saturday" "Sunday"))
(defparameter *months* '("January" "February" "March" "April"
                         "May" "June" "July" "August" "September"
                         "October" "November" "December"))
(defparameter *generators* '())

;; structure to store links
(defstruct article title tag date id tiny author rawdate converter)
(defstruct converter name command extension)
(defstruct generator key create-site-fn)

;; put these somewhere else and automagically get them pushed to *generators*

;;;; FUNCTIONS

(require 'asdf)

(load "config.lisp")

(defun get-day-of-week(day month year)
  "Return the day of the week."
  (multiple-value-bind
   (second minute hour date month year day-of-week dst-p tz)
   (decode-universal-time (encode-universal-time 0 0 0 day month year))
   (declare (ignore second minute hour date month year dst-p tz))
   day-of-week))

(defun date-parse(date)
  "Parse a date into components."
  (if (= 8 (length date))
      (let* ((year     (parse-integer date :start 0 :end 4))
             (monthnum (parse-integer date :start 4 :end 6))
             (daynum   (parse-integer date :start 6 :end 8))
             (day      (nth (get-day-of-week daynum monthnum year) *days*))
             (month    (nth (- monthnum 1) *months*)))
        (list
         :dayname day
         :daynumber daynum
         :monthname month
         :monthnumber monthnum
         :year year))
    nil))

(defun post(&optional &key title tag date id (tiny nil) (author (getf *config* :webmaster)) (converter nil))
  (push (make-article :title title
                      :tag tag
                      :date (date-parse date)
                      :rawdate date
                      :tiny tiny
                      :author author
                      :id id
                      :converter converter)
        *articles*))

(defun converter(&optional &key name command extension)
  "Add a converter to the list of those available."
  (setf *converters*
        (append
         (list name
               (make-converter :name name
                               :command command
                               :extension extension))
         *converters*)))

;; we add a generator to the list of available ones
(defun make-generator(&optional &key key create-site-fn)
  (push (make-generator :key key
                       :create-site-fn create-site-fn)
        *generators*))

;; Load data from metadata and config
(load "data/articles.lisp")
(setf *articles* (reverse *articles*))

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

(defun load-file(path)
  "Load a file as a string. We escape ~ to avoid failures with format."
  (if (probe-file path)
      (with-open-file (stream path)
        (let ((contents (make-string (file-length stream))))
          (read-sequence contents stream)
          contents))
    (progn
      (format t "ERROR : file ~a not found. Aborting~%" path)
      (quit))))

(defun save-file(path data)
  "Save a string to a file."
  (with-open-file (stream path :direction :output :if-exists :supersede)
		  (write-sequence data stream)))

(defmacro template(before &body after)
  "Simplify string replacement work in templates."
  `(progn
     (setf output (replace-all output ,before ,@after))))

(defmacro prepare(template &body code)
  "Simplify the declaration of a new page type by loading a template and executing code."
  `(progn
     (let ((output (load-file ,template)))
       ,@code
       output)))


(defmacro with-converter(&body code)
  "Get the converter object for an article and execute code in that context."
  `(progn
     (let ((converter-name (or (article-converter article)
			     (getf *config* :default-converter))))
       (let ((converter-object (getf *converters* converter-name)))
	 ,@code))))

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

(defun date-format(format date)
  "Format a date using the given format string with template substitutions."
  (let ((output format))
    (template "%DayName"     (getf date :dayname))
    (template "%DayNumber"   (format nil "~2,'0d" (getf date :daynumber)))
    (template "%MonthName"   (getf date :monthname))
    (template "%MonthNumber" (format nil "~2,'0d" (getf date :monthnumber)))
    (template "%Year"        (write-to-string (getf date :year )))
    output))

(defmacro generate(name &body data)
  "Simplify file saving by using the layout system."
  `(progn
     (save-file ,name (generate-layout ,@data))))

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
  (loop for i in *generators*
        do (if (getf *config* (getf i :key))
             (funcall (function (getf i :create-site-fn))))))

;; all the generators
(load "generators/html.lisp")
(load "generators/gopher.lisp")
(load "generators/gemini.lisp")

;;;; EXECUTION

(generate-site)

(quit)
