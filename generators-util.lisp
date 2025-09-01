<<<<<<< HEAD
(in-package #:cl-yag)
=======

(in-package :cl-yag)

(defmacro generate(name &body data)
  "Simplify file saving by using the layout system."
  `(progn
     (save-file ,name (generate-layout ,@data))))
>>>>>>> abstract-protocols

(defmacro template(before &body after)
  "Simplify string replacement work in templates."
  `(progn
     (setf output (replace-all output ,before ,@after))))

<<<<<<< HEAD
(defmacro generate(name &body data)
  "Simplify file saving by using the layout system."
  `(progn
     (save-file ,name (generate-layout ,@data))))
=======
(defmacro with-converter(&body code)
  "Get the converter object for an article and execute code in that context."
  `(progn
     (let ((converter-name (or (article-converter article)
			     (getf *config* :default-converter))))
       (let ((converter-object (getf *converters* converter-name)))
	 ,@code))))

>>>>>>> abstract-protocols
