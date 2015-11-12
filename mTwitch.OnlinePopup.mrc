alias mTwitch.has.OnlinePopup {
  return 0000.0000.0001
}

alias mTwitch.OnlinePopup.Menu {
  if ($mTwitch.isServer) {
    if ($1 == begin || $1 == end) {
      return -
    }
    elseif ($1 == 1) {
      if ($mTwitch.Storage.Get(OnlinePopup, #)) {
        return Disable Online Popup: noop $!mTwitch.Storage.Del(OnlinePopup,#)
      }
      else {
        return Enable Online Popup: noop $!mTwitch.Storage.Get(OnlinePopup,#)
      }
    }
  }
}

alias -l mTwitch.OnlinePopup.GetWid {
  var %x = 0
  while (%x < $scon(0)) {
    inc %x
    scon %x
    if ($mTwitch.isServer && $window($1)) {
      return $window($1).wid
    }
  }
}

menu channel {
  $submenu($mTwitch.OnlinePopup.menu($1))
}

on *:LOAD: {
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->OnlinePopup] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
}

on *:START: { 
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->OnlinePopup] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
}

on *:SIGNAL:mTwitch.Notifications.Online:{
  var %TipName = mTwitch.OnlinePopup.Tip. $+ $1
  if (!$tip(%TipName)) {
    noop $tip(%TipName, Streamer Online, $mid($1, 2-) is streaming: $+ $crlf $+  $+ $2-, $null, $null, 15, $$mTwitch.OnlinePopup.GetWid($1), $null)
  }
}
