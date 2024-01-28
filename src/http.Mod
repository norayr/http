MODULE http;
IMPORT IntStr := oocIntStr, Strings, Files, Out,
       hexIntStr, Internet, strTypes, strUtils;
CONST
  defName = "unknown.html";
  defReqHeaderLength = 5;
  defHeaderLength = 1024;
     defUserAgent = "oberon-http-client/1.0";
   defHttpVersion = "HTTP/1.1";
        defGetStr = "GET";
       defHostStr = "HOST";
         defUAStr = "User-Agent";
     defAcceptStr = "Accept";
 defEverythingStr = "*/*";

              hdrDate = "Date";
            hdrServer = "Server";
      hdrLastModified = "Last-Modified";
              hdrETag = "ETag";
      hdrAcceptRanges = "Accept-Ranges";
     hdrContentLength = "Content-Length";
              hdrVary = "Vary";
       hdrContentType = "Content-Type";
  hdrTransferEncoding = "Transfer-Encoding";
        hdrConnection = "keey-alive";
      hdrCacheControl = "Cache-Control";
           hdrExpires = "Expires";
          hdrLocation = "Location";
          hdrReportTo = "Report-To";
               hdrNEL = "NEL";
             hdrCFRAY = "CF-RAY";


TYPE

  httpClient* = POINTER TO httpClientDesc;

  httpClientDesc* = RECORD
    host-, port-, path- : strTypes.pstring;
                 socket : Internet.Socket;
         connectionFlag : BOOLEAN;
             userAgent- : strTypes.pstring;
               version- : strTypes.pstring;
                    eol : ARRAY 2 OF CHAR;
                   null : ARRAY 1 OF CHAR;
             reqHeader- : POINTER TO ARRAY OF strTypes.pstring;
          rspnPstrings- : strTypes.pstrings;
         rspnFirstLine- : strTypes.pstring;
              rspnDate- : strTypes.pstring;
            rspnServer- : strTypes.pstring;
      rspnLastModified- : strTypes.pstring;
              rspnETag- : strTypes.pstring;
      rspnAcceptRanges- : strTypes.pstring;
     rspnContentLength- : LONGINT;
              rspnVary- : strTypes.pstring;
       rspnContentType- : strTypes.pstring;
  rspnTransferEncoding- : strTypes.pstring;
        rspnConnection- : strTypes.pstring;
      rspnCacheControl- : strTypes.pstring;
           rspnExpires- : strTypes.pstring;
          rspnLocation- : strTypes.pstring;
          rspnReportTo- : strTypes.pstring;
               rspnNEL- : strTypes.pstring;
             rspnCFRAY- : strTypes.pstring;
              rspnBody- : strTypes.pstring;

                Create* : PROCEDURE(host, port, path: ARRAY OF CHAR): httpClient;
                   Get* : PROCEDURE(VAR http: httpClient): strTypes.pstring;
          setUserAgent* : PROCEDURE(VAR http: httpClient; ua: ARRAY OF CHAR);
            clearState* : PROCEDURE(VAR http: httpClient);
                  Save* : PROCEDURE(VAR http: httpClient);
  END;

PROCEDURE Empty(VAR string: strTypes.pstring);
VAR i : LONGINT;
BEGIN
  (*NEW(string, 512);
  string[0] := 0X;*)
  i := 0;
  REPEAT
    string[i] := 0X;
    INC(i)
  UNTIL i = LEN(string^) -1;
END Empty;

PROCEDURE clearstate(VAR http: httpClient);
BEGIN
  http^.rspnPstrings          := NIL;
  http^.rspnFirstLine         := NIL;
  http^.rspnDate              := NIL;
  http^.rspnServer            := NIL;
  http^.rspnLastModified      := NIL;
  http^.rspnETag              := NIL;
  http^.rspnAcceptRanges      := NIL;
  http^.rspnContentLength     := 0;
  http^.rspnVary              := NIL;
  http^.rspnContentType       := NIL;
  http^.rspnTransferEncoding  := NIL;
  http^.rspnConnection        := NIL;
  http^.rspnCacheControl      := NIL;
  http^.rspnExpires           := NIL;
  http^.rspnLocation          := NIL;
  http^.rspnReportTo          := NIL;
  http^.rspnNEL               := NIL;
  http^.rspnCFRAY             := NIL;
  http^.rspnBody              := NIL;

