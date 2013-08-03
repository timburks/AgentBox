(load "RadHTTP:macros")
(load "RadCrypto")
(load "RadMongoDB")

(set SITE "agentbox")
(set PASSWORD_SALT SITE)

(if (eq (uname) "Linux")
    (then (set AGENTBOX-PATH "/home/agentbox"))
    (else (set AGENTBOX-PATH "/AgentBox")))

(class NSString
 (- (id) md5HashWithSalt:(id) salt is
    (((self dataUsingEncoding:NSUTF8StringEncoding)
      hmacMd5DataWithKey:(salt dataUsingEncoding:NSUTF8StringEncoding))
     hexEncodedString)))
