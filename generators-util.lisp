(in-package #:cl-yag)

(defmacro template(before &body after)
  "Simplify string replacement work in templates."
  `(progn
     (setf output (replace-all output ,before ,@after))))

(defmacro generate(name &body data)
  "Simplify file saving by using the layout system."
  `(progn
     (save-file ,name (generate-layout ,@data))))