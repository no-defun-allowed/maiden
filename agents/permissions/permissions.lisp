#|
 This file is a part of Maiden
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.agents.permissions)

(defun package-short-name (package)
  (loop for min = (package-name package) then (if (< (length name) (length min)) name min)
        for name in (package-nicknames package)
        finally (return min)))

(defgeneric normalize-permission (perm))

(defmethod normalize-permission ((perm list))
  perm)

(defmethod normalize-permission ((perm string))
  (normalize-permission (cl-ppcre:split "[./]+" (string-downcase perm))))

(defmethod normalize-permission ((perm symbol))
  (normalize-permission (string-downcase perm)))

(defmethod normalize-permission ((package package))
  (normalize-permission (package-name package)))

(defmethod normalize-permission ((class standard-class))
  (let ((name (class-name class)))
    (append (normalize-permission (symbol-package name))
            (normalize-permission (symbol-name name)))))

(defmethod normalize-permission ((cmd maiden-commands:command-event))
  (normalize-permission (class-of cmd)))

(defmethod normalize-permission ((client client))
  (list* (string-downcase (name client))
         (normalize-permission (class-of client))))

(defmethod normalize-permission ((user user))
  (list* (string-downcase (name user))
         (normalize-permission (client user))))

(defun separate-grant-deny (perms)
  (let ((grant ())
        (deny ()))
    (loop for perm in perms
          for norm = (normalize-permission perm)
          do (if (equal (car norm) "!")
                 (push (cdr norm) deny)
                 (push norm grant)))
    (values grant deny)))

(defun perm-match-p (perm &rest matches)
  (let ((perm (normalize-permission perm)))
    (multiple-value-bind (grant deny) (separate-grant-deny matches)
      (flet ((branch-match (allow)
               (loop for p on perm
                     for a on allow
                     always (or (string-equal (car a) "*")
                                (string-equal (car p) (car a)))
                     finally (return (not (cdr a))))))
        (and (some #'branch-match grant)
             (notany #'branch-match deny))))))

(defun user-perm (user &optional client type)
  (typecase user
    (user (normalize-permission user))
    (T (list (string-downcase user) (string-downcase client) (string-downcase type)))))

(defun administrator-p (user &optional client type)
  (with-storage ('permissions)
    (perm-match-p (user-perm user client type) (value :administrators))))

(defun add-administrator (name &optional client type)
  (with-storage ('permissions)
    (pushnew (user-perm name client type) (value :administrators)
             :test #'perm-match-p)))

(defun remove-administrator (name &optional client type)
  (with-storage ('permissions)
    (setf (value :default-permissions)
          (remove (user-perm name client type) (value :administrators)
                  :test (lambda (a b) (perm-match-p b a))))))

(defun add-default-permission (perm)
  (with-storage ('permissions)
    (pushnew (normalize-permission perm) (value :default-permissions)
             :test #'perm-match-p)))

(defun remove-default-permission (perm)
  (with-storage ('permissions)
    (setf (value :default-permissions)
          (remove (normalize-permission perm) (value :default-permissions)
                  :test (lambda (a b) (perm-match-p b a))))))

(defun allowed-p (user perm)
  (with-storage ('permissions)
    (or (and (authenticated-p user) (administrator-p user))
        (perm-match-p perm (append (data-value :permissions user)
                                   (value :default-permissions))))))

(defun check-allowed (user perm)
  (unless (allowed-p user perm)
    ;; FIXME
    (error "I cannot let you do that.")))

(defmacro with-permission ((user permission) &body body)
  `(when (allowed-p ,user ,permission)
     ,@body))

(define-consumer permissions (agent)
  ())

(define-handler (permissions check command-event) (c ev dispatch-event)
  :before '(:main)
  :class deeds:locally-blocking-handler
  (check-allowed (user dispatch-event) ev))