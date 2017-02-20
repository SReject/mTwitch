alias mTwitch.has.DisplayName {
  return 0000.0000.0009
}
on *:CONNECT:{
  if ($mTwitch.isServer) {
    JSONOpen -uw mTwitch_NameFix https://api.twitch.tv/kraken/users?login= $+ $mTwitch.UrlEncode($me)
    JSONHttpHeader mTwitch_NameFix Client-ID e8e68mu4x2sxsewuw6w82wpfuyprrdx
    JSONHttpHeader mTwitch_NameFix Accept application/vnd.twitchtv.v5+json
    JSONHttpFetch mTwitch_NameFix
    if (!$JSONError) {
      var %dnick = $remove($JSON(mTwitch_NameFix, display_name).value, $chr(32), $cr, $lf)
      if (%dnick !== $null && %dnick !=== $me) {
        .parseline -iqt $+(:, $me, !, $me, @, $me, .tmi.twitch.tv) NICK $+(:, %dnick)
      }
    }
    JSONClose mTwitch_NameFix
  }
}
on $*:PARSELINE:in:/^(@\S+) \x3A([^!@\s]+)(![^@\s]+@\S+ PRIVMSG \x23?\S+ \x3A.*)$/:{
  var %tags = $regml(1), %nick = $regml(2), %param = $regml(3), %dnick
  if ($mTwitch.isServer) {
    %dnick = $remove($mTwitch.MsgTags(%tags, display-name), $chr(32), $cr, $lf)
    if (%dnick !== $null && %dnick !=== %nick) {
      %tags = %tags $+ $chr(59) $+ user-name= $+ $nick
      .parseline -it %tags $+(:, %dnick, %param)
    }
  }
}
