;; ========================= ;;
;;      PRIVATE ALIASES      ;;
;; ========================= ;;


;; Unescapes tags returned by $mTwitch.xTags
alias -l mTwitch.MsgTagsUnescape {
  if ($1 == :) return $chr(59)
  if ($1 == r) return $cr
  if ($1 == n) return $lf
  if ($1 == s) returnex $chr(32)
  return $1
}


;; Cleans up variable information on the streams state when the channel is exited
alias -l mTwitch.StreamState.Cleanup {
  if ($hget(mTwitch.StreamState)) {
    if (!$0) {
      var %x = 0
      while (%x < $chan(0)) {
        inc %x
        if (!$mTwitch.AmOn($chan(%x), $cid)) {
          hdel -w mTwitch.StreamState $chan(%x) $+ .*
        }
      }
    }
    elseif (!$mTwitch.AmOn($1, $cid)) {
      hdel -w mTwitch.StreamState $1.* 
    }
  }
}


;; ========================= ;;
;;       CAP NEGOCIATES      ;;
;; ========================= ;;


;; When the CAP * LS message is recieved
;; Set a variable to halt mIRC's default action then request all twitch-listed cap modules
on $*:PARSELINE:in:/^\x3A(irc|tmi)\.twitch\.tv CAP \* LS (\x3A.*)$/:{
  var %req = $regml(2)
  if ($mTwitch.isServer) {
    set -e $+(%, $cid, mTwitch.CapAcceptHalt) $true
    .raw CAP REQ %req
  }
}


;; Halt mIRC default CAP handling so mTwitch can handle the negociations
on $*:PARSELINE:out:/^CAP (LIST|END)$/:{
  if ($mTwitch.isServer && $($+(%, $cid, mTwitch.CapAcceptHalt), 2)) {
    .parseline -otn
  }
}


;; Wait for twitch to acknowledge the requested cap modules
;; then indicate to twitch that cap negociations are done
on $*:PARSELINE:in:/^\x3A(irc|tmi)\.twitch\.tv CAP \* ACK \x3A/:{
  if ($mTwitch.isServer && $($+(%, $cid, mTwitch.CapAcceptHalt), 2)) {
    unset $+(%, $cid, mTwitch.CapAcceptHalt)
    .raw CAP END
  }
}


;; ========================= ;;
;;       NETWORK SETTER      ;;
;; ========================= ;;


;; Injects the raw 005 numerical which fills $network with "twitch.tv", $chantypes and $prefix
raw 004:*:{
  if ($mTwitch.isServer) {
    .parseline -itqp :tmi.twitch.tv 005 $me NETWORK=twitch.tv CHANTYPES=# PREFIX=(o)@ :are supported by this server
  }
}


;; ======================= ;;
;;      SMARTER JOINs      ;;
;;======================== ;;


