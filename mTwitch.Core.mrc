alias mTwitch.has.core {
  return 0000.0000.0010
}

alias mTwitch.isServer {
  if ($isid) {
    mTwitch.Debug -i $!mTwitch.isServer~Called with the parameters: $*
    if (!$JSONVersion) {
      echo $color(info2) -a [mTwitch->Core] This script depends on SReject's JSON parser to be loaded
      .timer 1 0 .unload -rs $qt($script)
    }
    else {
      if (!$hget(mTwitch.IsServer.List) || !$timer(mTwitch.IsServer.UpdateList)) {
        mTwitch.Debug -i2 $!mTwitch.isServer~Updating server list
        mTwitch.IsServer.UpdateList
      }
      if (!$len($1-)) {
        tokenize 32 $server
      }
      if (!$0) {
        mTwitch.Debug -w $!mTwitch.isServer~No parameters specified and $!server is empty
        return $false
      }
      if (!$prop) && ($network === twitch.tv || $regex($1-, /^(tmi|irc)\.(chat\.)?twitch\.tv$/i)) {
        mTwitch.Debug -s $!mTwitch.isServer~Network matches twitch.tv or server matches twitch chat servers
        return $true
      }
      elseif ($prop == isGroup && $network == groupchat.twitch.tv) {
        mTwitch.Debug -s $!mTwitch.isServer~Server is a groupchat server
        return $true
      }
      elseif ($hget(mTwitch.IsServer.List, $1)) {
        var %type = $v1
        mTwitch.Debug -i $!mTwitch.isServer~Server found is server list as: $v1
        if (!$prop || ($prop == isGroup && %type == group)) {
          mTwitch.Debug -s $!mTwitch.isServer~Server is a twitch $iif(%type == group, grouchat, chat) server.
          return $true
        }
      }
    }
    return $false
  }
}

alias mTwitch.ChatIsSlow {
  mTwitch.Debug -i $!mTwitch.ChatIsSlow~Called with parameters: $*
  if ($hget(mTwitch.StreamState, $1.slow)) {
    return $iif($prop == dur, $hget(mTwitch.StreamState, $1.slow), $true)
  }
}

alias mTwitch.ChatIsSubOnly {
  mTwitch.Debug -i $!mTwitch.ChatIsSubOnly~Called with parameters: $*
  return $iif($hget(mTwitch.StreamState, $1.subonly), $true, $false)
}

alias mTwitch.ChatIsR9k {
  mTwitch.Debug -i $!mTwitch.ChatIsR9k~Called with parameters: $*
  return $iif($hget(mTwitch.StreamState, $1.r9k), $true, $false)
}

alias mTwitch.StreamIsHosting {
  mTwitch.Debug -i $!mTwitch.StreamIsHosting~Called with parameters: $*
  return $iif($hget(mTwitch.StreamState, $1.hosting), $v1, $false)
}

alias mTwitch.ConvertTime {
  mTwitch.Debug -i $!mTwitch.ConvertTime~Called with parameters: $*
  if ($regex($1-, /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/)) {
    var %time = $asctime($calc($ctime($+($gettok(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec, $regml(2), 32) $ord($base($regml(3), 10, 10)), $chr(44) $regml(1) $regml(4), :, $regml(5), :, $regml(6))) + ( $time(z) * 3600)), mmm dd @ HH:nn:ss)
    
    mTwitch.Debug -s $!mTwitch.ConvertTime~Returning time as: %time
    return %time
  }
  else {
    mTwitch.Debug -w $!mTwitch.ConvertTime~Input did not match the required pattern: $1-
  }
}

alias mTwitch.Storage.Add {
  if ($isid && $0 > 1) {
    var %x = 1, %key, %item
    while (%x < $0) {
      %item = $eval($ $+ %x, 2)
      if ($regex(%item, [\s\.\*\?])) {
        return $false
      }
      %key = $addtok(%key, %item, 46)
      inc %x
    }
    hadd -m mTwitch %key $($ $+ %x, 2)
    hsave mTwitch $qt($scriptdirmTwitch.dat)
    return $true
  }
}

alias mTwitch.Storage.Get {
  if ($isid && $0 > 1) {
    var %x = 1, %key, %item
    while (%x <= $0) {
      %item = $eval($ $+ %x, 2)
      if ($regex(%item, [\s\.])) {
        return
      }
      %key = $addtok(%key, %item, 46)
      inc %x
    }
    return $hget(mTwitch, %key)
  }
}

