;; pages

(function html-escape (s)
          ((((s stringByReplacingOccurrencesOfString:"&" withString:"&amp;")
             stringByReplacingOccurrencesOfString:"<" withString:"&lt;")
            stringByReplacingOccurrencesOfString:">" withString:"&gt;")
           stringByReplacingOccurrencesOfString:"\"" withString:"&quot;"))

(macro require-user ()
       `(unless (set account (get-user SITE))
                (return (RESPONSE redirectResponseToLocation:"/chief/signin"))))

(macro require-authorization ()
       `(progn (set authorization ((REQUEST headers) Authorization:))
               (set parts (authorization componentsSeparatedByString:" "))
               (set credentials (NSString stringWithData:(NSData dataWithBase64EncodedString:(parts 1))
                                                encoding:NSUTF8StringEncoding))
               (set parts (credentials componentsSeparatedByString:":"))
               (set username (parts 0))
               (set password (parts 1))
               (set account (mongo findOne:(dict username:username
                                                 password:(password md5HashWithSalt:PASSWORD_SALT))
                              inCollection:(+ SITE ".users")))
               (unless account (return "unauthorized"))))


(get "/chief"
(puts "get /chief")
(puts ((REQUEST cookies) description))
     (require-user)
     (set apps (mongo findArray:(dict $query:(dict owner_id:(account _id:))
                                    $orderby:(dict name:1))
                   inCollection:(+ SITE ".apps")))
     (set worker-count 0)
     (apps each:
           (do (app)
               (set worker-count (+ worker-count (((app deployment:) workers:) count)))))
     (htmlpage "AgentBox"
               (&& (navbar "Home")
                   (&div class:"row"
                         (&div class:"large-12 columns"
                               (&p "Monitoring " (apps count) " apps. "
                                   "Running " worker-count " instances.")
                               (&h1 "This is AgentBox.")                               
                               )))))

(get "/chief/apps/add"
     (require-user)
     (htmlpage "Add an app"
               (&& (navbar "Add")
                   (&div class:"row"
                         (&div class:"large-12 columns"
                               (&h1 "Add an app")
                               (&form action:"/chief/apps/add/"
                                          id:"edit" method:"post"
                                      (&dl (&dt (&label for:"app_name" "App name"))
                                           (&dd (&input id:"app_name" name:"name" size:"40" type:"text"))
                                           (&dt (&label for:"app_domains" "App domains"))
                                           (&dd (&input id:"app_domains" name:"domains" size:"40" type:"text"))
                                           (&dt (&label for:"app_workers" "App workers"))
                                           (&dd (&select id:"app_workers" name:"workers"
                                                         ((array 1 2 3 4 5 6 7 8 9 10) map:
                                                          (do (i) (&option value:i i selected:(eq i 3))))))
                                           (&dt (&label for:"app_description" "Description"))
                                           (&dd (&textarea id:"app_description" name:"description"
                                                         rows:"5" cols:"60")))
                                      (&input name:"save" type:"submit" value:"Save")
                                      " or "
                                      (&a href:"/chief" "Cancel")))))))

