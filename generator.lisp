;;;; GLOBAL VARIABLES

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

;; return the day of the week
(defun get-day-of-week(day month year)
  (multiple-value-bind
   (second minute hour date month year day-of-week dst-p tz)
   (decode-universal-time (encode-universal-time 0 0 0 day month year))
   (declare (ignore second minute hour date month year dst-p tz))
   day-of-week))

;; parse the date to
(defun date-parse(date)
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

;; we add a converter to the list of the one availables
(defun converter(&optional &key name command extension)
  (setf *converters*
        (append
         (list name
               (make-converter :name name
                               :command command
                               :extension extension))
         *converters*)))

;; load data from metadata and load config
(load "data/articles.lisp")
(setf *articles* (reverse *articles*))

;; common-lisp don't have a replace string function natively
(defun replace-all (string part replacement &key (test #'char=))
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

;; common-lisp don't have a split string function natively
(defun split-str(text &optional (separator #\Space))
  "this function split a string with separator and return a list"
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

;; load a file as a string
;; we escape ~ to avoid failures with format
(defun load-file(path)
  (if (probe-file path)
      (with-open-file (stream path)
        (let ((contents (make-string (file-length stream))))
          (read-sequence contents stream)
          contents))
    (progn
      (format t "ERROR : file ~a not found. Aborting~%" path)
      (quit))))

;; save a string in a file
(defun save-file(path data)
  (with-open-file (stream path :direction :output :if-exists :supersede)
		  (write-sequence data stream)))

;; simplify the str replace work
(defmacro template(before &body after)
  `(progn
     (setf output (replace-all output ,before ,@after))))

;; simplify the declaration of a new page type
(defmacro prepare(template &body code)
  `(progn
     (let ((output (load-file ,template)))
       ,@code
       output)))


;; get the converter object of "article"
(defmacro with-converter(&body code)
  `(progn
     (let ((converter-name (if (article-converter article)
			       (article-converter article)
			     (getf *config* :default-converter))))
       (let ((converter-object (getf *converters* converter-name)))
	 ,@code))))

;; generate the html file from the source file
;; using the converter associated with the post
(defun use-converter-to-html(filename &optional (converter-name nil))
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

;; format the date
(defun date-format(format date)
  (let ((output format))
    (template "%DayName"     (getf date :dayname))
    (template "%DayNumber"   (format nil "~2,'0d" (getf date :daynumber)))
    (template "%MonthName"   (getf date :monthname))
    (template "%MonthNumber" (format nil "~2,'0d" (getf date :monthnumber)))
    (template "%Year"        (write-to-string (getf date :year )))
    output))

;; xml generation of the items for the rss
(defun generate-rss-item (fn)
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


;; Generate the rss xml data
(defun generate-rss(fn)
  (prepare "templates/rss.tpl"
	   (template "%%Description%%" (getf *config* :description))
	   (template "%%Title%%" (getf *config* :title))
	   (template "%%Url%%" (getf *config* :url))
	   (template "%%Items%%" (generate-rss-item fn))))

; This is function called when running the tool
(defun generate-site()
  (loop for i in *generators*
        do (if (getf *config* (getf i :key))
             (funcall (function (getf i :create-site-fn))))))

;; all the generators
(load "generators/html.lisp")
(load "generators/gopher.lisp")



;;;; EXECUTION

(generate-site)

(quit)
