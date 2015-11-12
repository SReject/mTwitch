alias mTwitch.has.OnlinePopup return 0000.0000.0001

on *:LOAD: {
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->OnlinePopup] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
  else {
    hmake mTwitch.OnlinePopup
    if ($isfile($scriptdirmTwitch.OnlinePopup.dat)) {
      hload mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
    }
    else {
      hsave mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
    }
  }
}
on *:START: { 
  if (!$mTwitch.has.Core) {
    echo $color(info) -a [mTwitch->OnlinePopup] mTwitch.Core.mrc is required
    .timer 1 0 .unload -rs $qt($script)
  }
  else {
    hmake mTwitch.OnlinePopup
    if ($isfile($scriptdirmTwitch.OnlinePopup.dat)) {
      hload mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
    }
    else {
      hsave mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
    }
  }
}
on *:SIGNAL:mTwitch.Notifications.Online:{
  var %TipName = mTwitch.OnlinePopup.Tip. $+ $1
  if (!$tip(%TipName)) {
    noop $tip(%TipName, Streamer Online, $mid($1, 2-) is streaming: $+ $crlf $+  $+ $2-, $null, $null, 15, $$mTwitch.GetWid($1), $null)
  }
}
menu channel {
  $submenu($mTwitch.OnlinePopup.menu($1))
}
alias mTwitch.OnlinePopup.Menu {
  if (!$mTwitch.isServer) {
    return
  }
  elseif ($1 == begin || $1 == end) {
    return -
  }
  elseif ($1 == 1) {
    if ($hget(mTwitch.OnlinePopup, #)) {
      return Disable Online Popup: mTwitch.OnlinePopup -r #
    }
    else {
      return Enable Online Popup: mTwitch.OnlinePopup #
    }
  }
}
alias -l mTwitch.OnlinePopup {
  if ($1 === -r && $0 == 2) {
    if ($hget(mTwitch.OnlinePopup, $2)) {
      hdel mTwitch.OnlinePopup $2
      hsave mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
    }
  }
  else if (!$hget(mTwitch.OnlinePopup, $1)) {
    hadd -m mTwitch.OnlinePopup $1 $true
    hsave mTwitch.OnlinePopup $qt($scriptdirmTwitch.OnlinePopup.dat)
  }
}