(post "/chief/apps/add"
      (require-user)
      (set app (dict name:((REQUEST post) name:)
                  domains:((REQUEST post) domains:)
              description:((REQUEST post) description:)
                  workers:(((REQUEST post) workers:) intValue)
                 owner_id:(account _id:)))
      (set appid (add-app app))
      (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(get "/chief/apps/manage/appid:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (htmlpage (+ "Manage " (app name:))
               (&div (navbar "Manage")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 (app name:))
                                 (&table class:"table table-bordered"
                                         (&tr (&td "Path")
                                              (&td (app path:)))
                                         (&tr (&td width:"20%" "Domains")
                                              (&td
                                                  (((app domains:) componentsSeparatedByString:" ")
                                                   map:(do (domain)
                                                           (&span
                                                                 (&a href:(+ "http://" domain) domain) "&nbsp;")))))
                                         (&tr (&td "Description")
                                              (&td (app description:))))
                                 (&h3 "Versions")
                                 (if ((app versions:) count)
                                     (then (&table class:"table table-bordered"
                                                   ((app versions:) map:
                                                    (do (version)
                                                        (&tr (&td (version filename:))
                                                             (&td style:"font-size:80%;"
                                                                  (rss-date-formatter stringFromDate:(version created_at:))
                                                                  (&br)
                                                                  (version version:))
                                                             (&td (&a href:(+ "/chief/apps/manage/delete/" appid "/" (version version:))
                                                                      "Delete"))
                                                             (&td (&a href:(+ "/chief/apps/manage/deploy/" appid "/" (version version:))
                                                                      "Deploy")))))))
                                     (else (&p "No versions have been uploaded.")))
                                 (if (app deployment:)
                                     (+
                                       (&span style:"float:right" (&a href:(+ "/chief/apps/manage/stop/" (app _id:)) "Stop"))
                                       (&h3 "Deployment")
                                       (&table class:"table table-bordered"
                                               (&tr (&td "name") (&td ((app deployment:) name:)))
                                               (&tr (&td "version") (&td ((app deployment:) version:)))
                                               (((app deployment:) workers:) map:
                                                (do (worker)
                                                    (+ (&tr (&td (&strong "worker"))
                                                            (&td (worker host:) ":" (worker port:)))
                                                       (&tr (&td) (&td (&a href:(+ "/chief/apps/manage/" appid "/" (worker container:))
                                                                           (worker container:))))))))))
                                 (&form action:(+ "/chief/apps/upload/" appid)
                                        method:"post"
                                       enctype:"multipart/form-data"
                                        (&p "To upload a new version of this app:")
                                        (&input type:"file" name:"appfile" size:40)
                                        (&input type:"submit" name:"upload" value:"upload"))
                                 (&hr style:"margin-top:2em;")
                                 (&a href:(+ "/chief/apps/edit/" appid) "Edit this app")
                                 " | "
                                 (&a href:(+ "/chief/apps/delete/" appid) "Delete this app"))))))

