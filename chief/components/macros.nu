;; helpers

((set date-formatter
      ((NSDateFormatter alloc) init))
 setDateFormat:"EEEE MMMM d, yyyy")

((set rss-date-formatter
      ((NSDateFormatter alloc) init))
 setDateFormat:"EEE, d MMM yyyy hh:mm:ss ZZZ")

;; basic site structure

(macro htmlpage (title *body)
       `(progn (REQUEST setContentType:"text/html")
               (unless (defined account) (set account (get-user SITE)))
               (&html (&head (&meta charset:"utf-8")
                             (&title ,title)
                             (&meta name:"viewport" content:"width=device-width, initial-scale=1.0")
                             (&meta name:"description" content:"AgentBox Monitor")
                             (&meta name:"author" content:"Tim Burks")
                             (&script src:"/chief/v2/js/custom.modernizr.js")
                             (&link href:"/chief/v2/css/normalize.css" rel:"stylesheet")
                             (&link href:"/chief/v2/css/foundation.min.css" rel:"stylesheet"))
                      (&body ,@*body
                             (&script src:"/chief/v2/js/jquery.js")
                             (&script src:"/chief/v2/js/foundation.min.js")
                             (&script "$(document).foundation();")))))

(macro navbar (name)
       `(progn
              (if (and (defined account) account)
                  (set apps (mongo findArray:(dict $query:(dict owner_id:(account _id:))
                                                 $orderby:(dict name:1))
                                inCollection:(+ SITE ".apps"))))
              (&div class:""
                    (&nav class:"top-bar"
                          (&ul class:"title-area"
                               (&li class:"name" (&h1 (&a href:"/chief" "AgentBox")))
                               (&li class:"toggle-topbar menu-icon"
                                    (&a href:"#" (&span "Menu"))))
                          (&section class:"top-bar-section"
                                    (if (defined apps)
                                        (&ul class:"left"
                                             (&li class:"divider")
                                             (&li (&a href:"/chief/nginx.conf" "nginx"))
                                             (&li class:"divider")
                                             (&li (&a href:"/chief/browse" "mongodb"))
                                             (&li class:"divider")
                                             (&li class:"has-dropdown" (&a href:"#" "apps")
                                                  (&ul class:"dropdown"
                                                       (apps map:
                                                             (do (app)
                                                                 (&li (&a href:(+ "/chief/apps/manage/" (app _id:))
                                                                          (app name:)))))
                                                       (&li class:"divider")
                                                       (&li (&a href:"/chief/apps/add" "Add an app"))))))
                                    (&ul class:"right"
                                         (if (and (defined account) account)
                                             (then (&& (&li (&a href:"#"
                                                                "signed in as " (account username:)))
                                                       (&li (&a href:"/chief/signout" " sign out"))
                                                       (&li (&a href:"/chief/adduser" " add user"))
                                                       (&li (&a href:"/chief/restart" " restart"))))
                                             (else (&li href:"/chief/signin" "sign in")))))))))

