alias mTwitch.has.DisplayName {
  return 0000.0000.0008
}

on *:CONNECT:{
  if ($mTwitch.isServer) {
    JSONOpen -uw mTwitch_NameFix https://api.twitch.tv/kraken/users/ $+ $mTwitch.UrlEncode($me)
    JSONUrlHeader mTwitch_NameFix Client-ID e8e68mu4x2sxsewuw6w82wpfuyprrdx
    JSONUrlGet mTwitch_NameFix
    if (!$JSONError) {
      var %dnick = $remove($JSON(mTwitch_NameFix, display_name), $chr(32), $cr, $lf)
      if ($len(%dnick) && %dnick !=== $me) {
        .parseline -iqt $+(:, $me, !, $me, @, $me, .tmi.twitch.tv) NICK $+(:, %dnick)
      }
    }
    JSONClose mTwitch_NameFix
  }
}

on $*:PARSELINE:in:/^(@\S+) \x3A([^!@\s]+)(![^@\s]+@\S+ PRIVMSG \x23?\S+ \x3A.*)$/:{
  var %tags = $regml(1), %nick = $regml(2), %param = $regml(3), %dnick
  if ($mTwitch.isServer) {
    %dnick = $remove($mTwitch.xtags(%tags, display-name), $chr(32), $cr, $lf)
    if ($len(%dnick) && %dnick !=== %nick) {
      %tags = %tags $+ $chr(59) $+ user-name= $+ $nick
      .parseline -it %tags $+(:, %dnick, %param)
    }
  }
}
