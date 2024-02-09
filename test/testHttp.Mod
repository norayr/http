MODULE testHttp;
IMPORT http, strTypes, strUtils, Out;

PROCEDURE testH2S;
VAR
 hdrs: http.headers;
 pstr: strTypes.pstring;
BEGIN
  NEW(hdrs, 2);
  NEW(hdrs[0], 4 + 1);
  NEW(hdrs[1], 5 + 1);
  COPY("http", hdrs[0]^);
  COPY("maemo", hdrs[1]^);
  pstr := http.headersToString(hdrs);
  Out.String(pstr^); Out.Ln; Out.Ln;
  strUtils.dumpAllChars(pstr^);
END testH2S;


PROCEDURE testClient;
VAR
  h: http.httpClient;
  answer: strTypes.pstring;
BEGIN
(* this tests chunked downloads
     when the content length is not known
     since this page is hosted from the gemini
     via kineto gemini to http proxy *)
  h := http.Create("xn--y9a5bft.xn--y9a3aq", "80", "/SETs.pdf");

  (* this tests downloads of content with known length *)
  (*h := http.Create("norayr.am", "80", "/papers/SETs.pdf");*)
  answer := h.Get(h);
  h.Save(h);
END testClient;


BEGIN

(* testing headers to string *)
(*testH2S;*)

testClient;

END testHttp.
