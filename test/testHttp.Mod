MODULE testHttp;
IMPORT http, strTypes, Out;

VAR
  h: http.httpClient;
  answer: strTypes.pstring;
BEGIN
  h := http.Create("norayr.am", "80", "/index.html");
  answer := h.Get(h);
  h.Save(h);

END testHttp.
