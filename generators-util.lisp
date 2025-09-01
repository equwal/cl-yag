
(in-package :cl-yag)

(defmacro generate(name &body data)
  "Simplify file saving by using the layout system."
  `(progn
     (save-file ,name (generate-layout ,@data))))

(defmacro template(before &body after)
  "Simplify string replacement work in templates."
  `(progn
     (setf output (replace-all output ,before ,@after))))

(defmacro with-converter(&body code)
  "Get the converter object for an article and execute code in that context."
  `(progn
     (let ((converter-name (or (article-converter article)
			     (getf *config* :default-converter))))
       (let ((converter-object (getf *converters* converter-name)))
	 ,@code))))

(defmacro prepare(template &body code)
  "Simplify the declaration of a new page type by loading a template and executing code."
  `(progn
     (let ((output (load-file ,template)))
       ,@code
       output)))


(defun load-file(path)
  "Load a file as a string. We escape ~ to avoid failures with format."
  (if (probe-file path)
      (handler-case (with-open-file (stream path :if-exists :supersede :if-does-not-exist :create)
                      (let ((contents (make-string (file-length stream))))
                        (read-sequence contents stream)
                        contents))
        (file-error (condition)
          (cerror "ERROR : file ~a not found. Aborting~%" condition)))
    ))

(defun save-file(path data)
  "Save a string to a file."
  (with-open-file (stream path :direction :output :if-exists :supersede :if-does-not-exist :create)
		  (write-sequence data stream)))