END clearstate;

PROCEDURE AppendEOLAndClean(buff: ARRAY OF CHAR; VAR buffClean: strTypes.pstring);
VAR
  i: LONGINT;
BEGIN
  i := Strings.Length(buff);
  NEW(buffClean, i + 3);

  COPY(buff, buffClean^);
  buffClean[i] := 0DX;
  buffClean[i + 1] := 0AX;
  buffClean[i + 2] := 0X;
END AppendEOLAndClean;

PROCEDURE getHeader(VAR buff: ARRAY OF CHAR; key: ARRAY OF CHAR): strTypes.pstring;
VAR
  positionStart, valPositionStart, i: LONGINT;
  val: strTypes.pstring;
BEGIN
  positionStart := Strings.Pos(key, buff, 0);

  IF positionStart = -1 THEN
    RETURN NIL;
  END;

  valPositionStart := positionStart + Strings.Length(key) + 1;
  NEW(val, 8);
  (*Empty(val);*)
  i := 0;
  REPEAT
    val[i] := buff[valPositionStart + i];
    IF (val[i] = 0AX) OR (val[i] = 0DX) THEN
      val[i] := 0X
    ELSE
      val[i+1] := 0X
    END;
    INC(i);
    (*
    Out.String("length is '"); Out.String(val^); Out.String("'"); Out.Ln;
    Out.String("current character is '"); Out.Int(ORD(val[i-1]), 0); Out.String("'"); Out.Ln;
    *)
 UNTIL (val[i-1] = 0X) OR (i = Strings.Length(buff)-1);
 RETURN val;
END getHeader;

PROCEDURE readHeader(VAR http: httpClient):strTypes.pstring;
VAR
  valueContentLength: LONGINT;
  valueContentLengthString: strTypes.pstring;
  header, buff: strTypes.pstring;
  headerBool : BOOLEAN;
  res: SHORTINT;
  i: INTEGER;
  n: INTEGER;
BEGIN
  NEW(header, defHeaderLength);
  Empty(header);
  NEW(buff, 2);
  i := 0; headerBool := FALSE;
  REPEAT
    http^.connectionFlag := Internet.Read(http^.socket, buff^);
    header[i] := buff[0];
    (*      Out.String("got character: "); Out.Int(ORD(buff[0]), 0); Out.Ln;*)
    IF (header[i] = 0DX) THEN
      http^.connectionFlag := Internet.Read(http^.socket, buff^);
      INC(i); header[i] := buff[0];
               (*  Out.String("got character: "); Out.Int(ORD(buff[0]), 0); Out.Ln;*)
      IF (header[i] = 0AX) THEN
        http^.connectionFlag := Internet.Read(http^.socket, buff^);
        INC(i); header[i] := buff^[0];
        IF header[i] = 0DX THEN
          http^.connectionFlag := Internet.Read(http^.socket, buff^);
          INC(i); header[i] := buff^[0];
          IF header[i] = 0AX THEN headerBool := TRUE END;
        END;
      END;
    END;
    INC(i);
    header[i] := 0X;
(*    Out.String("header is '"); Out.String(header^); Out.Char("'"); Out.Ln;*)
  UNTIL headerBool;
  RETURN header
END readHeader;

PROCEDURE processHeader(VAR http: httpClient; VAR hdr: ARRAY OF CHAR);
VAR
  len, i, j: INTEGER;
  key: ARRAY 64 OF CHAR;
  val: ARRAY 512 OF CHAR;
  res: SHORTINT;
  isLengthFound: BOOLEAN;
BEGIN
  isLengthFound := FALSE;
  len := Strings.Length(hdr);
  Out.String("header length is "); Out.Int(len, 0); Out.Ln;

  (* getting string like 'HTTP/1.1 200 OK', hopefully *)
  http^.rspnPstrings := strUtils.string2pstrings(hdr);
