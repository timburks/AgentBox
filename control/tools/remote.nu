(load "RadCrypto")
(set HOST "agent.io")

(set username "tim")
(set password "admin123")

(puts "creating admin")
(set URL (NSURL URLWithString:"http://#{HOST}/control/api/admin"))
(set request (NSMutableURLRequest requestWithURL:URL))
(request setHTTPMethod:"POST")
(request setHTTPBody:((dict username:username password:password) XMLPropertyListRepresentation))
(set data (NSURLConnection sendSynchronousRequest:request returningResponse:(set responsep (NuReference new)) error:(set errorp (NuReference new))))
(puts ((NSString alloc) initWithData:data encoding:NSUTF8StringEncoding))

(puts "getting secret")
(set URL (NSURL URLWithString:"http://#{HOST}/control/api/account"))
(set request (NSMutableURLRequest requestWithURL:URL))
(set authValue (+ "Basic " (((+ username ":" password) dataUsingEncoding:NSUTF8StringEncoding) base64EncodedString)))
(request setValue:authValue forHTTPHeaderField:"Authorization")
(set data (NSURLConnection sendSynchronousRequest:request returningResponse:(set responsep (NuReference new)) error:(set errorp (NuReference new))))
(set account ((data propertyListValue) account:))
(set SECRET (account secret:))
(puts SECRET)
