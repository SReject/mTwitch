alias mTwitch.has.StateToTopic {
  0000.0000.0009
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
      if (!$calc($numtok(%streams, 44) % 10) || (%streams && %x == $hget(mTwitch.StateToTopic.Streams, 0).item)) {
        JSONOpen -u mTwitch.StateToTopic https://api.twitch.tv/kraken/streams?channel= $+ %streams
        if (!$JSONError) {
          %len = $JSON(mTwitch.StateToTopic, streams, length)
          %y = 0
          while (%y < %len) {
            %chan = $chr(35) $+ $JSON(mTwitch.StateToTopic, streams, %y, channel, name)
            %since = $mTwitch.ConvertTime($JSON(mTwitch.StateToTopic, streams, %y, created_at))
            %game = $JSON(mTwitch.StateToTopic, streams, %y, game)
            %title = $JSON(mTwitch.StateToTopic, streams, %y, channel, status)
            hadd -m mTwitch.StreamState $+(%chan, .online) $true
            hadd -m mTwitch.StreamState $+(%chan, .playing) %game
            hadd -m mTwitch.StreamState $+(%chan, .title) %title
            hadd -m mTwitch.StateToTopic.Streams %chan Online since %since -- Playing: %game -- Title: %title
            inc %y
          }
        }
        JSONClose mTwitch.StateToTopic
        %streams = $null
      }
      inc %x
    }
    %x = 1
    while ($hget(mTwitch.StateToTopic.Streams, %x).item) {
      scon -a mTwitch.StateToTopic.Set $v1
      inc %x
    }
    hfree mTwitch.StateToTopic.Streams
  }
}

alias -l mTwitch.StateToTopic.Set {
  if ($mTwitch.isServer && !$mTwitch.isServer().isGroup && $me ison $1) {
    var %topic = $hget(mTwitch.StateToTopic.Streams, $1)
    var %host = $iif($mTwitch.StreamIsHosting($1), [Hosting: $+ $v1 $+ ])
    var %sub = $iif($mTwitch.ChatIsSubOnly($1), [SubOnly])
    var %slow = $iif($mTwitch.ChatIsSlow($1).dur, [Slow: $+ $ceil($calc($v1 /60)) $+ m])
    var %r9k = $iif($mTwitch.ChatIsR9k($1), [R9K])
    %topic = $iif(%topic == -, Offline, %topic) $regsubex($iif(%host || %sub || %slow || %r9k, -- %host %sub %slow %r9k), /\s(?=\x20|$)/g, $chr(32))
    if ($chan($1).topic !== %topic) {
      if (Offline* iswm $chan($1).topic && Online* iswm %topic) {
        .signal mTwitch.Notifications.Online $1 $hget(mTwitch.StreamState, $1.playing)
      }
      .parseline -iqptu0 :jtv!jtv@jtv.twitch.tv TOPIC $1 : $+ %topic
    }
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
