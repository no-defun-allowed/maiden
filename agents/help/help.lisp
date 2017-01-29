#|
 This file is a part of Maiden
 (c) 2016 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.maiden.agents.help)

(define-consumer help (agent)
  ((start-time :initarg :start-time :initform (get-universal-time) :accessor start-time)))

(defun find-consumer (core name)
  (loop for consumer in (consumers core)
        do (when (or (matches name consumer)
                     (string-equal name (name consumer))
                     (string-equal name (class-name (class-of consumer))))
             (return consumer))))

(define-command (help about) (c ev &rest about)
  :command "help"
  (let ((command (format NIL "~{~(~a~)~^ ~}" about)))
    (cond ((string= command "")
           (reply ev "See 'help about' for general information. Try 'help X' to search for or retrieve information about a command."))
          ((string= command "uptime")
           (relay ev 'about-uptime))
          ((string= command "about")
           (relay ev 'about-self))
          ((find-command-invoker command)
           (relay ev 'about-command :command command))
          ((find-consumer (core ev) command)
           (relay ev 'about-consumer :consumer command))
          (T
           (relay ev 'about-term :term command)))))

(define-command (help about-self) (c ev)
  :command "about self"
  (reply ev "I'm an installation of the Maiden ~a chat framework. The core is running ~d consumer~:p, with ~d command~:p registered. I have been running for approximately ~a."
         (asdf:component-version (asdf:find-system :maiden T))
         (length (consumers (core ev)))
         (length (list-command-invokers))
         (format-relative-time (- (get-universal-time) (start-time c)))))

(define-command (help about-uptime) (c ev)
  :command "uptime"
  (reply ev "I have been running for approximately ~a since ~a."
         (format-relative-time (- (get-universal-time) (start-time c)))
         (format-absolute-time (start-time c))))

(define-command (help about-command) (c ev command)
  :command "about command"
  (let ((invoker (find-command-invoker command))
        (*print-case* :downcase))
    (unless invoker
      (reply ev "No such command found."))
    (reply ev "Command Syntax: ~a ~{~a~^ ~}~%~
                   Documentation:  ~:[None.~;~:*~a~]"
           (prefix invoker) (lambda-list invoker) (docstring invoker))))

(define-command (help about-consumer) (c ev consumer)
  :command "about consumer"
  (let ((consumer (find-consumer (core ev) consumer)))
    (unless consumer
      (error "No consumer of that name or ID found on the current core."))
    (unless (documentation (class-of consumer) T)
      (error "No documentation for ~a is available." (name consumer)))
    (reply ev "~a" (documentation (class-of consumer) T))))

(define-command (help about-term) (c ev term)
  :command "search"
  (let ((ranks (sort (loop for command in (list-command-invokers)
                           for prefix = (prefix command)
                           collect (list prefix (maiden-commands::levenshtein-distance prefix term)))
                     #'< :key #'second)))
    (reply ev "I found the following commands: ~{~a~^, ~}"
           (loop for (command rank) in ranks
                 repeat 10
                 collect command))))