strUtils.string2pstring(http^.rspnPstrings^[0]^, http^.rspnFirstLine);
           Out.String("first line: '"); Out.String(http^.rspnFirstLine^);
           Out.Char("'"); Out.Ln;
  i := 1;
  REPEAT
          Out.Int(i, 0); Out.String(": ");
          Out.String(http^.rspnPstrings^[i]^); Out.Ln;
    j := strUtils.Pos(':', http^.rspnPstrings^[i]^, 0);
    Strings.Extract(http^.rspnPstrings^[i]^, 0, j, key);
          Out.String("key: '"); Out.String(key); Out.Char("'"); Out.Ln;
    strUtils.getTillEOL(http^.rspnPstrings^[i]^, j+1, val);
          Out.String("val: '"); Out.String(val); Out.Char("'"); Out.Ln;
    IF key = hdrDate THEN strUtils.string2pstring(val, http^.rspnDate) END;
    IF key = hdrServer THEN strUtils.string2pstring(val, http^.rspnServer) END;
    IF key = hdrLastModified THEN strUtils.string2pstring(val, http^.rspnLastModified) END;
    IF key = hdrETag THEN strUtils.string2pstring(val, http^.rspnETag) END;
    IF key = hdrAcceptRanges THEN strUtils.string2pstring(val, http^.rspnAcceptRanges) END;
    IF key = hdrContentLength THEN
      isLengthFound := TRUE;
      IntStr.StrToInt(val, http^.rspnContentLength, res);
      IF res # IntStr.strAllRight THEN
        Out.String("not number"); Out.Ln; HALT(1)
      ELSE
        Out.String("got content length: "); Out.Int(http^.rspnContentLength, 0); Out.Ln
      END;
    END;

    IF key = hdrVary THEN strUtils.string2pstring(val, http^.rspnVary) END;
    IF key = hdrContentType THEN strUtils.string2pstring(val, http^.rspnContentType) END;
    IF key = hdrTransferEncoding THEN strUtils.string2pstring(val, http^.rspnTransferEncoding) END;
    IF key = hdrConnection THEN strUtils.string2pstring(val, http^.rspnConnection) END;
    IF key = hdrCacheControl THEN strUtils.string2pstring(val, http^.rspnCacheControl) END;
    IF key = hdrExpires THEN strUtils.string2pstring(val, http^.rspnExpires) END;
    IF key = hdrLocation THEN strUtils.string2pstring(val, http^.rspnLocation) END;
    IF key = hdrReportTo THEN strUtils.string2pstring(val, http^.rspnReportTo) END;
    IF key = hdrNEL THEN strUtils.string2pstring(val, http^.rspnNEL) END;
    IF key = hdrCFRAY THEN strUtils.string2pstring(val, http^.rspnCFRAY) END;

    INC(i)
  UNTIL i = LEN(http^.rspnPstrings^)-1;
  IF ~isLengthFound THEN http^.rspnContentLength := 0 END
END processHeader;

PROCEDURE getKnownLength(VAR http: httpClient): strTypes.pstring;
VAR
  buff, tmpBuff: strTypes.pstring;
  firstRead: BOOLEAN;
  readFailure: BOOLEAN; eof: BOOLEAN;
  readThisTime, readAll: LONGINT;
BEGIN
    firstRead := TRUE;
    readThisTime := 0; readAll := 0;
    buff := NIL;
    NEW(tmpBuff, http^.rspnContentLength);
    readFailure := FALSE; eof := FALSE;
    REPEAT
           Out.String("emptying tmpbuff"); Out.Ln; Out.Ln;
      Empty(tmpBuff);
           Out.String("emptied tmpbuff"); Out.Ln; Out.Ln;
      http^.connectionFlag := Internet.ReadBuf(http^.socket, tmpBuff^, readThisTime);
      IF readThisTime < 0 THEN readFailure := TRUE; Out.String("read failure"); Out.Ln END;
      IF readThisTime = 0 THEN eof := TRUE; Out.String("eof"); Out.Ln END;
      readAll := readAll + readThisTime;
      (*Out.String("downloaded "); Out.Int(readAll, 0); Out.String(" bytes."); Out.Ln;*)
      Out.Char('.');
      IF buff = NIL THEN
        strUtils.appendNumChars(tmpBuff, readThisTime, buff, 0);
      ELSE
        strUtils.appendNumChars(tmpBuff, readThisTime, buff, LEN(buff^));
      END;
    UNTIL (readAll >= http^.rspnContentLength) OR eof OR readFailure OR ~http^.connectionFlag OR (http^.rspnContentLength = 0);
  Out.Ln;
  http^.rspnBody := buff;
  RETURN buff;
