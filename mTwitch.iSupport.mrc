on $*:PARSELINE:in:/^\x3A(?:[^\.!@]+\.)?(?:tmi|irc)\.twitch\.tv 004 /i:{
  if (!$mTwitch.isServer || $mTwitch.isServer().isGroup) { return }
  var %hash = mTwitch.iSupportSet $+ $cid, %x = 0, %e, %out, %key, %val, %tok, %pre = :tmi.twitch.tv 005 $me, %post = :are supported on this server
  set -u0 $+(%, %hash) $true

  hadd -m %hash NETWORK twitch.tv
  hadd %hash PREFIX (qaohv)~&@%+
  hadd %hash CASEMAPPING ascii
  hadd %hash CHANMODES ,,,
  hadd %hash MODES 50

  .signal -n mTwitch.iSupportSet
  unset -u0 $+(%, %hash)
  %e = $hget(%hash, 0).item
  while (%x < %e) {
    inc %x
    %key = $hget(%hash, %x).item
    %val = $hget(%hash, %key)
    if (%val) {
      %tok = %key $+ = $+ %val
    }
    else {
      %tok = %key
    }
    if ($calc($len(%pre %post) + $len(%out) + 2 + $len(%tok)) > 510) {
      .parseline -iqptnu0 %pre $addtok(%out, %tok, 32) %post
      %out = $null
    }
    else {
      %out = $addtok(%out, %tok, 32)
    }
  }
  if (%out) {
    .parseline -iqptu0n %pre %out %post
  }
  if ($hget(%hash)) hfree %hash
}
alias mTwitch.iSupportSet {
  if ($isid) return
  if ($0 < 1) return
  if (!$($+(%, mTwitch.iSupportSet, $cid), 2)) return
  if (!$mTwitch.isServer || $mTwitch.isServer().isGroup) return
  if ($len($hget(mTwitch.iSupportSet $+ $cid, $1))) {
    return
  }
  else {
    hadd -m mTwitch.iSupportSet $+ $cid $1 $iif($2, $2, $false)
  }
}
alias mTwitch.has.iSupport return 0000.0000.0001