;; Transforms /join stream into /join #stream
on $*:PARSELINE:out:/^JOIN (\S+)$/i:{
  if ($mTwitch.isServer) {
    tokenize 44 $regml(1)
    var %i = 0, %chan, %chans
    while (%i < $0) {
      inc %i
      %chan = $($ $+ %i, 2)
      %chan = $iif(#* iswm %chan, $v2, $chr(35) $+ $v2)
      %chans = $addtok(%chans, %chan, 32)
    }
    if ($1- !=== %chans) {
      .parseline -otn JOIN $replace(%chan, $chr(32), $chr(44))
    }
  }
}


;; transforms join events without a # prefix to one with the prefix
on $*:PARSELINE:in:/^(\x3A[^\s!@]+![^\s@]+@\S+) JOIN ([^#]\S*)$/i:{
  var %user = $regml(1)
  var %chan = $chr(35) $+ $regml(2)
  if ($mTwitch.isServer) {
    parseline -itn %user JOIN %chan
  }
}


;; ============================== ;;
;;       WHISPERS to QUERIES      ;;
;; ============================== ;;


;; Transforms inbound twitch whispers into private message queries
on $*:PARSELINE:in:/^((?:@\S+ )?)(\x3A[^!@ ]+![^@ ]+@\S+) WHISPER (\S+) (\x3A.*)/i:{
  var %Tags   = $regml(1)
  var %User   = $regml(2)
  var %Target = $regml(3)
  var %Msg    = $regml(4)
  if ($mTwitch.IsServer && $me == %Target) {
    .parseline -itp %Tags %User PRIVMSG $me %Msg
  }
}


;; Transforms outbound private message queries into twitch whispers
on $*:PARSELINE:out:/^PRIVMSG ((?!jtv )[^#]\S*) \x3A(.+)$/i:{
  var %Target = $regml(1), %Msg = $regml(2)
  if ($mTwitch.IsServer) {
    .parseline -otnp PRIVMSG jtv :/w $lower(%Target) %Msg
  }
}


;; ============================ ;;
;;      ROOMSTATE TRACKING      ;;
;; ============================ ;;


raw ROOMSTATE:*:{
  if ($mTwitch.isServer) {
    tokenize 32 $rawmsg
    var %Table = mTwitch.StreamState
    if ($me ison $3) {

      ;; slow mode
      if ($msgtags(slow) && $hget(%Table, $3.ChatSlowMode) !== $msgtags(slow).key) {
        hadd -m %Table $3.ChatSlowMode $v2
        .signal mTwitch.ChatState. $+ $iif($v2, Slow $3 $v1, Unslow $3)
      }

      ;; r9k mode      
      if ($msgtags(r9k) && $hget(%Table, $3 $+ .ChatR9KMode) !== $msgtags(r9k).key) {
        hadd -m %table $3 $+ .ChatR9KMode $v2
        .signal mTwitch.ChatState. $+ $iif($v2, R9K, UnR9K) $3
      }

      ;; Subs-only mode
      if ($msgtags(subs-only) && $hget(%Table, $3.ChatSubsOnly) !== $msgtags(subs-only).key) {
        hadd -m %table $3.ChatSubsOnly $v2
        .signal mTwitch.ChatState. $+ $iif($v2, SubsOnly, UnSubsOnly) $3
      }

      ;; Emotes-only mode
      if ($msgtags(emotes-only) && $hget(%Table, $3.ChatEmotesOnly) !== $msgtags(emotes-only).key) {
        hadd -m %table $3.ChatEmotesOnly $v2
        .signal mTwitch.ChatState. $+ $iif($v2, EmotesOnly, UnEmotesOnly) $3
      }

      ;; Followers-only mode
      if ($msgtags(followers-only)) {
        var %val = $hget(%Table, $3.ChatfollowersOnlyMode)
        var %tval = $iif($msgtags(followers-only).key == -1, $false, $iif($v1 == 0, $true, $v1))
        if (%val !== %tval) {
          hadd -m %table $3.ChatFollowersOnlyMode %tval
          .signal mTwitch.ChatState. $+ $iif(%tval == $false, UnFollowersOnly $3, FollowersOnly $3 $iif(%tval > 0, $v1))
        }
      }

    }
    halt
  }
}


raw HOSTTARGET:*:{
  if ($mTwitch.isServer) {
    tokenize 32 $rawmsg
    if ($me ison $3) {
      hadd -m mTwitch.StreamState $3.StreamHosting $iif($4 == -, $false, $v1)
      .signal mTwitch. $+ $iif($4 == -, UnHost $3, Host $3 $v1)
    }
    halt
  }
}


;; =============================== ;;
;;     Manage Sub/Resub events     ;;
;; =============================== ;;


raw USERNOTICE:*:{
  if ($mTwitch.isServer) {
    if ($msgtags(msg-id).key == resub) {
      tokenize 32 $rawmsg
      .parseline -iqtn @ $+ $msgtags :jtv!jtv@tmi.twitch.tv PRIVMSG $3 :04 $+ $mTwitch.MsgTags($msgtags, system-msg)
      .signal mTwitch.ReSub $3 $msgtags(login).key $msgtags(msg-param-months).key $mid($4-, 2-)
      halt
    }
    else {
      ;; new sub? follow? other things?
    }
  }
}


;; ================================ ;;
;;     Hide USERSTATE messages      ;;
;; ================================ ;;


raw USERSTATE:*:{
  if ($mTwitch.isServer) {
    halt
  }
} 


;; ========================================= ;;
;;     Annoying jtv mode message hiding      ;;
;; ========================================= ;;


on $*:PARSELINE:in:/^\x3Ajtv MODE (\S) -o (\S+)$/i:{
  var %chan = $iif(#* iswm $regml(1), $v2, $chr(35) $+ $v2)
  if ($regml(1) !ison %chan && $mTwitch.isServer) {
    .parseline -itn
  }
}


;; ================================ ;;
;;     Halt USERHOST from mIRC      ;;
;; ================================ ;;


on $*:PARSELINE:out:/^USERHOST (\S+)$/i:{
  if ($regml(1) === $me && $mTwitch.isServer) {
    .parseline -otn
  }
}


;; ===================== ;;
;;     CLEANUP CODE      ;;
;; ===================== ;;


on me:*:PART:#:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup #
  }
}


on ^*:DISCONNECT:{
  if ($mTwitch.isServer) {
    mTwitch.StreamState.Cleanup
    unset $+(%, $cid, mTwitch.CapAcceptHalt)
  }
}


on *:UNLOAD:{
  unset $+(%, $cid, mTwitch.CapAcceptHalt)
  if ($hget(mTwitch.StreamState)) {
    hfree mTwitch.StreamState
  }
  .signal -n mTwitch.Core.Unload
}


;; ====================================== ;;
;;     HELPER ALIASES FOR ALL TO USE      ;;
;; ====================================== ;;

;; Returns the core versioning
alias mTwitch.has.core {
  return 0000.0000.0018
}


;; Returns true if the current server is a twitch-chat server
alias mTwitch.isServer {
  if ($isid) {
    if (!$len($1-)) {
      tokenize 32 $server
    }
    if (!$0) {
      return $false
    }
    elseif ($network === twitch.tv || $regex($1-, /^(?:tmi|irc)\.(?:chat\.)?twitch\.tv$/i)) {
      return $true
    }
    return $false
  }
}


;; $mTwitch.AmOn(@Channel, [@cid])
;;     If @cid is not specified, returns $true if you are on the specified twitch channel for the current connection
;;     If @cid is specified, returns true if you are on the specified twitch channel for a connection id other than that cid
alias mTwitch.AmOn {
  if ($0 == 1) {
    if ($mTwitch.isServer && $me ison $1) {
      return $true
    }
  }
  else {
    var %x = $scon(0)
    while (%x) {
      scon %x
      if ($cid != $2 && $status == connected && $mTwitch.isServer && $me ison $1) {
        scon -r
        return $true
      }
      dec %x
    }
    scon -r
  }
}


;; $mTwitch.ConvertTime(@timestamp)[.dur]
;; Takes a twitch provided timestamp and converts it to EPOCH seconds
;; Use $asctime or similar to convert the returned value to a formatted date
;;
;; if .dur is specified, the number of seconds since the input date is returned
alias mTwitch.ConvertTime {
  if ($regex($1-, /^(\d\d(?:\d\d)?)-(\d\d)-(\d\d)T(\d\d)\:(\d\d)\:(\d\d(?:.\d+)?)(?:(?:Z$)|(?:([+-])(\d\d)\:(\d+)))?$/i)) {
    var %month = $gettok(January February March April May June July August September October November December, $regml(2), 32)
    var %day = $ord($base($regml(3), 10, 10))
    var %offset = +0
    var %time
    if ($regml(0) > 6) {
      %offset = $regml(7) $+ $calc($regml(8) * 3600 + $regml(9))
    }
    %time = $calc($ctime(%month %day $regml(1) $regml(4) $+ : $+ $regml(5) $+ : $+ $floor($regml(6))) - %offset)
    if ($asctime(zz) !== 0 && $regex($v1, /^([+-])(\d\d)(\d+)$/)) {
      inc %time $regml(1) $+ $calc($regml(2) * 3600 + $regml(3))
    }
    if ($prop == dur) {
      return $calc($ctime - %time)
    }
    return %time
  }
}


;; $mTwitch.MsgTags(@Taglist, @Tagname).exists
;;   Returns $null if the tag does NOT exist
;;   Returns $true if the tag exists and the prop is .exists
;;   Returns the value if the tag exists
alias mTwitch.MsgTags {
  if (!$isid || $0 < 2) {
    return
  }
  if ($wildtok($iif(@* iswm $1, $mid($1, 2-), $1), $2 $+ =*, 1, 59)) {
    var %tag = $v1
    if ($prop == exists) {
      return $true
    }
    elseif ($mid(%tag, $calc($len($2) + 2) $+ -) !== $null) {
      return $regsubex($v1, /\\(.)/g, $mTwitch.MsgTagsUnescape(\1))
    }
  }
  return
}


;; $mTwitch.UrlEncode(@Input)
;; URL-Encodes the input
alias mTwitch.UrlEncode {
  return $regsubex($1, /(\W| )/g, % $+ $base($asc(\1), 10, 16, 2))
}


;; $mTwitch.ChatIsFollowersOnly(@Channel)[.delay]
;;   Returns $true if the specified channel's chat is in Followers-only mode
;;   If .delay is specified, the time a user must have been following is returned
alias mTwitch.ChatIsFollowersOnly {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1.ChatFollowersOnlyMode)) {
      var %val = $v1
      if ($prop == delay) return %val
      return $true
    }
    return $false
  }
}


