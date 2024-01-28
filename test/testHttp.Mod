MODULE testHttp;
IMPORT http, strTypes, Out;

VAR
  h: http.httpClient;
  answer: strTypes.pstring;
BEGIN
  (*h := http.Create("kwiecien.us", "80", "/index.html");*)
  (*h := http.Create("xn--y9a5bft.xn--y9a3aq", "80", "/");*)
  h := http.Create("xn--y9a5bft.xn--y9a3aq", "80", "/SETs.pdf");
  (*h := http.Create("norayr.am", "80", "/index.html");*)
  (*h := http.Create("norayr.am", "80", "/papers/SETs.pdf");*)
  answer := h.Get(h);
  h.Save(h);

END testHttp.
