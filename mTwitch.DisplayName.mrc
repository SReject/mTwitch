#mTwitch.DisplayName.Localization on
#mTwitch.DisplayName.Localization end
alias mTwitch.has.DisplayName {
  return 0000.0000.0011
}

alias mTwitch.Localization {
  var %state = $group(#mTwitch.DisplayName.Localization)
  if ($isid) {
    if ($group(#mTwitch.DisplayName.Localization) == on) {
      return $true
    }
    return $false
  }
  
  if (!$0) {
    echo -a [mTwitch] Display Name localization is $group(#mTwitch.DisplayName.Localization)
  }
  elseif ($1 == on || $1 == enable) {
    .enable #mTwitch.DisplayName.Localization
  }
  elseif ($1 == off || $1 == disable) {
    .disable #mTwitch.DisplayName.localization
  }
  elseif ($1 == toggle) {
    $iif(%state == on, .disable, .enable) #mTwitch.DisplayName.localization
  }
  else {
    echo -a [mTwitch] /mTwitch.Localization: invalid parameters.
  }
}

on *:CONNECT:{
  if ($mTwitch.isServer) {
    JSONOpen -uw mTwitch_NameFix https://api.twitch.tv/kraken/users?login= $+ $mTwitch.UrlEncode($me)
    JSONHttpHeader mTwitch_NameFix Client-ID e8e68mu4x2sxsewuw6w82wpfuyprrdx
    JSONHttpHeader mTwitch_NameFix Accept application/vnd.twitchtv.v5+json
    JSONHttpFetch mTwitch_NameFix
    if (!$JSONError) {
      var %dnick = $remove($JSON(mTwitch_NameFix, users, 0, display_name).value, $chr(32), $cr, $lf)
      if ($mTwitch.localization || !$regex(%dnick, [\x80-\xFF])) && (%dnick !== $null && %dnick !=== $me) {
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
    if ($mTwitch.localization || !$regex(%dnick, [\x80-\xFF])) && (%dnick !== $null && %dnick !=== %nick) {
      %tags = %tags $+ $chr(59) $+ user-name= $+ %nick
      .parseline -it %tags $+(:, %dnick, %param)
    }
  }
}