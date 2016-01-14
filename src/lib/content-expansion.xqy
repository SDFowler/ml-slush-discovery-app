xquery version "1.0-ml";

module namespace expand="http://marklogic.com/content-helpes/content-expansion";

declare namespace html = "http://www.w3.org/1999/xhtml";
declare namespace ingest = "http://marklogic.com/dll/ingest-binaries";
declare namespace zip = "xdmp:zip";

declare option xdmp:mapping "false";


declare function expand:document(
  $uri as xs:string,
  $content as document-node(),
  $shouldDecode as xs:boolean
) as document-node()
{
  let $content-type := xdmp:uri-content-type($uri)
  let $_log := xdmp:log("loading "|| $uri ||" of content type " || $content-type)
  let $content :=
    if ($shouldDecode) then
      let $binary :=
        if ($content castable as xs:base64Binary) then
          document { binary { xs:hexBinary(xs:base64Binary($content)) } }
        else if ($content castable as xs:hexBinary) then
          document { binary { xs:hexBinary($content) } }
        else (
          $content,
          xdmp:log(("couldn't decode", $content))
        )
      return
        if (fn:matches($content-type, "^(text/.*|application/(.+\+)?(xml|json))$") and $binary/binary()) then
          document {xdmp:binary-decode($binary, "UTF-8")}
        else
          document { binary { xs:hexBinary(xs:base64Binary(xdmp:binary-decode($binary, "UTF-8"))) } }
    else
      $content
  return
    if ($content-type eq "text/csv") then (
      expand:csv(
        $uri,
        $content
      ),
      document {
        "ExpandedToJson"
      }
    ) else if ($content-type eq "application/zip") then (
      expand:zip($uri, $content),
      $content
    ) else if (fn:matches($content-type, "^(text/.*|application/(.+\+)?(xml|json))$")) then (
      $content
    ) else (
      expand:binary($uri, $content),
      $content
    )
};

declare function expand:decode-hex($hexBinary as document-node())
{
  let $hex := fn:string($hexBinary/binary())
  return
    document {
      fn:codepoints-to-string(
        for $i in (1 to fn:string-length($hex))
        where ($i mod 2) eq 1
        return
          xdmp:hex-to-integer(fn:substring($hex, $i, 2))
      )
    }
};


declare function expand:binary(
  $uri as xs:string,
  $content as document-node()
) as empty-sequence()
{
  let $filter := xdmp:document-filter($content)
  let $metadata :=
    for $meta in $filter//html:meta
    return
      element { xs:QName(concat("ingest:", $meta/@name)) } {
        data($meta/@content)
      }
  return (
    xdmp:document-set-property($uri, <ingest:metadata>{$metadata}</ingest:metadata>)
  )
};

declare function expand:csv(
  $uri as xs:string,
  $content as document-node()
) as empty-sequence()
{
  let $uri-base := fn:replace($uri, "\.[^\.]+$", "/")
  let $lines := fn:tokenize($content, "(&#10;|&#13;)+")
  let $headers := fn:tokenize(fn:head($lines), ",")
  for $row at $row-num in fn:tail($lines)
  let $properties :=
    if (fn:matches($row, '"([^"]+)"')) then
      for $part in fn:analyze-string($row ,'"([^"]+)"')/*
      return
        typeswitch($part)
        case element(fn:match) return
          fn:string($part/fn:group)
        default return
          fn:tokenize($part, "\s*,\s*") ! fn:normalize-space()[. ne '']
    else
      fn:tokenize($row, "\s*,\s*")
  return
    xdmp:document-insert($uri-base || $row-num || ".json",
      xdmp:to-json(
        map:new((
          for $prop-label at $prop-pos in $headers
          return
            map:entry($prop-label, $properties[$prop-pos])
        ))
      ),
      (
        xdmp:permission("rest-reader", "read"),
        xdmp:permission("rest-writer", "update")
      )
    )
};

declare function expand:zip(
  $uri as xs:string,
  $content as document-node()
) as empty-sequence()
{
  let $uri-base := fn:replace($uri, "\.[^\.]+$", "/")
  let $manifest := xdmp:zip-manifest($content/binary())
  for $part in $manifest/zip:part
  let $file-relative-uri := fn:string($part)
  let $file-full-uri := $uri-base || $file-relative-uri
  let $file-content :=
    xdmp:zip-get(
      $content,
      $file-relative-uri
    )
  let $file-content :=
    typeswitch($file-content)
    case document-node() return
      $file-content
    default return
      document { $file-content }
  return
    xdmp:document-insert($file-full-uri,
      expand:document(
        $file-full-uri,
        $file-content,
        fn:false()
      ),
      (
        xdmp:permission("rest-reader", "read"),
        xdmp:permission("rest-writer", "update")
      )
    )
};