alias mTwitch.Storage.Del {
  if ($isid && $0 > 1) {
    var %x = 1, %key, %item
    while (%x <= $0) {
      %item = $eval($ $+ %x, 2)
      if ($regex(%item, [\s\.])) {
        return $false
      }
      %key = $addtok(%key, item, 46)
      inc %x
    }
    hdel $iif(wildcard, -w) mTwitch %key
    hsave mTwitch $qt($scriptdirmTwitch.dat)
    return $true
  }
}

alias mTwitch.UrlEncode {
  return $regsubex($1, /(\W| )/g, % $+ $base($asc(\1), 10, 16, 2))
}

alias mTwitch.MsgTags {
  var %tok = $wildtok($iif(@* iswm $1, $mid($1, 2-), $1), $2 $+ =*, $iif($0 > 2, $3, 1), 59)
  if ($0 > 2 && $3 == 0) {
    return %tok
  }
  return $regsubex($mTwitch.MsgTags.Unescape($gettok(%tok, 2, 61)), /\\(.)/g, $_xmsgtags(\t))
}

alias -l mTwitch.IsServer.UpdateList {
  mTwitch.Debug -i $!mTwitch.isServer.UpdateList~Called with parameters: $*
  if (!$isid && $JSONVersion) {
    var %i = 0, %e, %ee, %h, %n, %nn, %h =  mTwitch.IsServer.List, %n =  mTwitch_isServer_ChatServerList, %nn = mTwitch_isServer_GroupServerList, %s
    mTwitch.Debug -i $!mTwitch.isServer.UpdateList~Attempting to retrieve server lists
    JSONOpen -ud %n http://api.twitch.tv/api/channels/SReject/chat_properties
    if ($JSONError) {
      mTwitch.Debug -e $!mTwitch.isServer.UpdateList~Unable to get server list: $v1
    }
    elseif ($JSON(%n, chat_servers, length)) {
      %e = $v1
      mTwitch.Debug -i2 $!mTwitch.isServer.UpdateList~Number of servers returned: %e
      mTwitch.Debug -i $!mTwitch.isServer.UpdateList~Retrieving group servers
      JSONOpen -ud %nn http://tmi.twitch.tv/servers?cluster=group
      if ($JSONError) {
        mTwitch.Debug -i $!mTwitch.isServer.UpdateList~Unable to retrieve group-chat servers list.
      }
      else {
        %ee = $JSON(%nn, servers, length)
        if ($hget(%h)) {
          hfree $v1
        }
        while (%i < %e) {
          %s = $gettok($JSON(%n, chat_servers, %i), 1, 58)
          hadd -m %h %s General
          mTwitch.Debug -i2 $!mTwitch.isServer.UpdateList~Added %s as a general chat server
          inc %i
        }
        %i = 0
        while (%i < %ee) {
          %s = $gettok($JSON(%nn, servers, %i), 1, 58)
          hadd -m %h %s Group
          mTwitch.Debug -i $!mTwitch.isServer.UpdateList~Added %s as a group chat server
          inc %i
        }
      }
    }
    else {
      mTwitch.Debug -w $!mTwitch.isServer.UpdateList~No chat servers returned by http://api.twitch.tv/api/channels/SReject/chat_properties
    }
    .timermTwitch.isServer.UpdateList -io 1 3600 mTwitch.isServer.UpdateList
  }
}

alias -l mTwitch.StreamState.AmOn {
  if ($mTwitch.isServer && $me ison $1) {
    set -u0 %mTwitch.StreamState $true
  }
}

alias -l mTwitch.StreamState.Cleanup {
  if ($1) {
    scon -a mTwitch.StreamState.AmOn $1
    if (!%mTwitch.StreamState.AmOn) {
      hdel -w mTwitch.StreamState $1.
    }
    unset %mTwitch.StreamState.AmOn
  }
  else {
    var %x = 1
    while ($chan(%x)) {
      scon -a mTwitch.StreamState.AmOn $1
      if (!%mTwitch.StreamState.AmOn) {
        hdel -w mTwitch.StreamState $1.*
      }
      unset %mTwitch.StreamState.AmOn
      inc %x
    }
  }
}

alias -l mTwitch.MsgTags.Unescape {
  if ($1 == s) returnex $chr(32)
  if ($1 == r) return $cr
  if ($1 == l) return $lf
  if ($1 == :) return ;
  if ($1 == \) return
  return $1
}

on *:START:{
  if (!$JSONVersion) {
    echo $color(info2) -a [mTwitch->Core] This script depends on SReject's JSON parser to be loaded
    .timer 1 0 .unload -rs $qt($script)
  }
  else {
    hmake mTwitch 100
    if ($isfile($scriptdirmTwitch.dat)) {
      hload mTwitch $qt($scriptdirmTwitch.dat)
    }
    mTwitch.IsServer.UpdateList
  }
}

on *:UNLOAD:{
  .timermTwitch.isServer.UploadList off
}

