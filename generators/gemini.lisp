(defun generate-rss-gemini(article)
  (format nil "gemini://~a/articles/~a.gmi"
          (getf *config* :gemini-path)
          (article-id article)))

;; generate a gemini index file
(defun generate-gemini-index(articles)
  (let ((output (load-file "templates/gemini_head.tpl")))
    (dolist (article articles)
      (setf output
	    (string
	     (concatenate 'string output
                          (format nil "=> ~a/articles/~a.gmi ~a-~2,'0d-~2,'0d ~a~%"
                                  (getf *config* :gemini-path)
                                  (article-id article)
                                  (getf (article-date article) :year)
                                  (getf (article-date article) :monthnumber)
                                  (getf (article-date article) :daynumber)
                                  (article-title article))))))
    output))

;; we do all the gemini capsule
(defun create-gemini-capsule()

  ;; produce the index.gmi file
  (save-file (concatenate 'string "output/gemini/" (getf *config* :gemini-index))
             (generate-gemini-index *articles*))

  ;; produce a tag list menu
  (let* ((directory-path "output/gemini/_tags_/")
         (index-path (concatenate 'string directory-path (getf *config* :gemini-index))))
    (ensure-directories-exist directory-path)
    (save-file index-path
               (let ((output (load-file "templates/gemini_head.tpl")))
                 (loop for tag in
                      ;; sort tags per articles in it
                      (sort (articles-by-tag) #'>
                            :key #'(lambda (x) (length (getf x :value))))
                    do
                      (setf output
	                    (string
	                     (concatenate
                              'string output
                              (format nil "=> ~a/~a/index.gmi ~a ~d~%"
                                      (getf *config* :gemini-path)
                                      (getf tag :name)
                                      (getf tag :name)
                                      (length (getf tag :value)))))))
                 output)))

  ;; produce each tag gemini index
  (loop for tag in (articles-by-tag) do
       (let* ((directory-path (concatenate 'string "output/gemini/" (getf tag :NAME) "/"))
              (index-path (concatenate 'string directory-path (getf *config* :gemini-index)))
              (articles-with-tag (loop for article in *articles*
                                    when (member (article-id article) (getf tag :VALUE) :test #'equal)
                                    collect article)))
         (ensure-directories-exist directory-path)
         (save-file index-path (generate-gemini-index articles-with-tag))))

  ;; produce each article file (adding some headers)
  (loop for article in *articles*
     do
       (with-converter
	   (let ((id (article-id article)))
	     (save-file (format nil "output/gemini/articles/~a.gmi" id)
                        (format nil "~{~a~}"
                                (list
                                 "Title : " (article-title article) #\Newline
                                 "Author: " (article-author article) #\Newline
                                 "Date  : " (date-format (getf *config* :date-format) (article-date article)) #\Newline
                                 "Tags  : " (article-tag article) #\Newline #\Newline
		                 (load-file (format nil "data/~d~d" id (converter-extension converter-object))))))))))

(make-generator :key :gemini
                :create-site-fn #'create-gemini-capsule)