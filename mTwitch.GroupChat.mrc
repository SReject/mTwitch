alias mTwitch.has.GroupChat {
  return 0000.0000.0014
}

alias -l mTwitch.GroupChat.Parse {
  mTwitch.Debug -i GroupChat Parsing~ $+ $1-
  var %sock = $sockname
  if ($regex($1-, /^PING (:.*)$/)) {
    mTwitch.GroupChat.Buffer %sock PONG $regml(1)
  }
  else {
    if (!$hget(%sock, loggedIn)) {
      if ($regex($1-, /^:(?:tmi|irc)\.(?:chat\.)?twitch\.tv (\d\d\d) \S+ :\S*$/i)) {
        hadd -m $sockname loggedIn $true
      }
      else {
        if ($regex($1-, /^:(?:tmi|irc)\.(?:chat\.)?twitch\.tv NOTICE \S+ :Error logging in$/)) {
          mTwitch.GroupChat.Cleanup $sockname
          echo $color(info) -a [mTwitch->GroupChat] Invalid oauth token; stopping Twitch Group-Chat connection attempts.
          halt
        }
        return
      }
    }
    if ($regex($1-, /^:(?:[^\.!@]*\.)?(?:tmi|irc)\.(?:chat\.)?twitch\.tv CAP /i)) {
      return
    }
    elseif ($regex($1-, /^:(?:[^\.!@]*\.)?(?:tmi|irc)\.(?:chat\.)?twitch\.tv (\d\d\d) /i)) {
      var %tok = $regml(1)
      if (%tok isnum 1-5 || %tok == 372 || %tok == 375 || %tok == 376) {
        return
      }
      .parseline -iqpt :tmi.twitch.tv $2-
    }
    elseif ($regex($1-, /^(@\S+ [^!@\s]+![^@\s]+@\S+) WHISPER \S+ (:.*)$/i)) {
      .parseline -iqpt $regml(1) PRIVMSG $me $regml(2)
    }
    elseif ($regex($1-, /^:?(?:[^\.!@]*\.)?(?:tmi|irc)\.(?:chat\.)?twitch\.tv /i)) {
      .parseline -iqpt $iif(:* iswm $1, :tmi.twitch.tv, tmi.twitch.tv) $2-
    }
    else {
      .parseline -iqpt $1-
    }
  }
}

alias -l mTwitch.GroupChat.Connect {
  var %sock = mTwitch.GroupChat. $+ $1, %serv
  mTwitch.GroupChat.Cleanup %sock
  if ($hfind(mTwitch.isServer.list, group, 1, 2).data) {
    %serv = $v1
    mTwitch.Debug -i GroupChat Connect~Attempting to connect to %serv on port 443
    sockopen %sock %serv 443
    sockmark %sock $1-
  }
  else {
    mTwitch.Debug -e GroupChat Connect~Unable to locate a valid group-chat server
    echo $color(info) -s [mTwitch->GroupChat] Unable to locate a valid group chat server
  }
}

alias -l mTwitch.GroupChat.Buffer {
  if (!$sock($1)) {
    return
  }
  else {
    var %hsize, %space, %size
    bunset &buffer
    %hsize = $hget($1, sendbuffer, &buffer)
    if ($0 > 1) {
      mTwitch.Debug -i GroupChat Buffer~Adding to sendbuffer: $2-
      bset -t &buffer $calc($bvar(&buffer,0) +1) $2- $+ $crlf
    }
    if ($bvar(&buffer, 0) && $calc(16384 - $sock($1).sq) > 0) {
      %space = $v1
      %size = $bvar(&buffer, 0)
      if (%space >= %size) {
        sockwrite $1 &buffer
        if (%hsize) {
          hdel $1 sendbuffer
        }
      }
      else {
        sockwrite -b $1 %space &buffer
        bcopy -c &buffer 1 &buffer $calc(%space +1) -1
        hadd -mb $1 sendbuffer &buffer
      }
    }
    elseif (!$sock($1).sq && !$bvar(&buffer, 0)) {
      mTwitch.debug -i2 GroupChat Buffer~All data sent.
    }
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
  var %oauth = $regml(1)
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup) {
    mTwitch.Debug -i GroupChat~Captured twitch connection attempt; attempting to connect to group-chat servers
    mTwitch.GroupChat.Connect $cid $me %oauth
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
    mTwitch.Debug -i2 GroupChat~Disconnected from twitch's chat interface; disconnecting from groupchat server
    mTwitch.GroupChat.Cleanup mTwitch.GroupChat.Connection $+ $cid
  }
}

on *:SOCKOPEN:mTwitch.GroupChat.*:{
  tokenize 32 $sock($sockname).mark
  if ($0 !== 3) {
    mTwitch.Debug -e GroupChat~State lost; cleaning up
    mTwitch.GroupChat.Cleanup $sockname
  }
  elseif ($sockerr) {
    scid $1
    echo $color(info) -s [mTwitch->GroupChat] Connection to Twitch Group-Chat server failed to open; retrying...
    mTwitch.Debug -w GroupChat Open~Connection to Twitch group-chat server failed to open; retrying...
    mTwitch.GroupChat.Cleanup %sock
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
  else {
    mTwitch.Debug -i2 GroupChat~Connection to $sock($sockname).addr $+ : $+ $sock($sockname).port established; Sending nick and oauth
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
    mTwitch.Debug -e GroupChat Write~Connection to Twitch Group-Chat server failed; attempting to reconnect...
    mTwitch.GroupChat.Cleanup $sockname
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
  else {
    mTwitch.GroupChat.Buffer $sockname
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
    mTwitch.Debug -e GroupChat Read~Connection to Twitch Group-Chat server failed; attempting to reconnect...
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
    mTwitch.Debug -e GroupChat Close~Connection to Twitch Group-Chat server failed; attempting to reconnect...
    .timer 1 0 mTwitch.GroupChat.Connect $1-
  }
}