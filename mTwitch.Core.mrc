alias mTwitch.has.core {
  return 0000.0000.0007
}

alias mTwitch.isServer {
  if ($isid) {
    if (!$JSONVersion) {
      echo $color(info2) -a [mTwitch->Core] This script depends on SReject's JSON parser to be loaded
      .timer 1 0 .unload -rs $qt($script)
    }
    else {
      if (!$hget(mTwitch.IsServer.List) || !$timer(mTwitch.IsServer.UpdateList)) {
        mTwitch.IsServer.UpdateList
      }
      if (!$len($1-)) {
        tokenize 32 $server
      }
      if (!$0) {
        return $false
      }
      if (!$prop) && ($network === twitch.tv || $1- == tmi.twitch.tv || $1- == irc.twitch.tv) {
        return $true
      }
      elseif ($prop == isGroup && $network == groupchat.twitch.tv) {
        return $true
      }
      if (!$longip($1)) {
        return $false
      }
      if ($hget(mTwitch.IsServer.List, $1)) {
        var %type = $v1
        if (!$prop || ($prop == isGroup && %type == group)) {
          return $true
        }
      }
    }
    return $false
  }
}

alias mTwitch.ChatIsSlow {
  if ($hget(mTwitch.StreamState, $1.slow)) {
    return $iif($prop == dur, $hget(mTwitch.StreamState, $1.slow), $true)
  }
}

alias mTwitch.ChatIsSubOnly {
  return $iif($hget(mTwitch.StreamState, $1.subonly), $true, $false)
}

alias mTwitch.ChatIsR9k {
  return $iif($hget(mTwitch.StreamState, $1.r9k), $true, $false)
}

alias mTwitch.StreamIsHosting {
  return $iif($hget(mTwitch.StreamState, $1.hosting), $v1, $false)
}

alias mTwitch.ConvertTime {
  if ($regex($1-, /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/)) {
    return $asctime($calc($ctime($+($gettok(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec, $regml(2), 32) $ord($base($regml(3), 10, 10)), $chr(44) $regml(1) $regml(4), :, $regml(5), :, $regml(6))) + ( $time(z) * 3600)), mmm dd @ HH:nn:ss)
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
      %key = $addtok(%key, item, 46)
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
  if (!$isid && $JSONVersion) {
    var %i = 0, %e, %ee, %h, %n, %nn, %h =  mTwitch.IsServer.List, %n =  mTwitch_isServer_ChatServerList, %nn = mTwitch_isServer_GroupServerList
    JSONOpen -ud %n http://api.twitch.tv/api/channels/SReject/chat_properties
    if (!$JSONError) {
      %e = $JSON(%n, chat_servers, length) 
      if (%e && !$JSONError) {
        JSONOpen -ud %nn http://tmi.twitch.tv/servers?cluster=group
        if (!$JSONError) { 
          %ee = $JSON(%nn, servers, length)
          if (%ee && !$JSONError) { 
            if ($hget(%h)) {
              hfree $v1
            }
            while (%i < %e) {
              hadd -m %h $gettok($JSON(%n, chat_servers, %i), 1, 58) General
              inc %i
            }
            %i = 0
            while (%i < %ee) {
              hadd -m %h $gettok($JSON(%nn, servers, %i), 1, 58) Group
              inc %i
            }
          }
        }
      }
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
  raw CAP REQ $regml(2)
}

on $*:PARSELINE:out:/^JOIN (#\S+)$/i:{
  if ($lower($regml(1)) !=== $regml(1)) {
    join $v1
    .parseline -otn
  }
}

raw 004:*:{
  if ($mTwitch.isServer()) {
    .parseline -iqptu0 :tmi.twitch.tv 005 $me NETWORK= $+ $iif($mTwitch.isServer().isGroup, groupchat.,) $+ twitch.tv :are supported by this server
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
    elseif ($0 == 5 && :tmi.twitch.tv HOSTTARGET == $1-2 && $me ison $3) {
      hadd -m mTwitch.StreamState $3.hosting $iif($4 == -, $false, $4)
      haltdef
    }
  }
}

on ^*:DISCONNECT:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup
  }
}

on me:*:PART:#:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup #
  }
}