END getKnownLength;

PROCEDURE fixChunkStr(VAR str: ARRAY OF CHAR);
VAR
  i: LONGINT;
BEGIN
  i := LEN(str)-1;
  REPEAT
    IF ~( ((str[i] >= 30X) & (str[i] <= 39X))
       OR ((str[i] >= 41X) & (str[i] <= 5AX))
       OR ((str[i] >= 61X) & (str[i] <= 7AX)) )THEN str[i] := 0X END;
    DEC(i)
  UNTIL i = 0;
END fixChunkStr;

PROCEDURE getNextChunkSize(VAR http: httpClient): LONGINT;
VAR
  tmp: ARRAY 2 OF CHAR;
  len: ARRAY 64 OF CHAR;
  i: INTEGER;
  out: LONGINT; res: SHORTINT;
BEGIN
  strUtils.zeroStr(len);
  i := 0;
      Out.String("reading hopefully next chunk size"); Out.Ln;
  REPEAT
    http^.connectionFlag := Internet.ReadBytes(http^.socket, tmp, 1);
    len[i] := tmp[0];
    Out.String("iteration "); Out.Int(i, 0); Out.Ln;
    strUtils.dumpStr(len);
    Out.String("----"); Out.Ln;
    INC(i)
  UNTIL (i = LEN(len)) OR (tmp[0] = 0AX) ;
  Out.String("after the loop"); Out.Ln;
  strUtils.dumpStr(len);
  fixChunkStr(len);
  Out.String("after the fix"); Out.Ln;
  strUtils.dumpStr(len);
  hexIntStr.StrToInt(len, out, res);
  IF res # hexIntStr.strAllRight THEN Out.String("failed to get next chunk size"); Out.Ln; HALT(5); END;
  IF out < 0 THEN Out.String("next chunk size negative, this indicates bug in the http module, halting"); Out.Ln; HALT(5); END;
  RETURN out;
END getNextChunkSize;

PROCEDURE expectCRLF(VAR http: httpClient);
  VAR
    tmp, ref: POINTER TO ARRAY OF CHAR;
BEGIN
  NEW(tmp, 3); NEW(ref, 3);
  ref^[0] := 0DX;
  ref^[1] := 0AX;
  http^.connectionFlag := Internet.ReadBytes(http^.socket, tmp^, 2);
  IF tmp^ # ref^ THEN Out.String("crlf expected, got "); Out.String(tmp^); Out.Ln; HALT(5); END;
END expectCRLF;

PROCEDURE getChunked(VAR http: httpClient): strTypes.pstring;
VAR
  buff, tmpBuff, smBuff: strTypes.pstring;
  firstRead: BOOLEAN;
  readFailure: BOOLEAN; eof: BOOLEAN;
  nextChunkSize, readAll, i: LONGINT;
BEGIN
    firstRead := TRUE;
    readAll := 0;
    buff := NIL; tmpBuff := NIL;
    readFailure := FALSE; eof := FALSE;
    REPEAT
      nextChunkSize := getNextChunkSize(http);
      IF nextChunkSize > 0 THEN
            Out.String("next chunk size is "); Out.Int(nextChunkSize, 0); Out.Ln;
         NEW(tmpBuff, nextChunkSize+1);
         NEW(smBuff, 3);
         i := 0;
         REPEAT
           http^.connectionFlag := Internet.ReadBytes(http^.socket, smBuff^, 1);
           tmpBuff[i] := smBuff[0]; INC(i); Out.Char('.');
         UNTIL i = nextChunkSize;
           expectCRLF(http);
         Out.String("read chunk:"); Out.Ln;
         strUtils.dumpStr(tmpBuff^);
         Out.String("------------"); Out.Ln;
         readAll := readAll + nextChunkSize;
         Out.Int(nextChunkSize, 0); Out.String("   "); Out.Int(readAll, 0); Out.Ln;
         IF buff = NIL THEN
           strUtils.appendNumChars(tmpBuff, nextChunkSize, buff, 0);
              Out.String("appended when nil"); Out.Ln;
         ELSE
           strUtils.appendNumChars(tmpBuff, nextChunkSize, buff, LEN(buff^));
              Out.String("appended"); Out.Ln;
         END;
         Out.String("now buff is "); Out.Ln;
         strUtils.dumpStr(tmpBuff^);
         Out.String("------------"); Out.Ln;
      ELSE
        Out.String("next chunk size is not > 0"); Out.Ln;
        eof := TRUE
      END;
      Empty(tmpBuff);
    UNTIL eof OR readFailure OR ~http^.connectionFlag;
  RETURN buff;
