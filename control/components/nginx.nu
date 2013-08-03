(function NGINX-CONF (root-domain apps) <<-END
#
# AgentBox nginx configuration
# this file was automatically generated
#
worker_processes  8;

events {
    worker_connections  1024;
}

http {
    log_format agentbox '$msec|$time_local|$host|$request|$status|$bytes_sent|$request_time|$remote_addr|$http_referer|$http_user_agent|||';
    access_log #{AGENTBOX-PATH}/var/nginx-access.log agentbox;
    error_log #{AGENTBOX-PATH}/var/nginx-error.log debug;

    large_client_header_buffers 4 32k;

    gzip on;
    gzip_proxied any;

    types_hash_bucket_size 64;
    types {
        application/x-mpegURL                   m3u8;
        video/MP2T                              ts;
        video/mp4                               mp4;
        application/xml                         xml;
        image/gif                               gif;
        image/jpeg                              jpg;
        image/png                               png;
        image/bmp                               bmp;
        image/x-icon                            ico;
        text/css                                css;
        text/html                               html;
        text/plain                              txt;
        application/pdf                         pdf;
        text/xml                                plist;
        application/octet-stream                dmg;
        application/octet-stream                ipa;
        application/octet-stream                mobileprovision;
        application/x-apple-aspen-config        mobileconfig;
    }
    default_type       text/html;

    server_names_hash_bucket_size 64;
    server_names_hash_max_size 8192;

    server {
        listen          80;
        listen          443 ssl;
        ssl_certificate     #{AGENTBOX-PATH}/control/etc/wildcard_agent_io.crt;
        ssl_certificate_key #{AGENTBOX-PATH}/control/etc/wildcard_agent_io.key;
        server_name     ~^(.*)$;
        root #{AGENTBOX-PATH}/public;
        try_files $uri.html $uri $uri/ =404;
        location /control/ {
            proxy_set_header Host $host;
            proxy_pass  http://127.0.0.1:2010;
        }
#{(locations-for-apps apps)}
        error_page 404  /404.html;
        error_page 403  /403.html;
        error_page 502  /502.html;
        client_max_body_size 10M;
    }
#{(upstream-servers-for-apps apps)}
}
END)

(function locations-for-apps (apps)
          ((apps map:
                 (do (app)
                     (+ "        # " (app name:) "\n"
                        "        location /" (app path:) "/ {\n"
                        "            proxy_set_header Host $host;\n"
                        "            proxy_pass http://" (app _id:) ";\n"
                        "            proxy_set_header X-Forwarded-For $remote_addr;\n"
                        "        }")
                     )) componentsJoinedByString:"\n"))

(function upstream-servers-for-apps (apps)
          ((apps map:
                 (do (app)
                     (+ "\n"
                        "    # " (app name:) "\n"
                        "    upstream " (app _id:) "{\n"
                        ((((app deployment:) workers:) map:
                          (do (worker)
                              (+ "        server 127.0.0.1:" (worker port:) ";")))
                         componentsJoinedByString:"\n")
                        "\n    }")))
           componentsJoinedByString:"\n"))

(function nginx-config-with-services (root-domain apps)
          (set config (NGINX-CONF root-domain apps))
          config)

(function nginx-conf-path ()
          (if (eq (uname) "Linux")
              (then "/etc/nginx/nginx.conf")
              (else "#{AGENTBOX-PATH}/nginx/nginx.conf")))

(function nginx-path ()
          (if (eq (uname) "Linux")
              (then "/usr/sbin/nginx")
              (else "/usr/local/nginx/sbin/nginx")))

(function restart-nginx ()
          ((NSFileManager defaultManager) removeItemAtPath:(nginx-conf-path) error:nil)
          (set apps (mongo findArray:nil inCollection:(+ SITE ".apps")))
          ((nginx-config-with-services (get-property "root-domain") apps)
           writeToFile:(nginx-conf-path) atomically:YES)
          (system "#{(nginx-path)} -s reload -c #{(nginx-conf-path)} -p #{AGENTBOX-PATH}/nginx/"))

(function prime-nginx ()
          (set root-domain (get-property "root-domain"))
          ((NSFileManager defaultManager) removeItemAtPath:(nginx-conf-path) error:nil)
          ((nginx-config-with-services root-domain (array)) writeToFile:(nginx-conf-path) atomically:YES)
          ;; site index
          ((&html (&head (&title "AgentBox"))
                  (&body style:"background-color:#000; color:#FFF; font-family:Helvetica;"
                         (&p (&strong "AgentBox"))))
           writeToFile:"#{AGENTBOX-PATH}/public/index.html" atomically:NO)
          ;; control redirect
          ((&a href:(+ "/control") "OK, Continue")
           writeToFile:"#{AGENTBOX-PATH}/public/restart.html" atomically:NO))