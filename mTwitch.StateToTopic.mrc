on *:LOAD:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->StateToTopic] mTwitch.Core.mrc is required
    .unload -rs $qt($script)
  }
  elseif (1.?* !iswm $JSONVersion(short)) {
    echo $color(info) -a [mTwitch->StateToTopic] JSONForMirc v1.x is required
    .unload -rs $qt($script)
  }
  else {
    mTwitch.StateToTopic
  }
}
on *:START:{
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->StateToTopic] mTwitch.Core.mrc is required
    .unload -rs $qt($script)
  }
  elseif (1.?* !iswm $JSONVersion(short)) {
    echo $color(info) -a [mTwitch->StateToTopic] JSONForMirc v1.x is required
    .unload -rs $qt($script)
  }
  else {
    mTwitch.StateToTopic
  }
}
on *:UNLOAD: {
  .timermTwitch.StateToTopic off
}
on me:*:JOIN:#:{
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, # $+ .ChanTopic)) {
      parseline -itqpn :jtv!jtv@twitch.tv TOPIC # : $+ $v1
    }
    else {
      .timermTwitch.StateToTopic.onJoin 1 5 mTwitch.StateToTopic 
    }
  }
}
on *:SIGNAL:/^mTwitch\.(ChatState\.(Un)?(Slow|R9K|FollowersOnly|SubsOnly))|((Un)Host)$/i:{
  mTwitch.StateToTopic.Set $1
}
alias mTwitch.has.StateToTopic {
  return 0000.0000.0012
}
alias mTwitch.StateToTopic {
  if ($isid || $0) {
    return
  }
  .timermTwitch.StateToTopic -io 1 300 mTwitch.StateToTopic
  hmake mTwitch.StateToTopic 1
  var %Table = mTwitch.StateToTopic
  var %ConnIndex = 0
  var %ConnLength = $scon(0)
  while (%ConnIndex < %ConnLength) {
    inc %ConnIndex
    scon %ConnIndex
    if ($status == connected && $mTwitch.isServer && $chan(0)) {
      var %ChanLength = $v1
      var %ChanIndex = 0
      var %Streams
      while (%chanIndex < %ChanLength) {
        inc %ChanIndex
        var %Chan = $lower($chan(%ChanIndex))
        if ($me ison %chan && !$hget(%Table, %Chan)) {
          hadd %table %Chan -
          %Streams = $addtok(%Streams, $mTwitch.UrlEncode($lower($iif(#* iswm %Chan, $mid(%Chan, 2-), %Chan))), 44)
          if ($len(%Streams) >= 2500 || (%ConnIndex == %ConnLength && %ChanIndex == %ChanLength) || !$calc($numtok(%Streams, 44) % 100)) {
            JSONOpen -uw mTwitch.StateToTopic https://api.twitch.tv/kraken/streams?limit=100&channel= $+ %Streams
            JSONHttpHeader mTwitch.StateToTopic Client-ID e8e68mu4x2sxsewuw6w82wpfuyprrdx
            JSONHttpFetch  mTwitch.StateToTopic
            %Streams = $null
            if (!$JSONError && $JSON(mTwitch.StateToTopic).HttpStatus == 200) {
              noop $JSONForEach($JSON(mTwitch.StateToTopic, streams), mTwitch.StateToTopic.UpdateStreamState)
            }
            JSONClose mTwitch.StateToTopic
          }
        }
      }
    }
  }
  noop $hfind(%Table, *, 0, w, mTwitch.StateToTopic.Set $1-)
  hfree %Table
}

alias mTwitch.StateToTopic.UpdateStreamState {
  var %chan = $chr(35) $+ $JSON($1, channel, name).value
  var %online = $hget(mTwitch.StreamState, %chan $+ . $+ StreamOnline)
  var %hadd = hadd -m mTwitch.StreamState %chan $+ .
  %hadd $+ StreamOnline $true
  %hadd $+ StreamStart $mTwitch.ConvertTime($JSON($1, created_at).value)
  %hadd $+ StreamGame $JSON($1, game).value
  %hadd $+ StreamTitle $JSON($1, channel, status).value
  %hadd $+ StreamIsMature $JSON($1, channel, mature).value
  if (!%Online) {
    .signal mTwitch.StreamOnline $mid(%chan, 2-)
  }
  hadd -m mTwitch.StateToTopic %chan $true
}
alias -l mTwitch.StateToTopic.Set {
  var %item = $lower(#$1), %Table = mTwitch.StreamState, %State, %Game, %Title, %Mature, %Start, %FolOnly, %SubOnly, %Slow, %R9K, %Topic
  if (!$hfind(%Table, %item $+ .*, 1, w)) {
    %Topic = 04Offline
  }
  else {
    if ($hget(mTwitch.StateToTopic, %item) == -) {
      if ($hget(%Table, %item $+ .StreamOnline)) {
        .signal mTwitch.StreamOffline $mid(%item, 2-)
      }
      %State = Offline
      hadd -m %Table %item $+ .StreamOnline $false
    }
    %State   = $iif($hget(%table, %Item $+ .StreamOnline) , Online, Offline)
    %Start   = $hget(%Table, %Item $+ .StreamStart)
    %Game    = $hget(%Table, %Item $+ .StreamGame)
    %Title   = $hget(%Table, %Item $+ .StreamTitle)
    %Mature  = $hget(%Table, %Item $+ .StreamIsMature)
    %FolOnly = $hget(%Table, %Item $+ .ChatFollowersOnly)
    %SubOnly = $hget(%Table, %Item $+ .ChatSubOnly)
    %Slow    = $hget(%Table, %Item $+ .ChatSlow)
    %R9k     = $hget(%Table, %Item $+ .ChatR9K)

    ;; Online/Offline status
    if (%State == Online) {
      %Topic = $+($chr(3), 12Online since $chr(15), $asctime(%Start, ddd mm HH:nn))
    }
    else {
      %Topic = $+($chr(3), 04Offline, $chr(15))
    }

    ;; game title and mature
    if (%Game) {
      %Topic = %Topic $+($chr(3), 12Playing, $chr(15), :) %Game
    }
    if (%Title) {
      %Topic = %Topic $+($chr(3), 12Title, $chr(15), :) %Title
    }
    if (%Mature) {
      %Topic = %Topic [Mature]
    }

    ;; Followers-only chat mode
    if (%FolOnly !== $null) {
      if (%FolOnly == 0) {
        %Topic = %Topic [Followers Only]
      }
      elseif (%FolOnly !== -1) {
        %Topic = %Topic [Followers Only: $+ %FolOnly $+ ]
      }
    }

    ;; Sub-only chat mode
    if (%SubObly) {
      %Topic = %Topic [Subs Only]
    }

    ;; Slow chat mode
    if (%Slow) {
      %Topic = %Topic [Slow: $+ %Slow]
    }

    ;; R9K mode   
    if (%R9k) {
      %Topic = %Topic [R9K]
    }
  }
  if (%Topic !== $hget(mTwitch.StreamState, %item $+ .ChanTopic)) {
    hadd -m mTwitch.StreamState $+(%item, .ChanTopic) %Topic
    scon -at1 mTwitch.StateToTopic.Update $1 $unsafe(%Topic)
  }
}
alias -l mTwitch.StateToTopic.Update {
  if ($mTwitch.isServer && $me ison $1 && $chan($1).topic !== $2-) {
    .parseline -iqtn :jtv!jtv@twitch.tv TOPIC $1 : $+ $2-
  }
}
