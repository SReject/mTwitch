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
      if (!$hget(mTwitch.chatServerList) || !$timer(mTwitch.chatServerListUpdate)) {
        mTwitch.chatServerListUpdate
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
      if ($hget(mTwitch.chatServerList, $1)) {
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

alias -l mTwitch.chatServerListUpdate {
  if (!$isid && $JSONVersion) {
    var %i = 0, %e, %ii = 0, %ee, %s, %n = mTwitch_getChatServerList, %nn = mTwitch_getGroupServerList, %h = mTwitch.chatServerList
    JSONOpen -ud %n http://api.twitch.tv/api/channels/SReject/chat_properties
    if ($JSONError) {
      return 
    }
    %e = $JSON(%n, chat_servers, length)
    if (!%e || $JSONError) {
      return 
    }
    JSONOpen -ud %nn http://tmi.twitch.tv/servers?cluster=group
    if ($JSONError) { 
      return
    }
    %ee = $JSON(%nn, servers, length)
    if (!%ee || $JSONError) { 
      return 
    }
    if ($hget(%h)) {
      hfree $v1
    }
    while (%i < %e) {
      hadd -m %h $gettok($JSON(%n, chat_servers, %i), 1, 58) General
      inc %i
    }
    while (%ii < %ee) {
      hadd -m %h $gettok($JSON(%nn, servers, %ii), 1, 58) Group
      inc %ii
    }
    .timermTwitch.chatServerListUpdate -io 1 3600 mTwitch.chatServerListUpdate
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

alias -l mTwitch.StreamState.AmOn {
  if ($mTwitch.isServer && $me ison $1) {
    set -u0 %mTwitch.StreamState $true
  }
}

alias -l mTwitch.GetWid {
  var %x = 0
  while (%x < $scon(0)) {
    inc %x
    scon %x
    if ($mTwitch.isServer && $window($1)) {
      return $window($1).wid
    }
  }
}

on *:START:{
  if (!$JSONVersion) {
    echo $color(info2) -a [mTwitch->Core] This script depends on SReject's JSON parser to be loaded
    .timer 1 0 .unload -rs $qt($script)
  }
  else {
    mTwitch.chatServerListUpdate
  }
}

on *:UNLOAD:{
  .timermTwitch.chatServerListUpdate off
}

on $*:PARSELINE:in:/^\x3A(irc|tmi)\.twitch\.tv CAP \* LS (\x3A.*)$/:{
  raw CAP REQ $regml(2)
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
