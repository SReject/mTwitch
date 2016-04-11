alias mTwitch.has.DisplayName {
  return 0000.0000.0006
}

on *:CONNECT:{
  if ($mTwitch.isServer) {
    JSONOpen -u mTwitch_NameFix https://api.twitch.tv/kraken/users/ $+ $mTwitch.UrlEncode($me)
    if (!$JSONError) {
      var %dnick = $remove($JSON(mTwitch_NameFix, display_name), $chr(32), $cr, $lf)
      if (%dnick !=== $me) {
        .parseline -iqt $+(:, $me, !, $me, @, $me, .tmi.twitch.tv) NICK $+(:, %dnick)
      }
    }
    JSONClose mTwitch_NameFix
  }
}

on $*:PARSELINE:in:/^(@\S+) \x3A([^!@\s]+)(![^@\s]+@\S+ PRIVMSG \x23?\S+ \x3A.*)$/:{
  var %tags = $regml(1), %nick = $regml(2), %param = $regml(3), %dnick
  if ($mTwitch.isServer) {
    %dnick = $remove($mTwitch.xtags($regml(1), display-name), $chr(32), $cr, $lf)
    if ($len(%dnick) && %dnick !=== %nick) {
      .parseline -it %tags $+(:, %dnick, %param)
    }
  }
}
