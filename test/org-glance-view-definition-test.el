(require 'org-glance)

(ert-deftest org-glance-test/def-view ()
  (let ((org-glance-default-scope '("/tmp")))
    (org-glance-let temp-view :as temp-view
                    (let ((scope (org-glance-view-scope temp-view))
                          (db (org-glance-view-db temp-view)))
                      (should (equal scope org-glance-default-scope))
                      (should (string= db (f-join org-glance-db-directory "org-glance-temp-view.el")))))))