(get "/chief/apps/manage/stop/appid:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (halt-app-deployment app)
     (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(get "/chief/apps/manage/delete/appid:/version:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (set version ((REQUEST bindings) version:))
     (set versions (app versions:))
     (set versions (versions select:
                             (do (v) (ne (v version:) version))))
     (set update (dict $set:(dict versions:versions)))
     (mongo updateObject:update
            inCollection:(+ SITE ".apps")
           withCondition:(dict _id:(oid appid))
       insertIfNecessary:NO
   updateMultipleEntries:NO)
     (mongo removeFile:version
          inCollection:"appfiles"
            inDatabase:SITE)
     (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(get "/chief/apps/manage/deploy/appid:/version:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (set version ((REQUEST bindings) version:))
     (deploy-version app version)
     (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(post "/chief/apps/upload/appid:"
      (require-user)
      (set appid ((REQUEST bindings) appid:))
      (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
      (unless app (return nil))
      (puts "uploading")
      (set d ((REQUEST body) multipartDictionary))
      (puts (d description))
      (if (and (set appfile (d appfile:))
               (set appfile-data (appfile data:))
               (appfile-data length)
               (set appfile-name (appfile filename:)))
          (then ;; save appfile
                (puts "saving")
                (add-version app appfile-name appfile-data)))
      (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(post "/chief/api/appname:"
      (require-authorization)
      (set app (mongo findOne:(dict name:appname) inCollection:(+ SITE ".apps")))
      (unless app (return "error: app #{appname} not found"))
      (puts "uploading")
      (if (and (set appfile-data (REQUEST body))
               (appfile-data length)
               (set appfile-name (+ (app name:) ".zip")))
          (then ;; save appfile
                (puts "saving")
                (set version (add-version app appfile-name appfile-data))
                (version version:))
          (else "error: invalid app data")))

(post "/chief/api/appname:/deploy/version:"
      (require-authorization)
      (set app (mongo findOne:(dict name:appname) inCollection:(+ SITE ".apps")))
      (unless app (return "can't find app"))
      (set version ((REQUEST bindings) version:))
      (if (deploy-version app version)
          (then "deployed")
          (else "error: unable to deploy app")))

(get "/chief/apps/edit/appid:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (htmlpage (+ "Editing " (app name:))
               (&div (navbar "Edit")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 "Editing " (app name:))
                                 (&form action:(+ "/chief/apps/edit/" appid)
                                            id:"edit" method:"post"
                                        (&dl (&dt (&label for:"app_name" "App name"))
                                             (&dd (&input id:"app_name" name:"name" size:"40" type:"text" value:(app name:)))
                                             (&dt (&label for:"app_path" "App path"))
                                             (&dd (&input id:"app_path" name:"path" size:"40" type:"text" value:(app path:)))
                                             (&dt (&label for:"app_domains" "App domains"))
                                             (&dd (&input id:"app_domains" name:"domains" size:"40" type:"text" value:(app domains:)))
                                             (&dt (&label for:"app_workers" "Number of workers"))
                                             (&dd (&select id:"app_workers" name:"workers"
                                                           ((array 1 2 3 4 5 6 7 8 9 10) map:
                                                            (do (i) (&option value:i i selected:(eq i (app workers:)))))))
                                             (&dt (&label for:"app_description" "Description"))
                                             (&dd (&textarea  id:"app_description" name:"description"
                                                            rows:"5" cols:"60" (app description:))))
                                        (&input name:"save" type:"submit" value:"Save")
                                        " or "
                                        (&a href:"/chief" "Cancel")))))))

(post "/chief/apps/edit/appid:"
      (require-user)
      (set appid ((REQUEST bindings) appid:))
      (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
      (unless app (return nil))
      (set post (REQUEST post))
      (set update (dict name:(post name:)
                        path:(post path:)
                     domains:(post domains:)
                 description:(post description:)
                     workers:((post workers:) intValue)))
      (mongo updateObject:(dict $set:update)
             inCollection:(+ SITE ".apps")
            withCondition:(dict _id:(oid appid))
        insertIfNecessary:NO
    updateMultipleEntries:NO)
      (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid)))

(get "/chief/apps/delete/appid:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (htmlpage "delete this app?"
               (&div (navbar "delete this app?")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 "Do you really want to delete this app?")
                                 (&table (&tr (&td "name") (&td (app name:)))
                                         (&tr (&td "domains" (&td (app domains:))))
                                         (&tr (&td "description" (&td (app description:)))))
                                 (&h2 "WARNING: there is no undo.")
                                 (&form action:(+ "/chief/apps/delete/" appid)
                                        method:"POST"
                                        (&input type:"submit" name:"submit" value:"OK")
                                        "&nbsp;"
                                        (&input type:"submit" name:"submit" value:"Cancel")))))))

(post "/chief/apps/delete/appid:"
      (require-user)
      (set appid ((REQUEST bindings) appid:))
      (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
      (unless app (return nil))
      (set post (REQUEST post))
      (puts (post description))
      (if (eq (post submit:) "OK")
          (then (mongo removeWithCondition:(dict _id:(oid appid)) fromCollection:(+ SITE ".apps"))
                ;; TODO stop and remove the app workers
                ((app versions:) each:
                 (do (version)
                     (mongo removeFile:(version version:)
                          inCollection:"appfiles"
                            inDatabase:SITE)))
                (htmlpage "item deleted"
                          (&div (navbar "item deleted")
                                (&div class:"row"
                                      (&div class:"large-12 columns"
                                            (&h2 "It's gone.")))))))
      (else (RESPONSE redirectResponseToLocation:(+ "/chief/apps/manage/" appid))))

(get "/chief/apps/manage/appid:/container:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (set container ((REQUEST bindings) container:))
     (set worker nil)
     (if (app deployment:)
         (then (set worker (((app deployment:) workers:) find:(do (w) (eq (w container:) container))))
               (htmlpage "worker detail"
                         (&div (navbar "worker detail")
                               (&div class:"row"
                                     (&div class:"large-12 columns"
                                           (&h1 "Worker for " (&a href:(+ "/chief/apps/manage/" appid) (app name:)))
                                           (&pre (worker description))
                                           (&ul (if (eq (uname) "Linux")
                                                    (then (&li (&a href:(+ "/chief/apps/manage/" appid "/" container "/upstart.conf") "upstart.conf")))
                                                    (else (+ (&li (&a href:(+ "/chief/apps/manage/" appid "/" container "/launchd.plist") "launchd.plist"))
                                                             (&li (&a href:(+ "/chief/apps/manage/" appid "/" container "/sandbox.sb") "sandbox.sb")))))
                                                (&li (&a href:(+ "/chief/apps/manage/" appid "/" container "/stdout.log") "stdout.log"))
                                                (&li (&a href:(+ "/chief/apps/manage/" appid "/" container "/stderr.log") "stderr.log"))))))))
         (else "not found")))

(get "/chief/apps/manage/appid:/container:/file:"
     (require-user)
     (set appid ((REQUEST bindings) appid:))
     (set app (mongo findOne:(dict _id:(oid appid) owner_id:(account _id:)) inCollection:(+ SITE ".apps")))
     (unless app (return nil))
     (set container ((REQUEST bindings) container:))
     (set worker nil)
     (set text nil)
     (if (app deployment:)
         (then (set worker (((app deployment:) workers:) find:(do (w) (eq (w container:) container))))
               (set file ((REQUEST bindings) file:))
               (set text
                    (case file
                          ("upstart.conf" (NSString stringWithContentsOfFile:(+ "/etc/init/agentbox-worker-" (worker port:) ".conf")))
                          ("sandbox.sb" (NSString stringWithContentsOfFile:(+ AGENTBOX-PATH "/workers/" container "/sandbox.sb")))
                          ("launchd.plist" (NSString stringWithContentsOfFile:(+ "/Library/LaunchDaemons/net.agentbox.app." (worker port:) ".plist")))
                          ("stdout.log" (NSString stringWithContentsOfFile:(+ AGENTBOX-PATH "/workers/" container "/var/stdout.log")))
                          ("stderr.log" (NSString stringWithContentsOfFile:(+ AGENTBOX-PATH "/workers/" container "/var/stderr.log")))
                          (t nil))))
         (else (set text nil)))
     (if text
         (then (REQUEST setContentType:"text/html")
               (htmlpage file
                         (&div (navbar file)
                               (&div class:"row"
                                     (&div class:"large-12 columns"
                                           (&h1 file)
                                           (&pre class:"code" (html-escape text)))))))
         (else nil)))

(get "/chief/about"
     (require-user)
     (htmlpage "About AgentBox"
               (&div (navbar "About")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 "About AgentBox")
                                 (&p "Build, test, and deploy cloud-based apps with Xcode and Objective-C.")
                                 (&ul (&li "App servers run Mac OS X.")
                                      (&li "Apps can be built with Xcode and are written in Objective-C and related scripting languages.")
                                      (&li "Apps are managed with launchd.")
                                      (&li "Apps are run in a sandbox that controls their access to local files and network resources.")
                                      (&li "Apps keep all persistent information outside the app itself."
                                           (&ul (&li "Structured data is kept in MongoDB collections accessed over web services.")
                                                (&li "Files are kept in a managed file store.")))
                                      (&li "Apps can be run as multiple concurrent instances to increase capacity.")
                                      (&li "Apps are connected using a load balancer that routes requests to apps."))
                                 (&p (&a href:"http://radtastical.com" "by Radtastical Inc."))
                                 (&p "Copyright ©2012, All rights reserved.")
                                 (&p (&a href:"mailto:tim@radtastical.com" "Contact us.")))))))