on $*:PARSELINE:in:/^\x3A(irc|tmi)\.twitch\.tv CAP \* LS (\x3A.*)$/:{
  if ($mTwitch.isServer) {
    set -e $+(%,$cid,mTwitch.CapAcceptHalt) $true
    .raw CAP REQ $regml(2)
  }
}

on $*:PARSELINE:out:/^CAP END$/:{
  if ($mTwitch.isServer && $($+(%, $cid, mTwitch.CapAcceptHalt), 2)) {
    .parseline -otn
  }
}

on $*:PARSELINE:in:/^\x3A(irc|tmi)\.twitch\.tv CAP \* ACK \x3A/:{
  if ($mTwitch.isServer && $($+(%, $cid, mTwitch.CapAcceptHalt), 2)) {
    .raw CAP END
    unset $+(%, $cid, mTwitch.CapAcceptHalt)
  }
}

on $*:PARSELINE:out:/^JOIN #?(\S+)$/i:{
  if ($lower($regml(1)) !=== $regml(1)) {
    join $chr(35) $+ $v1
    .parseline -otn
  }
}

raw 004:*:{
  if ($mTwitch.isServer) {
    .parseline -iqpt :tmi.twitch.tv 005 $me NETWORK= $+ $iif($mTwitch.isServer().isGroup, groupchat.,) $+ twitch.tv :are supported by this server
  } 
}

raw *:*:{
  if ($mTwitch.isServer) {
    tokenize 32 $rawmsg
    if ($0 == 3 && :tmi.twitch.tv ROOMSTATE == $1-2 && $me ison $3) {
      if ($msgtags(slow)) {
        hadd -m mTwitch.StreamState $3.slow $msgtags(slow).key
      }
      if ($msgtags(sub-only)) {
        hadd -m mTwitch.StreamState $3.subonly $msgtags(subs-only).key
      }
      if ($msgtags(r9k)) {
        hadd -m mTwitch.StreamState $3.r9k $msgtags(r9k).key
      }
      haltdef
    }
    elseif ($regex($1-, /^:(?:tmi|irc)\.twitch\.tv HOSTTARGET #\S+ :(\S+) \d+$/i) && $me ison $3) {
      hadd -m mTwitch.StreamState $3.hosting $iif($regml(1) == -, $false, $v1)
      haltdef
    }
  }
}

on ^*:DISCONNECT:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup
    unset $+(%, $cid, mTwitch.CapAcceptHalt)
  }
}

on me:*:PART:#:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup #
  }
}

alias mTwitchDebug {
  var %Error, %State = $iif($group(#mTwitchDebug) == on, $true, $false)
  if ($isid) {
    return %State
  }
  elseif ($0 > 1) {
    %Error = Excessive parameters
  }
  elseif ($0 && !$regex($1, /^(?:on|off|enable|disable)$/i)) {
    %Error = Invalid parameter specified
  }
  else {
    if ($1 == on || $1 == enable) {
      .enable #mTwitchDebug
    }
    elseif ($1 == off || $1 == disable) {
      .disable #mTwitchDebug
    }
    else {
      $iif(%State, .disable, .enable) #mTwitchDebug
    }
    if ($group(#mTwitchDebug) == on && !$window(@mTwitchDebug)) {
      window -nzk0 @mTwitchDebug
    }
  }
  :error
  if ($error || %Error) {
    echo -sg * /mTwitchDebug: $v1
    halt
  }
}
#mTwitchDebug off
alias mTwitch.Debug {
  if (!$window(@mTwitchDebug)) {
    mTwitchDebug off
    return
  }
  var %Color = 03, %Prefix = mTwitch, %Msg
  if (-* iswm $1) {
    if ($1 == -e) {
      %Color = 04
    }
    elseif ($1 == -w) {
      %Color = 07
    }
    elseif ($1 == -i2) {
      %Color = 10
    }
    elseif ($1 == -s) {
      %Color = 12
    }
    tokenize 32 $2-
  }
  if (~ !isin $1-) {
    %Msg = $1-
  }
  elseif (~* iswm $1-) {
    %Msg = $mid($1-, 2-)
  }
  else {
    %Prefix = $gettok($1-, 1, 126)
    %Msg = $gettok($1-, 2-, 126)
  }
  echo @mTwitchDebug $+($chr(3), %color, [, %Prefix, ], $chr(15)) %Msg
}
#mTwitchDebug end
alias mTwitch.Debug noop
menu @mTwitchDebug {
  $iif($group(#mTwitchDebug) == on, Disable, Enable): mTwitchDebug
  -
  Clear: clear @mTwitchDebug
  -
  Close: mTwitchDebug off | close -@ @mTwitchDebug
}

