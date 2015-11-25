on *:CONNECT:{
  if ($mTwitch.isServer) {
    JSONOpen -u mTwitch_NameFix https://api.twitch.tv/kraken/users/ $+ $mTwitch.UrlEncode($me)
    if (!$JSONError && $remove($JSON(mTwitch_NameFix, display_name), $chr(32), $cr, $lf) !=== $me) {
      .parseline -iqtu0 $+(:, $me, !, $me, @, $me, .tmi.twitch.tv) NICK $+(:, $v2)
    }
    JSONClose mTwitch_NameFix
  }
}

on $*:PARSELINE:in:/^(@\S+) \x3A([^!@\s]+)(![^@\s]+@\S+ PRIVMSG \x23\S+ \x3A.*)$/:{
  if ($mTwitch.isServer) {
    tokenize 32 $parseline
    var %tags = $regml(1), %nick = $regml(2), %param = $regml(3), %dnick = $remove($mTwitch.MsgTags(%tags, display-name), $chr(32), $cr, $lf)
    if (%dnick !=== %nick) {
      .parseline -itu0 %tags $+(:, %dnick, %param)
    }
  }
}
