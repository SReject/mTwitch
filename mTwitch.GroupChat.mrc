alias mTwitch.has.GroupChat return 0000.0000.0008
on *:START:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->GroupChat] mTwitch.Core.mrc is required
    .unload -rs $qt($script)
  }
}
on $*:PARSELINE:out:/^PASS (oauth\x3A[a-zA-Z\d]{30,32})$/:{
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup) {
    connect $cid $me $regml(1)
  }
}
on $*:PARSELINE:out:/^PRIVMSG (?!=jtv|#)(\S+) :(.*)$/i:{
  if (!$mTwitch.isServer || $mTwitch.isServer().isGroup) {
    return
  }
  if ($sock(mTwitch.groupChatConnection $+ $cid) && $hget(mTwitch.groupChatConnection $+ $cid, loggedIn)) {
    buffer $+(mTwitch.groupChatConnection $+ $cid) PRIVMSG jtv :/w $regml(1) $regml(2)
  }
  halt
}
on *:DISCONNECT:{
  if ($mTwitch.isServer && $sock(mTwitch.GroupChatConnection $+ $cid)) {
    cleanup mTwitch.groupChatConnection $+ $cid
  }
}
on *:SOCKOPEN:mTwitch.groupChatConnection*:{
  tokenize 32 $sock($sockname).mark
  if ($0 !== 3) {
    cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -a [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed to open; retrying...
    cleanup %sock
    .timer 1 0 connect $1-
  }
  else {
    buffer $sockname PASS $3
    buffer $sockname NICK $2
    buffer $sockname USER $2 ? * :Twitch User
    buffer $sockname CAP REQ :twitch.tv/commands twitch.tv/tags twitch.tv/membership
  }
}
on *:SOCKWRITE:mTwitch.groupChatConnection*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -a [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed; attempting to reconnect...
    cleanup $sockname
    .timer 1 0 connect $1-
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
on *:SOCKREAD:mTwitch.groupChatConnection*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -a [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed; attempting to reconnect...
    cleanup $sockname
    .timer 1 0 connect $1-
  }
  else {
    scid $1
    var %t
    sockread %t
    while ($sockbr) {
      parse $regsubex(%t, /(?:^[\r\n\s]+)|(?:[\r\n\s]+$)/i, )
      sockread %t
    }
  }
}
on *:SOCKCLOSE:mTwitch.groupChatConnection*:{
  tokenize 32 $sock($sockname).mark
  if (!$0) {
    cleanup $sockname
  }
  else {
    scid $1
    cleanup $sockname
    echo $color(info) -a [mTwitch->GroupChat] Connection to Twitch Group-Chat server lost; attempting to reconnect...
    .timer 1 0 connect $1-
  }
}

alias -l connect {
  var %sock = mTwitch.groupChatConnection $+ $1
  cleanup %sock
  sockopen %sock $$hfind(mTwitch.chatServerList, group, 1, w).data 443
  sockmark %sock $1-
}
alias -l buffer {
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
alias -l cleanup {
  if ($sock($1)) sockclose $1
  if ($hget($1)) hfree $1
  if ($timer($1)) $+(.timer, $1) off
}
alias -l parse {
  var %sock = $sockname
  if ($regex($1-, /^PING (:.*)$/)) {
    buffer %sock PONG $regml(1)
    return
  }
  if (!$hget(%sock, loggedIn)) {
    if ($regex($1-, /^:(?:tmi|irc)\.twitch\.tv NOTICE \S+ :Error logging in$/)) {
      cleanup $sockname
      echo $color(info) -a [mTwitch->GroupChat] Invalid oauth token; stopping Twitch Group-Chat connection attempts.
      halt
    }
    elseif ($regex($1-, /^:(?:tmi|irc)\.twitch\.tv (\d\d\d) \S+ :\S*$/i)) {
      hadd -m $sockname loggedIn $true
    }
    else {
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
