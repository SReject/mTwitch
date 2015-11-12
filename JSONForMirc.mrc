alias JSONVersion {
  if ($isid) {
    return $iif($1 != short,JSONForMirc v,v) $+ 0.2.2
  }
}
alias JSONError {
  if ($isid) {
    return %JSONError 
  }
}
alias JSONOpen {
  if ($isid) return
  unset %JSONError
  debugger -i 0 Calling /JSONOpen $1-
  var %switches = -, %error, %com, %file
  if (-* iswm $1) {
    %switches = $1
    tokenize 32 $2-
  }
  if ($regex(%switches, ([^dbfuw\-]))) {
    %error = Invalid switches specified: $regml(1)
  }
  elseif ($regex(%switches, ([dbfuw]).*?\1)) {
    %error = Duplicate switch specified: $regml(1)
  }
  elseif ($regex(%switches, /([bfu])/g) > 1) {
    %error = Conflicting switches: $regml(1) $+ , $regml(2)
  }
  elseif (u !isin %switches && w isin %switches) {
    %error = -w switch can only be used with -u
  }
  elseif ($0 < 2) {
    %error = Missing Parameters
  }
  elseif (!$regex($1, /^[a-z][a-z\d_.-]+$/i)) {
    %error = Invalid handler name: Must start with a letter and contain only letters numbers _ . and -
  }
  elseif ($com(JSONHandler:: $+ $1)) {
    %error = Name in use
  }
  elseif (b isin %switches && $0 != 2) {
    %error = Invalid parameter: Binary variable names cannot contain spaces
  }
  elseif (b isin %switches && &* !iswm $2) {
    %error = Invalid parameters: Binary variable names start with &
  }
  elseif (b isin %switches && !$bvar($2, 0)) {
    %error = Invalid parameters: Binary variable is empty
  }
  elseif (f isin %switches && !$isfile($2-)) {
    %error = Invalid parameters: File doesn't exist
  }
  elseif (f isin %switches && !$file($2-).size) {
    %error = Invalid parameters: File is empty
  }
  elseif (u isin %switches && $0 != 2) {
    %error = Invalid parameters: URLs cannot contain spaces
  }
  else {
    .comopen JSONHandler:: $+ $1 MSScriptControl.ScriptControl
    if (!$com(JSONHandler:: $+ $1) || $comerr) {
      %error = Unable to create an instance of MSScriptControl.ScriptControl
    }
    else {
      %com = JSONHandler:: $+ $1
      if (!$com(%com, language, 4, bstr, jscript) || $comerr) {
        %error = Unable to set ScriptControl's language to Javascript
      }
      elseif (!$com(%com, timeout, 4, bstr, 60000) || $comerr) {
        %error = Unable to set ScriptControl's timeout to 60seconds
      }
      elseif (!$com(%com, ExecuteStatement, 1, bstr, $JScript) || $comerr) {
        %error = Unable to add required javascript to the ScriptControl instance
      }
      elseif (u isincs %switches) {
        if (1 OK != $jstry(%com, $jscript(urlInit), $escape($2-).quote)) {
          %error = $gettok($v2, 2-, 32)
        }
        elseif (w !isincs %switches && 0 ?* iswm $jsTry(%com, $jscript(urlParse), status="error").withError) {
          %error = $gettok($v2, 2-, 32)
        }
      }
      elseif (f isincs %switches) {
        if (1 OK != $jstry(%com, $jscript(fileParse), $escape($longfn($2-)).quote)) {
          %error = $gettok($v2, 2-, 32)
        }
      }
      elseif (b isincs %switches) {
        %file = $tempfile
        bwrite $qt(%file) -1 -1 $2
        debugger %com Wrote $2 to $qt(%file)
        if (0 ?* iswm $jstry(%com, $jscript(fileParse), $escape(%file).quote)) {
          %error = $gettok($v2, 2-, 32)
        }
      }
      else {
        %file = $tempfile
        write -n $qt(%file) $2-
        debugger %com Wrote $2- to $qt(%file)
        if (0 ?* iswm $jstry(%com, $jscript(fileParse), $escape(%file).quote)) {
          %error = $gettok($v2, 2-, 32)
        }
      }
      if (!%error) {
        if (d isin %switches) {
          $+(.timer, %com) -o 1 0 JSONClose $1
        }
        Debugger -s %com Successfully created
      }
    }
  }
  :error
  %error = $iif($error, $error, %error)
  reseterror
  if (%file && $isfile(%file)) {
    .remove $qt(%file)
    debugger %com Removed $qt(%file)
  }
  if (%error) {
    if (%com && $com(%com)) {
      .comclose %com
    }
    set -eu0 %JSONError %error
    Debugger -e 0 /JSONOpen %switches $1- --RAISED-- %error
  }
}
alias JSONUrlMethod {
  if ($isid) return
  unset %JSONError
  debugger -i 0 Calling /JSONUrlMethod $1-
  var %error, %com
  if ($0 < 2) {
    %error = Missing parameters
  }
  elseif ($0 > 2) {
    %error = Too many parameters specified
  }
  elseif (!$regex($1, /^[a-z][a-z\d_.\-]+$/i)) {
    %error = Invalid handler name: Must start with a letter and contain only letters numbers _ . and -
  }
  elseif (!$com(JSONHandler:: $+ $1)) {
    %error = Invalid handler name: JSON handler does not exist
  }
  elseif (!$regex($2, /^(?:GET|POST|PUT|DEL)$/i)) {
    %error = Invalid request method: Must be GET, POST, PUT, or DEL
  }
  else {
    var %com = JSONHandler:: $+ $1
    if (1 OK != $jsTry(%com, $JScript(UrlMethod), status="error", $qt($upper($2))).withError) {
      %error = $gettok($v2, 2-, 32)
    }
    else {
      Debugger -s $+(%com,>JSONUrlMethod) Method set to $upper($2)
    }
  }
  :error
  %error = $iif($error, $v1, %error)
  reseterror
  if (%error) {
    set -eu0 %JSONError %error
    if (%com) set -eu0 % [ $+ [ %com ] $+ ] ::Error %error
    Debugger -e $iif(%com, $v1, 0) /JSONUrlMethod %switches $1- --RAISED-- %error
  }
}
alias JSONUrlHeader {
  if ($isid) return
  unset %JSONError
  debugger -i 0 Calling /JSONUrlHeader $1-
  var %error, %com
  if ($0 < 3) {
    %error = Missing parameters
  }
  elseif (!$regex($1, /^[a-z][a-z\d_.\-]+$/i)) {
    %error = Invalid handler name: Must start with a letter and contain only letters numbers _ . and -
  }
  elseif (!$com(JSONHandler:: $+ $1)) {
    %error = Invalid handler name: JSON handler does not exist
  }
  elseif (!$regex($2, /^[a-z_-]+:?$/i)) {
    %error = Invalid header name: Header names can only contain letters, _ and -
  }
  else {
    %com = JSONHandler:: $+ $1
    if (1 OK !== $jsTry(%com, $JScript(UrlHeader), status="error", $escape($regsubex($2, :+$, )).quote, $escape($3-).quote).withError) {
      %error = $gettok($v2, 2-, 32)
    }
    else {
      Debugger -s $+(%com,>JSONUrlHeader) Header $+(',$2,') set to $3-
    }
  }
  :error
  %error = $iif($error, $v1, %error)
  reseterror
  if (%error) {
    set -eu0 %JSONError %error
    if (%com) set -eu0 % [ $+ [ %com ] $+ ] ::Error %error
    Debugger -e $iif(%com, $v1, 0) /JSONUrlMethod %switches $1- --RAISED-- %error
  }
}
alias JSONUrlOption {
  if ($isid) return
  unset %JSONError
  Debugger -i 0 /JSONUrlOption is depreciated and will be removed. Please use /JSONUrlMethod and /JSONUrlHeader
  if ($2 == method) {
    JSONUrlMethod $1 $3-
  }
  else {
    JSONUrlHeader $1-
  }
}
alias JSONUrlGet {
  if ($isid) return
  unset %JSONError
  Debugger -i 0 Calling /JSONUrlGet $1-
  var %switches = -, %error, %com, %file
  if (-* iswm $1) {
    %switches = $1
    tokenize 32 $2-
  }
  if (!$0 || (%switches != - && $0 < 2)) {
    %error = Missing parameters
  }
  elseif (!$regex(%switches, ^-[bf]?$)) {
    %error = Invalid switch(es) specified
  }
  elseif (!$regex($1, /^[a-z][a-z\d_.\-]+$/i)) {
    %error = Invalid handler name: Must start with a letter and contain only letters numbers _ . and -
  }
  elseif (!$com(JSONHandler:: $+ $1)) {
    %error = Specified handler does not exist
  }
  elseif (b isincs %switches && &* !iswm $2) {
    %error = Invalid bvar name: bvars start with &
  }
  elseif (b isincs %switches && $0 > 2) {
    %error = Invalid bvar name: Contains spaces: $2-
  }
  elseif (f isincs %switches && !$isfile($2-)) {
    %error = Specified file does not exist: $longfn($2-)
  }
  else {
    %com = JSONHandler:: $+ $1
    if ($0 > 1) {
      if (f isincs %switches) {
        if (0 ?* iswm $jsTry(%com, $JScript(UrlData), status="error", $escape($longfn($2-)).quote).withError) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          Debugger -s $+(%com,>JSONUrlGet) Stored $longfn($2-) as data to send with HTTP Request
        }
      }
      else {
        %file = $tempfile
        if (b isincs %switches) {
          bwrite $qt(%file) -1 -1 $2
        }
        else {
          write -n $qt(%file) $2-
        }
        Debugger -s $+(%com,>JSONUrlGet) Wrote specified data to %file
        if (0 ?* iswm $jsTry(%com, $JScript(UrlData), status="error", $escape(%file).quote).withError) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          Debugger -s $+(%Com,>JSONUrlGet) Stored $2- as data to send with HTTP Request
        }
        .remove $qt(%file)
      }
    }
    if (!%error) {
      if (0 ?* iswm $jsTry(%com, $JScript(URLParse), status="error").withError) {
        %error = $gettok($v2, 2-, 32)
      }
      else {
        Debugger -s $+(%com,>JSONUrlGet) Request finished
      }
    }
  }
  :error
  %error = $iif($error, $v1, %error)
  reseterror
  if (%error) {
    set -eu0 %JSONError %error
    if (%com) set -eu0 % [ $+ [ %com ] $+ ] ::Error %error
    Debugger -e $iif(%com, $v1, 0) /JSONUrlGet %switches $1- --RAISED-- %error
  }
}
alias JSONGet {
  if ($isid) return
  unset %JSONError
  debugger -i 0 /JSONGet is depreciated and will be removed. Please use /JSONUrlGet
  JSONUrlGet $1-
}
alias JSONClose {
  if ($isid) return
  unset %JSONError
  Debugger -i 0 /JSONClose $1-
  var %switches = -, %error, %com, %x
  if (-* iswm $1) {
    %switches = $1
    tokenize 32 $2-
  }
  if ($0 < 1) {
    %error = Missing parameters
  }
  elseif ($0 > 1) {
    %error = Too many parameters specified.
  }
  elseif (%switches !== - && %switches != -w) {
    %error = Unknown switches specified
  }
  elseif (%switches == -) {
    %com = JSONHandler:: $+ $1
    if ($com(%com)) { .comclose %com }
    if ($timer(%com)) { $+(.timer,%com) off }
    unset % [ $+ [ %com ] $+ ] ::Error
    Debugger -i %com Closed
  }
  else {
    %com = JSONHandler:: $+ $1
    %x = 1
    while (%x <= $com(0)) {
      if (%com iswm $com(%x)) {
        .comclose $v1
        $+(.timer,$v1) off
        unset % [ $+ [ $v1 ] $+ ] ::*
        Debugger -i %com Closed
      }
      else {
        inc %x
      }
    }
  }
  :error
  %error = $iif($error, $v1, %error)
  reseterror
  if (%error) {
    set -eu0 %JSONError %error
  }
}
alias JSONList {
  if ($isid) return
  Debugger -i 0 Calling /JSONList $1-
  var %x = 1, %i = 0
  while ($com(%x)) {
    if (JSONHandler::* iswm $v1) {
      inc %i
      echo $color(info) -a * # $+ %i : $regsubex($v2, /^JSONHandler::/, )
    }
    inc %x
  }
  if (!%i) {
    echo $color(info) -a * No active JSON handlers
  }
}
alias JSON {
  if (!$isid) {
    return
  }
  var %x, %calling, %i = 0, %com, %get = json, %ref = $false, %error, %file
  if ($JSONDebug) {
    %x = 0
    while (%x < $0) {
      inc %x
      %calling = %calling $+ $iif(%calling,$chr(44)) $($ $+ %x,2)
    }
    debugger -i 0 Calling $!JSON( $+ %calling $+ $chr(41) $+ $iif($prop,. $+ $prop)
  }
  if (!$0) {
    return
  }
  if ($regex($1, ^\d+$)) {
    %x = 1
    while ($com(%x)) {
      if (JSONHandler::* iswm $v1) {
        inc %i
        if (%i == $1) {
          %com = $com(%x)
          break
        }
      }
      inc %x
    }
    if ($0 == 1 && $1 == 0) {
      return %i
    }
  }
  elseif ($regex($1, /^[a-z][a-z\d_.-]+$/i)) {
    %com = JSONHandler:: $+ $1
  }
  elseif ($regex($1, /^(JSONHandler::[a-z][a-z\d_.-]+)::(.+)$/i)) {
    %com = $regml(1)
    %get = json $+ $regml(2)
    %ref = $true
  }
  if (!%com) {
    %error = Invalid name specified
  }
  elseif (!$com(%com)) {
    %error = Handler doesn't exist
  }
  elseif (!$regex($prop, /^(?:Status|IsRef|IsChild|Error|Data|UrlStatus|UrlStatusText|UrlHeader|Fuzzy|FuzzyPath|Type|Length|ToBvar|IsParent)?$/i)) {
    %error = Unknown prop specified
  }
  elseif ($0 == 1) {
    if ($prop == isRef) {
      return %ref
    }
    elseif ($prop == isChild) {
      Debugger -i 0 $!JSON().isChild is depreciated use $!JSON().isRef
      return %ref
    }
    elseif ($prop == status) {
      if ($com(%com, eval, 1, bstr, status) && !$comerr) {
        return $com(%com).result
      }
      else {
        %error = Unable to determine status
      }
    }
    elseif ($prop == error) {
      if ($eval($+(%,%com,::Error),2)) {
        return $v1
      }
      elseif ($com(%com, eval, 1, bstr, error) && !$comerr) {
        return $com(%com).result
      }
      else {
        %error = Unable to determine if there is an error
      }
    }
    elseif ($prop == UrlStatus || $prop == UrlStatusText) {
      if (0 ?* iswm $jsTry(%com, $JScript($prop))) {
        %error = $gettok($v2, 2-, 32)
      }
      else {
        return $v2
      }
    }
    elseif (!$prop) {
      return $regsubex(%com,/^JSONHandler::/,)
    }
  }
  elseif (!$regex($prop, /^(?:fuzzy|fuzzyPath|data|type|length|toBvar|isParent)?$/i)) {
    %error = $+(',$prop,') cannot be used when referencing items
  }
  elseif ($prop == toBvar && $chr(38) !== $left($2, 1) ) {
    %error = Invalid bvar specified: bvar names must start with &
  }
  elseif ($prop == UrlHeader) {
    if ($0 != 2) {
      %error = Missing or excessive header parameter specified
    }
    elseif (0 ?* iswm $jsTry(%com, $JScript(UrlHeader), $escape($2).quote)) {
      %error = $gettok($v2, 2-, 32)
    }
    else {
      return $gettok($v2, 2-, 32)
    }
  }
  elseif (fuzzy* iswm $prop) {
    if ($0 < 2) {
      %error = Missing parameters
    }
    else {
      var %x = 2, %path, %res
      while (%x <= $0) {
        %path = %path $+ $escape($($ $+ %x, 2)).quote $+ $chr(44)
        inc %x
      }
      %res = $jsTry(%com, $JScript(fuzzy), %get, $left(%path, -1))

      if (0 ? iswm %res) {
        %error = $gettok(%res, 2-, 32)
      }
      elseif ($prop == fuzzy) {
        %get = %get $+ $gettok(%res, 2-, 32)
      }
      else {
        return $regsubex(%get, ^json, ) $+ $gettok(%res, 2-, 32)
      }
    }
  }
  if (!%error) {
    if (fuzzy* !iswm $prop) {
      %x = $iif($prop == toBvar, 3, 2)
      while (%x <= $0) {
        %i = $ [ $+ [ %x ] ]
        if ($len(%i)) {
          %get = $+(%get, [", $escape(%i), "])
          inc %x
        }
        else {
          %error = Empty index|item passed.
          break
        }
      }
    }
    if (!%error) {
      if ($prop == type) {
        if (0 ?* iswm $jsTry(%com, $JScript(typeof), %get)) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          return $gettok($v2, 2-, 32)
        }
      }
      elseif ($prop == length) {
        if (0 ?* iswm $jsTry(%com, $JScript(length), %get)) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          return $gettok($v2, 2-, 32)
        }
      }
      elseif ($prop == isParent) {
        if (0 ?* iswm $jsTry(%com, $JScript(isparent), %get)) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          return $iif($gettok($v2, 2-, 32), $true, $false)
        }
      }
      elseif ($prop == toBvar) {
        %file = $tempfile
        if (0 ?* iswm $jsTry(%com, $JScript(tofile), $escape(%file).quote, %get)) {
          %error = $gettok($v2, 2-, 32)
        }
        else {
          bread $qt(%file) 0 $file(%file) $2
        }
        if ($isfile(%file)) { .remove $qt(%file) }
      }
      elseif (0 ?* iswm $jsTry(%com, $JScript(get), %get)) {
        %error = $gettok($v2, 2-, 32)
        if (%error == Object or Array referenced) {
          %error = $null
          Debugger -s $+(%com,>$JSON) Result is an Object or Array; returning reference
          return %com $+ :: $+ $regsubex(%get, /^json/, )
        }
      }
      else {
        var %res = $gettok($v2, 2-, 32)
        Debugger -s $+(%com,>$JSON) %get references %res
        return %res
      }
    }
  }
  :error
  %error = $iif($error, $v1, %error)
  if (%error) {
    set -eu0 %JSONError
    if (%com && $com(%com)) {
      set -eu0 $+(%,%com,::Error) %error
    }
    var %r
    %x = 0
    while (%x < $0) {
      inc %x
      %r = $addtok(%r, $chr(32) $+ $ [ $+ [ %x ] ] , 44)
    }
    debugger -e $iif(%com && $com(%com),%com,0) $!JSON( $+ %r $+ ) $+ $+ $iif($prop,. $+ $prop) --RAISED-- %error
  }
}
alias JSONDebug {
  if ($isid) {
    return $iif($group(#JSONForMircDebug) == on, $true, $false)
  }
  elseif ($0) {
    tokenize 32 $iif($group(#JSONForMircDebug) == on, off, on)
  }
  if ($regex($1-,/^(?:on|enable)$/i)) {
    .enable #JSONForMircDebug
    debugger -i Debugger Now Enabled
  }
  elseif ($regex($1-, /^(?:off|disable)$/i)) {
    .disable #JSONForMircDebug
    if ($window(@JSONForMircDebug)) {
      close -@ @JSONForMircDebug
    }
  }
}
#JSONForMircDebug off
alias -l Debugger {
  if ($isid) return
  if (!$window(@JSONForMircDebug)) {
    window -zk0 @JSONForMircDebug
  }
  var %switches = -, %c
  if (-* iswm $1) {
    %switches = $1
    tokenize 32 $2-
  }
  if (e isincs %switches) {
    %c = 04
  }
  elseif (s isincs %switches) {
    %c = 12
  }
  else {
    %c = 03
  }
  var %n = $iif($1, $1, JSONForMirc)
  %n = $regsubex(%n, /^JSONHandler::, )
  aline -p @JSONForMircDebug $+($chr(3),%c,[,%n,],$chr(15)) $2-
}
#JSONForMircDebug end
alias -l Debugger return
menu @JSONForMircDebug {
  .Clear: clear -@ @JsonForMircDebug
  .Disable and Close: JSONDebug off
}
alias -l tempfile {
  var %n = 1
  while ($isfile($scriptdirJSONTmpFile $+ %n $+ .json)) {
    inc %n
  }
  return $scriptdirJSONTmpFile $+ %n $+ .json
}
alias -l escape {
  var %esc = $replace($1-,\,\\,",\")
  return $iif($prop == quote, $qt(%esc), %esc)
}
alias -l JScript {
  if (!$isid) return
  if (!$0) return (function(){status="init";json=null;url={m:"GET",u:null,h:[],d:null};response=null;var r,x=['MSXML2.SERVERXMLHTTP.6.0','MSXML2.SERVERXMLHTTP.3.0','MSXML2.SERVERXMLHTTP','MSXML2.XMLHTTP.6.0','MSXML2.XMLHTTP.3.0','Microsoft.XMLHTTP'],i;while(x.length){try{r=new ActiveXObject(x.shift());break}catch(e){}}xhr=r?function(){r.open(url.m,url.u,false);for(i=0;i<url.h.length;i+=1)r.setRequestHeader(url.h[i][0],url.h[i][1]);r.send(url.d);return(response=r).responseText}:function(){throw new Error("HTTP Request object not found")};read=function(f){var a=new ActiveXObject("ADODB.stream"),d;a.CharSet="utf-8";a.Open();a.LoadFromFile(f);if(a.EOF){a.close();throw new Error("No content in file")}d=a.ReadText();a.Close();return d;};write=function(f,d){var a=new ActiveXObject("ADODB.stream");a.CharSet="utf-8";a.Open();a.WriteText(d);a.SaveToFile(f,2);a.Close()};parse=function(t){if(/^[\],:{}\s]*$/.test((t=(String(t)).replace(/[\u0000\u00ad\u0600-\u0604\u070f\u17b4\u17b5\u200c-\u200f\u2028-\u202f\u2060-\u206f\ufeff\ufff0-\uffff]/g,function(a){return'\\u'+('0000'+a.charCodeAt(0).toString(16)).slice(-4)})).replace(/\\(?:["\\\/bfnrt]|u[0-9a-fA-F]{4})/g,'@').replace(/"[^"\\\n\r]*"|true|false|null|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?/g,']').replace(/(?:^|:|,)(?:\s*\[)+/g,''))){return eval('('+t+')')}throw new SyntaxError('Unable to Parse: Invalid JSON')};fuzzy=function(){var a=Array.prototype.slice.call(arguments),b=a.shift(),c="",d=Object.prototype.toString.call(b),e,f,g,h,i;for(e=0;e<a.length;e+=1){f=a[e];if(b.hasOwnProperty(f)){if(typeof b[f]==="function")throw new TypeError("Reference points to a function");b=b[f];c+="[\""+f+"\"]"}else if(d==="[object Object]"){if(typeof f==="number")f=f.toString(10);f=f.toLowerCase();g=-1;i=!1;for(h in b){if(b.hasOwnProperty(h)&&typeof b[h]!=="function"){g+=1;if(h.toLowerCase()===f){b=b[h];c+="[\""+h+"\"]";i=!0;break}else if(g.toString(10)===f){b=b[h];c+="[\""+h+"\"]";i=!0;break}}}if(!i)throw new Error("No matching reference found");}else{throw new Error("Reference does not exist")}d=Object.prototype.toString.call(b)}return c}}());
  if ($1 == FileParse)     return if(status!=="init")throw new Error("Parse Not Pending");json=parse(read(@1@));status="done"
  if ($1 == UrlInit)       return if(status!=="init")throw new Error("JSON handler not ready");url.u=@1@;status="url"
  if ($1 == UrlMethod)     return if(status!=="url")throw new Error("URL Request Not Pending");url.m=@1@
  if ($1 == UrlHeader)     return if(status!=="url")throw new Error("URL Request Not Pending");url.h.push([@1@,@2@])
  if ($1 == UrlData)       return if(status!=="url")throw new Error("URL Request Not Pending");url.d=read(@1@)
  if ($1 == UrlParse)      return if(status!=="url")throw new Error("URL Request Not Pending");json=parse(xhr());status="done"
  if ($1 == UrlStatus)     return if(status!=="done")throw new Error("Data not parsed");if(!response)throw new Error("URL request not made");return response.status;
  if ($1 == UrlStatusText) return if(status!=="done")throw new Error("Data not parsed");if(!response)throw new Error("URL request not made");return response.statusText;
  if ($1 == UrlHeader)     return if(status!=="done")throw new Error("Data not parsed");if(!response)throw new Error("URL Request not made");return response.getResponseHeader(@1@)
  if ($1 == fuzzy)         return if(status!=="done")throw new Error("Data not parsed");return "1 "+fuzzy(@1@,@2@)
  if ($1 == typeof)        return if(status!=="done")throw new Error("Data not parsed");var i=@1@;if(i===undefined)throw new TypeError("Reference doesn't exist");if(i===null)return"1 null";var s=Object.prototype.toString.call(i);if(s==="[object Array]")return"1 array";if(s==="[object Object]")return"1 object";return "1 "+typeof(i)
  if ($1 == length)        return if(status!=="done")throw new Error("Data not parsed");var i=@1@;if(i===undefined)throw new TypeError("Reference doesn't exist");if(/^\[object (?:String|Array)\]$/.test(Object.prototype.toString.call(i)))return"1 "+i.length.toString(10);throw new Error("Reference is not a string or array");
  if ($1 == isparent)      return if(status!=="done")throw new Error("Data not parsed");var i=@1@;if(i===undefined)throw new TypeError("Reference doesn't exist");if(/^\[object (?:Object|Array)\]$/.test(Object.prototype.toString.call(i)))return"1 1";return"1 0"
  if ($1 == tofile)        return if(status!=="done")throw new Error("Data not parsed");var i=@2@;if(i===undefined)throw new TypeError("Reference doesn't exist");if(typeof i!=="string")throw new TypeError("Reference must be a string");write(@1@,i);
  if ($1 == get)           return if(status!=="done")throw new Error("Data not parsed");var i=@1@;if(i===undefined)throw new TypeError("Reference doesn't exist");if(i===null)return"1";if(/^\[object (?:Array|Object)\]$/.test(Object.prototype.toString.call(i)))throw new TypeError("Object or Array referenced");if(i.length>4000)throw new Error("Data would exceed mIRC's line length limit");if(typeof i == "boolean")return i?"1 1":"1 0";if(typeof i == "number")return "1 "+i.toString(10);return "1 "+i;
}
alias -l jsTry {
  if ($isid) {
    if ($0 < 2 || $prop == withError && $0 < 3) {
      return 0 Missing parameters
    }
    elseif (!$com($1)) {
      return 0 No such com
    }
    else {
      var %code = $2, %error, %n = 2, %o, %js
      if ($prop == withError) {
        %error = $3
        %n = 3
      }
      %o = %n
      while (%n < $0) {
        inc %n
        set -l $+(%, arg, $calc(%n - %o)) $eval($+($, %n), 2)
      }
      %code = $regsubex($regsubex(%code, /@(\d+)@/g, $var($+(%, arg, \t ),1).value), [\s;]+$, )
      %error = $regsubex($regsubex(%error, /@(\d+)@/g, $var($+(%, arg, \t ),1).value), [\s;]+$, )
      if (%code) %code = $v1 $+ ;
      if (%error) %error = $v1 $+ ;
      %js = (function(){error=null;try{ $+ %code $+ return"1 OK"}catch(e){ $+ %error $+ error=e.message;return"0 "+error}}())
      debugger $1>$jsTry Executing: %js
      if (!$com($1, eval, 1, bstr, %js) || $comerr) {
        return 0 Unable to execute specified javascript
      }
      return $com($1).result
    }
  }
}
