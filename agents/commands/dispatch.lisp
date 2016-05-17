#|
 This file is a part of Maiden
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.agents.commands)

(define-consumer commands (agent)
  ())

(define-handler (commands processor message-event) (c ev message)
  (let ((command (extract-command ev)))
    (when command
      (multiple-value-bind (match alternatives) (find-matching-command command)
        (cond ((not (null match))
               (handler-case
                   (handler-bind ((error #'invoke-debugger))
                     (funcall (second match) ev (subseq command (1+ (length (first match))))))
                 (command-condition (err)
                   (reply ev "Invalid command: ~a" err))
                 (error (err)
                   (reply ev "Unexpected error: ~a" err))))
              ((null alternatives)
               (reply ev "I don't know what you mean."))
              (T
               (setf alternatives (sort alternatives #'compare-alternatives))
               (reply ev "Unknown command. Possible matches:~10{ ~a~}"
                      (mapcar #'second alternatives))))))))

(defun find-matching-command (message)
  (let ((match NIL)
        (alternatives ()))
    (loop for command in *commands*
          for prefix = (first command)
          for cut = (subseq message 0 (length prefix))
          for distance = (levenshtein-distance prefix cut)
          do (when (and (= 0 distance)
                        (or (null match) (< (length (first match))
                                            (length prefix))))
               (setf match command))
             (when (< distance *alternative-distance-threshold*)
               (push (cons distance command) alternatives)))
    (values match alternatives)))

(defun compare-alternatives (a b)
  (let ((a-distance (first a))
        (a-length (length (second a)))
        (b-distance (first b))
        (b-length (length (second b))))
    (or (< a-distance b-distance)
        (and (= a-distance b-distance)
             (< b-length a-length)))))

(defun levenshtein-distance (a b)
  (cond ((= 0 (length a)) (length b))
        ((= 0 (length b)) (length a))
        (T
         (let ((v0 (make-array (1+ (length b))))
               (v1 (make-array (1+ (length b)))))
           (dotimes (i (length v0)) (setf (aref v0 i) i))
           (dotimes (i (length a) (aref v1 (length b)))
             (incf (aref v1 0))
             (dotimes (j (length b))
               (let ((cost (if (char= (char a i) (char b j)) 0 1)))
                 (setf (aref v1 (1+ j)) (min (1+ (aref v1 j))
                                             (1+ (aref v0 (1+ j)))
                                             (+ cost (aref v0 j))))))
             (dotimes (j (length v0))
               (setf (aref v0 j) (aref v1 j))))))))