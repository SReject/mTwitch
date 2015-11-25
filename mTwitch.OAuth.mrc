alias mTwitch.has.OAuth {
  return 0000.0000.0002
}

alias mTwitch.OAuth.Config {
  dialog -m mTwitch.OAuth mTwitch.OAuth
}

alias mTwitch.OAuth.Generate {
  var %uri, %clientid, %secret, %err, %port = 80, %url
  %uri      = $mTwitch.Storage.Get(OAuth, app_uri)
  %clientid = $mTwitch.Storage.Get(OAuth, app_clientid)
  %secret   = $mTwitch.Storage.Get(OAuth, app_secret)
  if (!$len(%uri)) {
    %err = Twitch App Redirect URI not specified
  }
  elseif (!$regex(%uri, /^http:\/\/localhost(?::\d+)?$/)) {
    %err = Specified Twitch App Redirect URI invalid
  }
  elseif (!$len(%clientId)) {
    %err = Twitch App Client Id not specified
  }
  elseif (!$regex(%clientId, /^(?:[a-z\d]{30,32})$/i)) {
    %err = Specified Twitch App Client Id invalid
  }
  elseif (!$len(%secret)) {
    %err = Twitch App Secret not specified
  }
  elseif (!$regex(%secret, /^(?:[a-z\d]{30,32})$/i)) {
    %err = Specified Twitch App Secret invalid
  }
  elseif ($sock(mTwitch.OAuth.Listener)) {
    %err = mTwitch OAuth listening socket in use
  }
  else {
    if ($regex(%uri,/:(\d+)$/)) {
      %port = $regml(1)
    }
    if (%port !isnum 1-65535) {
      %err = Specified Twitch App Redirect Port invalid; must be a numerical value between 1 and 65535 (inclusive)
    }
  }
  :error
  %err = $iif($error, $v1, %err)
  if (%err) {
    echo $color(info) -a [mTwitch->OAuth] %err
  }
  else {
    %uri = $mTwitch.OAuth.UrlEncode(%uri)
    socklisten mTwitch.OAuth.Listener %port
    sockmark mTwitch.OAuth.Listener %clientId %secret %uri
    %url = https://api.twitch.tv/kraken/oauth2/authorize?response_type=code
    %url = %url $+ &scope=user_read+user_blocks_edit+user_blocks_read+user_follows_edit+user_subscriptions+channel_read+channel_editor+channel_commercial+channel_stream+channel_subscriptions+channel_check_subscription+chat_login
    %url = %url $+ &redirect_uri= $+ %uri
    %url = %url $+ &client_id= $+ %clientId
    run %url
    $+(.timer, mTwitch.OAuth.Listener) -oi 1 30 mTwitch.OAuth.Cleanup mTwitch.OAuth.Listener
  }
}

alias -l mTwitch.OAuth.UrlEncode {
  return $regsubex($1-, /([^a-z\d])/g, % $+ $base($asc(\t), 10, 16, 2))
}

alias -l mTwitch.OAuth.Cleanup {
  if ($sock($1)) {
    sockclose $v1
  }
  if ($hget($1)) {
    hfree $v1
  }
  if ($timer($1)) {
    $+(.timer, $1) off
  }
}

dialog -l mTwitch.OAuth {
  title "mTwitch OAuth Token Config"
  size -1 -1 376 376
  option pixels
  text "For mTwitch OAuth token generator to function you will need to create a", 1, 5 6 365 16
  link "Twitch App", 2, 5 22 55 16
  text "(use 'http://localhost' as the Redirect URI) and then fill in the", 3, 61 22 309 16
  text "following details about your app:", 4, 5 38 365 16
  box "App Redirect URI", 8, 5 63 365 115
  text "The Redirect URI specified when creating your Twitch App. If the default web-access port(80) is in use by another application on your machine, you may use 'http://localhost:PORT' (where port is the port number) in your twitch app instead", 9, 20 83 335 55
  edit "", 10, 20 144 335 21
  box "App Client Id", 11, 5 178 365 75
  text "The Client Id given to you by twitch after creating your app", 12, 20 198 335 16
  edit "", 13, 20 218 335 21
  box "App Secret", 14, 5 253 365 87
  text "The Secret given to you by twitch after creating your app and clicking 'New Secret'", 15, 20 273 335 32
  edit "", 16, 20 306 335 21
  button "Save", 17, 215 343 75 25
  button "Cancel", 18, 294 343 75 25, ok cancel
}

on *:LOAD:{
  mTwitch.OAuth.Config
}

on *:UNLOAD:{
  noop $mTwitch.Storage.Del(OAuth, *).wildcard
}

on *:DIALOG:mTwitch.OAuth:init:0:{
  if ($hget(mTwitch.OAuth)) {
    if ($mTwitch.Storage.Get(OAuth, app_uri)) {
      did -ra $dname 10 $v1
    }
    if ($mTwitch.Storage.Get(OAuth, app_clientid)) {
      did -ra $dname 13 $v1
    }
    if ($mTwitch.Storage.Get(OAuth, app_secret)) {
      did -ra $dname 16 $v1
    }
  }
  did -f $dname 10
}

on *:DIALOG:mTwitch.OAuth:sclick:2:{
  run http://www.twitch.tv/kraken/oauth2/clients/new
}

