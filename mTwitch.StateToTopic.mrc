alias mTwitch.has.StateToTopic {
  0000.0000.0008
}

alias mTwitch.StateToTopic {
  if (!$isid && !$0 && $status == connected && $mTwitch.isServer) {
    .timermTwitch.StateToTopic -io 1 300 mTwitch.StateToTopic
    var %x = 1, %streams, %len, %y, %stream, %chan, %since, %game, %title, %topic, %host, %sub, %slow, %r9k
    hmake mTwitch.StateToTopic.Streams 1
    while ($scon(%x)) {
      scon %x
      if ($mTwitch.isServer) {
        %y = 1
        while ($chan(%y)) {
          if ($me ison $v1) {
            hadd mTwitch.StateToTopic.Streams $v2 -
          }
          inc %y
        }
      }
      inc %x
    }
    %x = 1
    while ($hget(mTwitch.StateToTopic.Streams, %x).item) {
      %streams = $addtok(%streams, $mid($v1, 2-), 44)
      if (!$calc($numtok(%streams, 44) % 10) || (%streams && %x == $hget(mTwitch.StateToTopic.Streams, 0))) {
        JSONOpen -u mTwitch.StateToTopic https://api.twitch.tv/kraken/streams?channel= $+ %streams
        if (!$JSONError) {
          %len = $JSON(mTwitch.StateToTopic, streams, length)
          %y = 0
          while (%y < %len) {
            %stream = $JSON(mTwitch.StateToTopic, streams, %y, channel, name)
            %chan = $chr(35) $+ %stream
            %since = $ConvertTime($JSON(mTwitch.StateToTopic, streams, %y, created_at))
            %playing = $JSON(mTwitch.StateToTopic, streams, %y, game)
            %title = $JSON(mTwitch.StateToTopic, streams, %y, channel, status)
            hadd -m mTwitch.StreamState $+(%chan, .online) $true
            hadd -m mTwitch.StreamState $+(%chan, .playing) %playing
            hadd -m mTwitch.StreamState $+(%chan, .title) %title
            hadd -m mTwitch.StateToTopic.Streams %chan Online since %since -- Playing: %playing -- Title: %title
            inc %y
          }
        }
        JSONClose mTwitch.StateToTopic
      }
      inc %x
    }
    %x = 1
    while ($hget(mTwitch.StateToTopic.Streams, %x).item) {
      scon -a mTwitch.StateToTopic.Set $v1 $hget(mTwitch.StateToTopic.Streams, $v1)
      inc %x
    }
    hfree mTwitch.StateToTopic.Streams
  }
}

alias -l mTwitch.StateToTopic.Set {
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup && $me ison $1) {
    var %topic, %sub, %slow, %host, %r9k, %online
    %host = $iif($mTwitch.StreamIsHosting($1), [Hosting: $+ $v1 $+ ])
    %sub = $iif($mTwitch.ChatIsSubOnly($1), [SubOnly])
    %slow = $iif($mTwitch.ChatIsSlow($1).dur, [Slow: $+ $ceil($calc($v1 /60)) $+ m])
    %r9k = $iif($mTwitch.ChatIsR9k($1), [R9K])
    %topic = $iif($2- == -, Offline, %topic) $regsubex($iif(%host || %sub || %slow || %r9k, -- %host %sub %slow %r9k), /\s(?=\x20|$)/g, $chr(32))
    if ($chan($1).topic !== %topic) {
      if (Offline* iswm $chan($1).topic && Online* iswm %topic) {
        .signal mTwitch.Notifications.Online $1 $hget(mTwitch.StreamState, $1.playing)
      }
      .parseline -iqptu0 :jtv!jtv@jtv.twitch.tv TOPIC $1 : $+ %topic
    }
  }
}

alias -l ConvertTime {
  if ($regex($1-, /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)Z$/)) {
    return $asctime($calc($ctime($+($gettok(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec, $regml(2), 32) $ord($base($regml(3), 10, 10)), $chr(44) $regml(1) $regml(4), :, $regml(5), :, $regml(6))) + ( $time(z) * 3600)), mmm dd @ HH:nn:ss)
  }
}

on *:LOAD:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->GroupChat] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
  else {
    mTwitch.StateToTopic
  }
}

on *:START:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->GroupChat] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
}

on *:UNLOAD: {
  .timermTwitch.StateToTopic off
}

on me:*:JOIN:#:{
  if ($mTwitch.isServer) {
    .timermTwitch.StateToTopic.onJoin 1 5 mTwitch.StateToTopic 
  }
}
