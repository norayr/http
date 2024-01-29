MODULE testHttp;
IMPORT http, strTypes, Out;

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

END testHttp.
