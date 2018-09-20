// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************
// Livecode Multi Core Processing Library
// created by Tom Glod | MakeShyft R.D.A | www.makeshyft.com
// This library is licensed under GPL 3
// ***********************************************************************************************************
// ***********************************************************************************************************
// ***********************************************************************************************************



on preopenstack
    if MultiCore_IAm() = 1 then
      if the environment = "standalone application" then
         set the iconic of me to true
         MultiCore_StartupOptions
      else
      end if
   else
   end if
end preopenstack

on MultiCore_StartupOptions
   set itemdelimiter to "="
   
   if item 1 of $1 = "core_id" then
      put item 2 of $1 into TimeSaversToolboxMemory["Startup Options"][item 1 of $1]
   end if
   
   if item 1 of $2 = "port" then
      put item 2 of $2 into TimeSaversToolboxMemory["Startup Options"][item 1 of $2]
   end if
   
   if item 1 of $3 = "master_hash" then
      put item 2 of $3 into TimeSaversToolboxMemory["Startup Options"][item 1 of $3]
   end if
end MultiCore_StartupOptions

function MultiCore_IAm
   if $1 begins with "core_id=" then
      return 1
   else
      return 0
   end if
end MultiCore_Iam


on MultiCore_Launch
   local launchcommand,standalone_options,core_id,core_port,master_hash
   local available_ports = 1000
   local executablename = "TimeSaversToolbox.exe"
   
   put the effective filename of this stack into launchcommand
   
   if the environment = "development" then
      set itemdelimiter to "/"
      delete last item of launchcommand
      put "/" & executablename after launchcommand
   else if the environment = "standalone application" then
   end if
   
   // add parameters
   
   put HashThis(uuid("random")) into core_id
   put "core_id=" & core_id & space after standalone_options
   put core_id into MultiCoreArray["Available Cores"][core_id]["core_id"]
   
   put item (1) of available_ports into core_port
   put "port=" & core_port & space after standalone_options
   put core_port into MultiCoreArray["Available Cores"][core_id]["core_port"]
   
   put HashThisFile(the effective filename of this stack) into master_hash
   put "master_hash=" & master_hash after standalone_options
   
   put space & standalone_options after launchcommand
   
   launch launchcommand


   put "launched" into MultiCoreArray["Available Cores"][core_id]["core_state"]
   AddToConsoleLog "Launched Secondary Core"
end MultiCore_Launch


on MultiCore_AcceptConnection -- Secondary Core
   accept connections on port TimeSaversToolboxMemory["Startup Options"]["port"] with message "MultiCore_Hello"
end MultiCore_AcceptConnection

on MultiCore_Hello SocketID  -- Secondary Core
   
   read from socket SocketID until return
   
   if it = "Start Core" & return then
      write "Core Started"  & return to socket SocketID
      send "MultiCore_ReceiveCommand " & SocketID to me in 0 milliseconds
   else
   end if
   
   put SocketID into TimeSaversToolboxMemory["MultiCore_SocketID"]
   
end MultiCore_Hello

on MultiCore_Connect CoreID -- Primary Core
   open socket to "localhost:" & MultiCoreArray["Available Cores"][CoreID]["core_port"] with message "MultiCore_CoreConnected"
end MultiCore_Connect

on MultiCore_CoreConnected SocketID -- Primary Core
   put SocketID into MultiCoreArray["Available Cores"][line 1 of the keys of MultiCoreArray["Available Cores"]]["core_socket_id"]
   AddToConsoleLog "Sending Hello"
   write "Start Core" & return to socket SocketID
   AddToConsoleLog "Reading Response"
   read from socket SocketID until return
   
   if it = "Core Started" & return then
      AddToConsoleLog "Core Successfully Communicated"
   else
   end if
end MultiCore_CoreConnected

on MultiCore_SendCommand SocketID,WhatScript -- Primary Core
   write WhatScript & "<script_end>" to socket SocketID with message "MultiCore_CommandSent"
   send "MultiCore_WaitForResult " & SocketID to me in 0 milliseconds
end MultiCore_SendCommand

on MultiCore_CommandSent
   AddToConsoleLog "Command was Sent"
end MultiCore_CommandSent

on MultiCore_WaitForResult SocketID -- Primary Core
   read from socket SocketID until "<command_result>" with message "MultiCore_ResultReceived"
end MultiCore_WaitForResult

on MultiCore_ReceiveCommand SocketID -- Secondary Core
   AddToConsoleLog "Waiting For Command"
   read from socket SocketID until "<script_end>" with message "MultiCore_CommandReceived"
end MultiCore_ReceiveCommand

on MultiCore_CommandReceived SocketID,CommandData -- Secondary Core
   local incoming_command
   put CommandData into incoming_command
   replace "<script_end>" with empty in incoming_command
   AddToConsoleLog "Command OK"
   send "MultiCore_DoCommand " & SocketID & comma & incoming_command to me in 0 milliseconds
end MultiCore_CommandReceived

on MultiCore_DoCommand SocketID,WhatScript -- Secondary Core
   local command_result
   AddToConsoleLog "Running Command"
   do WhatScript
   put the result into command_result
   
   AddToConsoleLog "Writing Result"
   AddToConsoleLog "Command Result was:" & command_result
   
   write command_result & "<command_result>" to socket SocketID with message "MultiCore_ResultReturned"   
end MultiCore_DoCommand

on MultiCore_ResultReturned -- Secondary Core
   AddToConsoleLog "Result Returned"
   send "MultiCore_ReceiveCommand " & TimeSaversToolboxMemory["MultiCore_SocketID"] to me in 0 milliseconds
   AddToConsoleLog "Waiting for Next Command"
end MultiCore_ResultReturned

on MultiCore_ResultReceived SocketID,ReturnedData -- Primary Core
   replace "<command_result>" with empty in ReturnedData
   AddToConsoleLog ReturnedData
end MultiCore_ResultReceived