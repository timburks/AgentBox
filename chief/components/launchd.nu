
(function generate-launchd-plist (CONTAINER NAME PORT)
          ((dict Label:(+ "net.agentbox.app." PORT)
              OnDemand:(NSNumber numberWithBool:NO)
              UserName:"agentbox"
      WorkingDirectory:(+ AGENTBOX-PATH "/workers/" CONTAINER "/" NAME ".app")
  EnvironmentVariables:(dict AGENTBOX-CONTAINER: CONTAINER
                                  AGENTBOX-PORT: PORT
                               AGENTBOX-APPNAME: NAME)
       StandardOutPath:(+ AGENTBOX-PATH "/workers/" CONTAINER "/var/stdout.log")
     StandardErrorPath:(+ AGENTBOX-PATH "/workers/" CONTAINER "/var/stderr.log")
      ProgramArguments:(array "sandbox-exec"
                              "-f"
                              (+ AGENTBOX-PATH "/workers/" CONTAINER "/sandbox.sb")
                              (+ AGENTBOX-PATH "/workers/" CONTAINER "/" NAME ".app/" NAME)
                              "-p"
                              (PORT stringValue)))
           XMLPropertyListRepresentation))