(get "/chief/browse"
     (require-user)
     (set collections ((mongo collectionNamesInDatabase:SITE) sort))
     (htmlpage "Browse Data Store"
               (&div (navbar "browse data store")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 "Collections")
                                 (&table class:"table table-striped"
                                         (collections mapWithIndex:
                                                      (do (collection index)
                                                          (&tr (&td (+ index 1) ". "
                                                                    (&a href:(+ "/chief/browse/" collection) collection)))))))))))

(get "/chief/browse/collection:"
     (require-user)
     (set collection ((REQUEST bindings) collection:))
     (set documents (mongo findArray:nil inCollection:(+ SITE "." collection)))
     (htmlpage (+ "browsing " collection)
               (&div (navbar "browsing collection")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 collection)
                                 (documents map:
                                            (do (document)
                                                (&div (&h4 (document _id:))
                                                      (&pre (document description))))))))))

(get "/chief/nginx.conf"
     (require-user)
     (REQUEST setContentType:"text/html")
     (htmlpage "AgentBox nginx.conf"
               (&div (navbar "nginx.conf")
                     (&div class:"row"
                           (&div class:"large-12 columns"
                                 (&h1 "AgentBox nginx.conf " (&a href:"/chief/restart-nginx" "(restart)"))
                                 (&pre class:"code" (NSString stringWithContentsOfFile:(nginx-conf-path))))))))

(get "/chief/restart-nginx"
     (require-user)
     (restart-nginx)
     (RESPONSE redirectResponseToLocation:"/chief"))

;;; site management

(get "/chief/restart"
     (require-user)
     (RESPONSE setExit:1)
     (RESPONSE redirectResponseToLocation:"/chief.html"))