;; $mTwitch.ChatIsSubOnly(@Channel)
;;   Returns $true if the specified channel's chat is in subonly mode
alias mTwitch.ChatIsSubOnly {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1.ChatsSubsOnlyMode)) {
      return $true
    }
    return $false
  }
}


;; $mTwitch.ChatIsEmotesOnly(@Channel)
;;   Returns $true if the specified channel's chat is in emotes-only mode
alias mTwitch.ChatIsEmotesOnly {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1.ChatEmotesOnlyMode)) {
      return $true
    }
    return $false
  }
}

;; $mTwitch.ChatIsSlow(@Channel)[.delay]
;;   Returns $true if the specified channel's chat is in slowmode
;;   If .delay is specified, the delay between messages is returned
alias mTwitch.ChatIsSlow {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1.ChatSlowMode)) {
      var %val = $v1
      if ($prop == delay) return %val
      return $true
    }
    return $false
  }
}


;; $mTwitch.ChatIsR9K(@Channel)
;;   Returns $true if the specified channel's chat is in R9K mode
alias mTwitch.ChatIsR9k {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1 $+ .ChatR9KMode)) {
      return $true
    }
    return $false
  }
}


;; $mTwitch.StreamIsHosting
;;   Returns the name of the stream being hosted
;;   If no stream is being hosted, $false is returned
alias mTwitch.StreamIsHosting {
  if ($mTwitch.isServer) {
    if ($hget(mTwitch.StreamState, $1.StreamHosting)) {
      return $v1
    }
    return $false
  }
}
