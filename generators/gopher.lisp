
(in-package #:cl-yag)

(defun generate-rss-gopher(article)
  (format nil "gopher://~a:~d/0~a/article-~a.txt"
          (getf *config* :gopher-server)
          (getf *config* :gopher-port)
          (getf *config* :gopher-path)
          (article-id article)))

;; generate a gopher index file
(defun generate-gopher-index(articles)
  (let ((output (load-file "templates/gopher_head.tpl")))
    (dolist (article articles)
      (setf output
	    (string
	     (concatenate 'string output
                          (format nil (getf *config* :gopher-format)
                                  0 ;;;; gopher type, 0 for text files
				  ;; here we create a 80 width char string with title on the left
				  ;; and date on the right
				  ;; we truncate the article title if it's too large
				  (let ((title (format nil "~80a"
						       (if (< 80 (length (article-title article)))
							   (subseq (article-title article) 0 80)
							   (article-title article)))))
				    (replace title (article-rawdate article) :start1 (- (length title) (length (article-rawdate article)))))
				  (concatenate 'string
                                               (getf *config* :gopher-path) "/article-" (article-id article) ".txt")
				  (getf *config* :gopher-server)
				  (getf *config* :gopher-port)
				  )))))
    output))

;; we do all the gopher hole
(defun create-gopher-hole()

  ;;(generate-file-rss)
  (save-file "output/gopher/rss.xml" (generate-rss #'generate-rss-gopher))

  ;; produce the gophermap file
  (save-file (concatenate 'string "output/gopher/" (getf *config* :gopher-index))
             (generate-gopher-index *articles*))

  ;; produce a tag list menu
  (let* ((directory-path "output/gopher/_tags_/")
         (index-path (concatenate 'string directory-path (getf *config* :gopher-index))))
    (ensure-directories-exist directory-path)
    (save-file index-path
               (let ((output (load-file "templates/gopher_head.tpl")))
                 (loop for tag in
                      ;; sort tags per articles in it
                      (sort (articles-by-tag) #'>
                            :key #'(lambda (x) (length (getf x :value))))
                    do
                      (setf output
	                    (string
	                     (concatenate
                              'string output
                              (format nil (getf *config* :gopher-format)
                                      1 ;; gopher type, 1 for menus
                                      ;; here we create a 72 width char string with title on the left
				      ;; and number of articles on the right
				      ;; we truncate the article title if it's too large
				      (let ((title (format nil "~72a"
						           (if (< 72 (length (getf tag :NAME)))
							       (subseq (getf tag :NAME) 0 80)
							       (getf tag :NAME))))
                                            (article-number (format nil "~d article~p" (length (getf tag :value)) (length (getf tag :value)))))
				        (replace title article-number :start1 (- (length title) (length article-number))))
                                      (concatenate 'string
                                                   (getf *config* :gopher-path) "/" (getf tag :NAME) "/")
				      (getf *config* :gopher-server)
				      (getf *config* :gopher-port)
				      )))))
                 output)))

  ;; produce each tag gophermap index
  (loop for tag in (articles-by-tag) do
       (let* ((directory-path (concatenate 'string "output/gopher/" (getf tag :NAME) "/"))
              (index-path (concatenate 'string directory-path (getf *config* :gopher-index)))
              (articles-with-tag (loop for article in *articles*
                                    when (member (article-id article) (getf tag :VALUE) :test #'equal)
                                    collect article)))
         (ensure-directories-exist directory-path)
         (save-file index-path (generate-gopher-index articles-with-tag))))

  ;; produce each article file (adding some headers)
  (loop for article in *articles*
     do
       (with-converter
	   (let ((id (article-id article)))
	     (save-file (format nil "output/gopher/article-~d.txt" id)
                        (format nil "Title: ~a~%Author: ~a~%Date: ~a~%Tags: ~a~%============~%~%~a"
                                 (article-title article)
                                 (article-author article)
                                 (date-format (getf *config* :date-format) (article-date article))
                                 (article-tag article)
		                         (load-file (format nil "data/~d~d" id (converter-extension converter-object)))))))))
