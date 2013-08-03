(load "components/config")
(load "components/database")
(load "components/nginx")

(set-property "root-domain" "rad.agent.io")
(set-property "deus-domain" "rad.agent.io")

(set-username-password "admin" "password123")

(prime-nginx)
;(restart-nginx)
