#|
 This file is a part of Maiden
 (c) 2015 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:maiden-user)
(defpackage #:maiden-serialize
  (:nicknames #:org.shirakumo.maiden.modules.serialize)
  (:use #:cl #:maiden)
  (:export
   #:serialize
   #:deserialize))
