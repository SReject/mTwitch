alias mTwitch.has.GroupChat {
  return 0000.0000.0008
}

alias -l mTwitch.GroupChat.Parse {
  var %sock = $sockname
  if ($regex($1-, /^PING (:.*)$/)) {
    mTwitch.GroupChat.Buffer %sock PONG $regml(1)
  }
  else {
    if (!$hget(%sock, loggedIn)) {
      if ($regex($1-, /^:(?:tmi|irc)\.twitch\.tv (\d\d\d) \S+ :\S*$/i)) {
        hadd -m $sockname loggedIn $true
      }
      else {
        if ($regex($1-, /^:(?:tmi|irc)\.twitch\.tv NOTICE \S+ :Error logging in$/)) {
          mTwitch.GroupChat.Cleanup $sockname
          echo $color(info) -a [mTwitch->GroupChat] Invalid oauth token; stopping Twitch Group-Chat connection attempts.
          halt
        }
        return
      }
    }
    if ($regex($1-, /^:(?:[^\.!@]*\.)?(?:tmi|irc)\.twitch\.tv CAP /i)) {
      return
    }
    elseif ($regex($1-, /^:(?:[^\.!@]*\.)?(?:tmi|irc)\.twitch\.tv (\d\d\d) /i)) {
      var %tok = $regml(1)
      if (%tok isnum 1-5 || %tok == 372 || %tok == 375 || %tok == 376) {
        return
      }
      .parseline -iqptu0 :tmi.twitch.tv $2-
    }
    elseif ($regex($1-, /^(@\S+ [^!@\s]+![^@\s]+@\S+) WHISPER \S+ (:.*)$/i)) {
      .parseline -iqptu0 $regml(1) PRIVMSG $me $regml(2)
    }
    elseif ($regex($1-, /^:?(?:[^\.!@]*\.)?(?:tmi|irc)\.twitch\.tv /i)) {
      .parseline -iqptu0 $iif(:* iswm $1, :tmi.twitch.tv, tmi.twitch.tv) $2-
    }
    else {
      .parseline -iqptu0 $1-
    }
  }
}

alias -l mTwitch.GroupChat.Connect {
  var %sock = mTwitch.GroupChat. $+ $1
  mTwitch.GroupChat.Cleanup %sock
  sockopen %sock $$hfind(mTwitch.isServer.list, group, 1, w).data 443
  sockmark %sock $1-
}

alias -l mTwitch.GroupChat.Buffer {
  if ($0 < 2 || !$sock($1)) { 
    return 
  }
  elseif (!$sock($1).sq) {
    sockwrite -n $1-
  }
  else {
    bunset &queue
    bunset &buffer
    bset -t &queue 1 $2- $+ $crlf
    noop $hget($1, sendbuffer, &buffer)
    bcopy -c &buffer $calc($bvar(&buffer, 0) +1) &queue 1 -1
    hadd -mb $1 sendbuffer &buffer
  }
}

alias -l mTwitch.GroupChat.Cleanup {
  if ($sock($1)) {
    sockclose $1
  }
  if ($hget($1)) {
    hfree $1
  }
  if ($timer($1)) {
    $+(.timer, $1) off
  }
}

on *:START:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->GroupChat] mTwitch.Core.mrc is required
    .unload -rs $qt($script)
  }
}

on $*:PARSELINE:out:/^PASS (oauth\x3A[a-zA-Z\d]{30,32})$/:{
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup) {
    mTwitch.GroupChat.Connect $cid $me $regml(1)
  }
}

on $*:PARSELINE:out:/^PRIVMSG (?!=jtv|#)(\S+) :(.*)$/i:{
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup) {
    if ($sock(mTwitch.GroupChat. $+ $cid) && $hget(mTwitch.GroupChat. $+ $cid, loggedIn)) {
      mTwitch.GroupChat.Buffer $+(mTwitch.GroupChat. $+ $cid) PRIVMSG jtv :/w $regml(1) $regml(2)
    }
    halt
  }
}

on *:DISCONNECT:{
  if ($mTwitch.isServer && $sock(mTwitch.GroupChat. $+ $cid)) {
    mTwitch.GroupChat.Cleanup mTwitch.GroupChat.Connection $+ $cid
  }
}

on *:SOCKOPEN:mTwitch.GroupChat.*:{
  tokenize 32 $sock($sockname).mark
  if ($0 !== 3) {
    mTwitch.GroupChat.Cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -s [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed to open; retrying...
    mTwitch.GroupChat.Cleanup %sock
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
  else {
    mTwitch.GroupChat.Buffer $sockname PASS $3
    mTwitch.GroupChat.Buffer $sockname NICK $2
    mTwitch.GroupChat.Buffer $sockname USER $2 ? * :Twitch User
    mTwitch.GroupChat.Buffer $sockname CAP REQ :twitch.tv/commands twitch.tv/tags twitch.tv/membership
  }
}

on *:SOCKWRITE:mTwitch.GroupChat.*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    mTwitch.GroupChat.Cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -s [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed; attempting to reconnect...
    mTwitch.GroupChat.Cleanup $sockname
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
  elseif ($hget($sockname, sendbuffer, &buffer) && $calc(16384 - $sock($sockname).sq) > 0) {
    var %bytes = $v1
    if (%bytes >= $bvar(&buffer, 0)) {
      sockwrite $sockname &buffer
      hdel $sockname sendbuffer
    }
    else {
      sockwrite %bytes $sockname &buffer
      bcopy -c &buffer 1 &buffer $calc(%bytes + 1) -1
      hadd -mb $sockname sendbuffer &buffer
    }
  }
}

on *:SOCKREAD:mTwitch.GroupChat.*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    mTwitch.GroupChat.Cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -s [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed; attempting to reconnect...
    mTwitch.GroupChat.Cleanup $sockname
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
  else {
    scid $1
    var %t
    sockread %t
    while ($sockbr) {
      mTwitch.GroupChat.Parse $regsubex(%t, /(?:^[\r\n\s]+)|(?:[\r\n\s]+$)/i, )
      sockread %t
    }
  }
}

on *:SOCKCLOSE:mTwitch.GroupChat.*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    mTwitch.GroupChat.Cleanup $sockname
  }
  else {
    scid $1
    mTwitch.GroupChat.Cleanup $sockname
    echo $color(info) -s [mTwitch->GroupChat] Connection to Twitch Group-Chat server lost; attempting to reconnect...
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
}
