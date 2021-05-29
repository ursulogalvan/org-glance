(require 'org-glance-module)

(org-glance-module-import lib.core.metastore)

(cl-defun org-glance-headline:by-id (id)
  "Get org-element headline by ID."
  (or
   (cl-loop for vid in (org-glance-view:ids)
      for metastore = (->> vid
                        org-glance-view
                        org-glance-view-metadata-location
                        org-glance-metastore:read)
      for headline = (gethash id metastore)
      when headline
      do (return (org-glance-metastore:deserialize headline)))
   ;; headline not found
   (org-glance-headline-not-found "%s. Try to update view or make sure the headline was not deleted" id)))

(cl-defun org-glance-headline:search-buffer (headline)
  "Search buffer for HEADLINE and return its point.
Raise `org-glance-headline-not-found` error on fail.''"
  (let ((points (org-element-map (org-element-parse-buffer 'headline) 'headline
                  (lambda (hl) (when (org-glance-headline:eq hl headline)
                            (org-element-property :begin hl))))))
    (unless points
      (org-glance-headline-not-found "Headline not found in file %s: %s" file headline))

    (when (> (length points) 1)
      (warn "Headline ID %s not unique" (org-glance-headline:id headline)))

    (car points)))

(cl-defun org-glance-headline:visit (id)
  (let* ((headline (org-glance-headline:by-id id))
         ;; extract headline filename
         (file (org-element-property :file headline))
         ;; cache file buffer
         (buffer (get-file-buffer file)))

    (cond ((file-exists-p file) (find-file file))
          (t (org-glance-db-outdated "File not found: %s" file)))

    ;; we are now at headline file, let's remove restrictions
    (widen)

    ;; search for headline in buffer
    (goto-char (org-glance-headline:search-buffer headline))
    (org-glance-headline:expand-parents)
    (org-overview)
    (org-cycle 'contents)))

(org-glance-module-provide)