on *:DIALOG:mTwitch.OAuth:sclick:17:{
  if (!$regex($did($dname, 10).text, /^http:\/\/localhost(?::\d+)?$/)) {
    did -f $dname 10
    noop $input(The specified Twitch App Redirect URI is invalid; please try again, o, Invalid App URI)
  }
  elseif (!$regex($did($dname, 13).text, /^(?:[a-z\d]{30,32})$/i)) {
    did -f $dname 13
    noop $input(The specified Twitch App Client Id is invalid; please try again, o, Invalid App Client Id)
  }
  elseif (!$regex($did($dname, 16).text, /^(?:[a-z\d]{30,32})$/i)) {
    did -f $dname 16
    noop $input(The specified Twitch App Secret Key is invalid; please try again, o, Invalid App Secret Key)
  }
  else {
    noop $mTwitch.Storage.Del(OAuth, *)
    noop $mTwitch.Storage.Add(OAuth, app_uri, $did($dname, 10).text)
    noop $mTwitch.Storage.Add(OAuth, app_clientid, $did($dname, 13).text)
    noop $mTwitch.Storage.Add(OAuth, app_secret, $did($dname, 16)
  }
}

on *:SOCKLISTEN:mTwitch.OAuth.Listener:{
  if ($sockerr) {
    echo $color(info) -a [mTwitch->OAuth] Sock Listen Error
  }
  else {
    var %sock = 1
    while ($sock(mTwitch.OAuth.Client $+ %sock)) {
      inc %sock
    }
    %sock = mTwitch.OAuth.Client $+ %sock
    sockaccept %sock
    sockmark %sock $sock($sockname).mark
    $+(.timer, %sock) -io 1 30 mTwitch.OAuth.Cleanup %sock
  }
}

on *:SOCKWRITE:mTwitch.OAuth.Client*:{
  if ($sockerr) {
    mTwitch.OAuth.Cleanup $sockname
    echo $color(info) -a [mTwitch->OAuth] Unable to send data to connected client
  }
  elseif (!$sock($sockname).rq && $sock($sockname).mark === closing) {
    mTwitch.OAuth.Cleanup $sockname
  }
}

on *:SOCKREAD:mTwitch.OAuth.Client*:{
  var %w = sockwrite -n $sockname, %headers, %request, %body
  if ($sockerr) {
    mTwitch.OAuth.Cleanup $sockname
    echo $color(info) -a [mTwitch->OAuth] Client sockread error
  }
  elseif ($sock($sockname).mark !== closing) {
    noop $hget($sockname, readBuffer, &buffer)
    sockread $sock($sockname).rq &read
    bcopy -c &buffer $calc($bvar(&buffer, 0) + 1) &read 1 -1
    %headers = $bfind(&buffer, 1, $crlf $+ $crlf)
    %request = $bfind(&buffer, 1, $crlf)
    if (!%headers) {
      hadd -mb $sockname readBuffer &buffer
      return
    }
    elseif ($calc(%headers + 3) < $bvar(&buffer, 0)) {
      %w HTTP 400 BAD_REQUEST
      %w Connection: close
      %w
    }
    elseif (!%request || %request == %headers || %request > 4000) {
      %w HTTP 400 BAD_REQUEST
      %w Connection: close
      %w
    }
    elseif (!$regex(request, $bvar(&buffer, 1, $calc(%request - 1)).text, ^GET (\S+) HTTP\/\d+\.\d+$)) {
      %w HTTP 400 BAD_REQUEST
      %w Connection: close
      %w
    }
    elseif ($left($regml(request, 1), 2) !== /?) {
      %w HTTP 404 NOT_FOUND
      %w Connection: close
      %w
    }
    elseif (!$regex(code, $regml(request, 1), [\?&]code=([a-zA-Z\d]{30,})(?:\?|&|$) )) {
      %w HTTP 400 BAD_REQUEST
      %w Connection: close
      %w
    }
    else {
      mTwitch.OAuth.Cleanup mTwitch.OAuth.Listener
      %w HTTP 200 OK
      %w Connection: close
      %w Content-Type: text/plain
      %w
      %w All Good! You may close this window/tab now.
      tokenize 32 $sock($sockname).mark
      %body = grant_type=authorization_code&client_id= $+ $1 $+ &client_secret= $+ $2 $+ &redirect_uri= $+ $3 $+ &code= $+ $regml(code, 1)
      JSONOpen -uw mTwitchOAuthVerify https://api.twitch.tv/kraken/oauth2/token
      JSONUrlMethod mTwitchOAuthVerify POST
      JSONUrlHeader mTwitchOAuthVerify Content-Length $len(%body)
      JSONUrlGet mTwitchOAuthVerify %body
      if (!$JSONError && $JSON(mTwitchOAuthVerify, access_token) && !$JSONError) {
        echo $color(info) -a [mTwitch->OAuth] OAuth Token: $JSON(mTwitchOAuthVerify, access_token)
      }
      else {
        echo $color(info) -a [mTwitch->OAuth] An error occured while verifying the returned access code
      }
      JSONClose mTwitchOAuthVerify
    }
    sockmark $sockname closing
  }
}

on *:SOCKCLOSE:mTwitch.OAuth.Client*:{
  mTwitch.OAuth.Cleanup $sockname
  if ($sockerr) {
    echo $color(info) -a [mTwitch->OAuth] Client disconnected unexpectedly
  }
}
