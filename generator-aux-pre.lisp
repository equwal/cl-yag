(in-package #:cl-yag)

;;;; GLOBAL VARIABLES

(defvar *config* '())
(defvar *generators* '())

(defparameter *articles* '())
(defparameter *converters* '())
(defparameter *days* '("Monday" "Tuesday" "Wednesday" "Thursday"
                       "Friday" "Saturday" "Sunday"))
(defparameter *months* '("January" "February" "March" "April"
                         "May" "June" "July" "August" "September"
                         "October" "November" "December"))

;; structure to store links
(defstruct article title tag date id tiny author rawdate converter)
(defstruct converter name command extension)
(defstruct generator key create-site-fn)

;;;; FUNCTIONS

(require 'asdf)

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

;; we add a generator to the list of available ones
(defun register-generator(&key key create-site-fn)
  (push (make-generator :key key
                       :create-site-fn create-site-fn)
        *generators*))