END getChunked;


PROCEDURE sendHeaders(VAR http: httpClient);
VAR
  i: INTEGER;
BEGIN
    i := 0;
    REPEAT
      http^.connectionFlag := Internet.Write(http^.socket, http^.reqHeader[i]^);
      INC(i)
    UNTIL i = LEN(http^.reqHeader^);
END sendHeaders;

PROCEDURE get*(VAR http: httpClient): strTypes.pstring;
VAR
  header: strTypes.pstring;
BEGIN
  http^.clearState(http);
  http^.connectionFlag := Internet.Connect(http^.host^, http^.port^, http^.socket);
  IF ~http^.connectionFlag THEN
    Out.String("Connection failed");
    Out.Ln;
    HALT(5)
  END;
    sendHeaders(http);
    header := readHeader(http);
    processHeader(http, header^);
          Out.String("headers processed"); Out.Ln;
    IF http^.rspnContentLength # 0 THEN
         Out.String("calling getknwn"); Out.Ln;
      http^.rspnBody := getKnownLength(http)
    ELSIF ((http^.rspnTransferEncoding # NIL) & (http^.rspnTransferEncoding^ = "chunked")) THEN
          Out.String("need to get chunked"); Out.Ln;
      http^.rspnBody := getChunked(http)
    END;
  Internet.Disconnect(http^.socket);
  RETURN http^.rspnBody
END get;

PROCEDURE nextHeaderLine(key, val: ARRAY OF CHAR): strTypes.pstring;
VAR
  header: strTypes.pstring;
  headerLength, tmp: LONGINT;
BEGIN
  headerLength := Strings.Length(key)
          + Strings.Length(val) + 2 (* 2 for ": " *)
          + 3; (* for eol: 0DX, 0AX, 0X *)
  NEW(header, headerLength);
    Out.String("header is now '"); Out.String(header^); Out.Char("'"); Out.Ln;
  COPY(key, header^);
    Out.String("header is now '"); Out.String(header^); Out.Char("'"); Out.Ln;
  Strings.Append(": ", header^);
    Out.String("header is now '"); Out.String(header^); Out.Char("'"); Out.Ln;
  Strings.Append(val, header^);

    Out.String("header is now '"); Out.String(header^); Out.Char("'"); Out.Ln;

  tmp := Strings.Length(header^);
  header^[tmp] := 0DX;
  header^[tmp+1] := 0AX;
  header^[tmp+2] := 0X;
    Out.String("header is now '"); Out.String(header^); Out.Char("'"); Out.Ln;
  RETURN header
END nextHeaderLine;

PROCEDURE formReqHeader(VAR http: httpClient);
VAR
  pstr: strTypes.pstring;
  len, tmp: INTEGER;
BEGIN
  NEW(http^.reqHeader, defReqHeaderLength);
  len := Strings.Length(http^.path^) + 1 (* space *) + Strings.Length(http^.version^) + 4 + 3 (* "GET " *);
  NEW(http^.reqHeader[0], len);
  COPY(defGetStr, http^.reqHeader[0]^);
  Strings.Append(" ",           http^.reqHeader[0]^);
  Strings.Append(http^.path^,    http^.reqHeader[0]^);
  Strings.Append(" ",           http^.reqHeader[0]^);
  Strings.Append(http^.version^, http^.reqHeader[0]^);
  tmp := Strings.Length(http^.reqHeader[0]^);
  http^.reqHeader[0]^[tmp] := 0DX;
  http^.reqHeader[0]^[tmp+1] := 0AX;
  http^.reqHeader[0]^[tmp+2] := 0X;
  (*
  Strings.Append(http^.eol,     http^.reqHeader[0]^);
  Strings.Append(http^.null,    http^.reqHeader[0]^);
*)
  http^.reqHeader[1] := nextHeaderLine(defHostStr, http^.host^);

  http^.reqHeader[2] := nextHeaderLine(defUAStr, http^.userAgent^);

  http^.reqHeader[3] := nextHeaderLine(defAcceptStr, defEverythingStr);

  NEW(http^.reqHeader[4], 3);
  COPY(http^.eol, http^.reqHeader[4]^);
  Strings.Append(http^.null, http^.reqHeader[4]^);
END formReqHeader;

PROCEDURE setuseragent*(VAR http: httpClient; ua: ARRAY OF CHAR);
BEGIN
  strUtils.string2pstring(ua, http^.userAgent)
END setuseragent;

PROCEDURE save(VAR http: httpClient);
VAR
  F: Files.File; R: Files.Rider;
  out0, out1: strTypes.pstring;
  i: LONGINT;
  pos: INTEGER;
  size: LONGINT;
BEGIN
  IF http^.rspnContentLength = 0 THEN size := LEN(http^.rspnBody^) ELSE size := http^.rspnContentLength END;
  NEW(out0, Strings.Length(http^.path^)+1);
  NEW(out1, Strings.Length(http^.path^)+1);
  COPY(http^.path^, out0^);
  IF (out0^ = "/") OR (out0^ = "") THEN
         Out.String("DEBUG: out0="); Out.String(out0^); Out.Ln;
     NEW(out1, Strings.Length(defName));
     COPY(defName, out1^);
  ELSE
    strUtils.RemoveRightChars(out0^, '/');
    pos := strUtils.Rpos(out0^, '/');
    Strings.Extract(out0^, pos+1, Strings.Length(out0^)-pos-1, out1^);
  END;
  F := Files.New(out1^);
  IF F # NIL THEN
    Out.String("file created"); Out.Ln;
    Files.Set(R, F, 0);
    i := 0;
    REPEAT
      Files.Write(R, http^.rspnBody[i]);
      INC(i)
    UNTIL i >= size;
    Out.String("file written "); Out.Int(i, 0); Out.Ln;
    Files.Register(F);
  ELSE
    Out.String("failed to create file "); Out.String(out1^); Out.Ln;
  END
END save;

PROCEDURE Create*(host, port, path: ARRAY OF CHAR): httpClient;
VAR
  http: httpClient;
BEGIN
  NEW(http);
  http^.eol[0] := 0DX; http^.eol[1] := 0AX; http^.null[0] := 0X;
  strUtils.string2pstring(host, http^.host);
  strUtils.string2pstring(port, http^.port);
  strUtils.string2pstring(path, http^.path);
  strUtils.string2pstring(defUserAgent, http^.userAgent);
  strUtils.string2pstring(defHttpVersion, http^.version);

  http^.Get := get;
  http^.setUserAgent := setuseragent;
  http^.clearState := clearstate;
  http^.Save := save;
  formReqHeader(http);

  http^.rspnPstrings          := NIL;
  http^.rspnFirstLine         := NIL;
  http^.rspnDate              := NIL;
  http^.rspnServer            := NIL;
  http^.rspnLastModified      := NIL;
  http^.rspnETag              := NIL;
  http^.rspnAcceptRanges      := NIL;
  http^.rspnContentLength     := 0;
  http^.rspnVary              := NIL;
  http^.rspnContentType       := NIL;
  http^.rspnTransferEncoding  := NIL;
  http^.rspnConnection        := NIL;
  http^.rspnCacheControl      := NIL;
  http^.rspnExpires           := NIL;
  http^.rspnLocation          := NIL;
  http^.rspnReportTo          := NIL;
  http^.rspnNEL               := NIL;
  http^.rspnCFRAY             := NIL;
  http^.rspnBody              := NIL;

  RETURN http
END Create;

END http.
