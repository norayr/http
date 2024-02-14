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
  transport* = POINTER TO transportDesc;
  transportDesc* = RECORD END;
   bsdSocket* = POINTER TO bsdSocketDesc;
   bsdSocketDesc = RECORD (transportDesc)
          socket : Internet.Socket
          END;
  Client* = POINTER TO ClientDesc;
  headers*    = POINTER TO ARRAY OF strTypes.pstring;

  ClientDesc* = RECORD
    host-, port-, path- : strTypes.pstring;
                   trn- : transport;
        connectionFlag* : BOOLEAN;
             userAgent- : strTypes.pstring;
               version- : strTypes.pstring;
                    eol : ARRAY 2 OF CHAR;
                   null : ARRAY 1 OF CHAR;
             reqHeader- : headers;
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

                Create* : PROCEDURE(host, port, path: ARRAY OF CHAR): Client;
                   Get* : PROCEDURE(VAR http: Client): strTypes.pstring;
          setUserAgent* : PROCEDURE(VAR http: Client; ua: ARRAY OF CHAR);
            clearState* : PROCEDURE(VAR http: Client);
                  Save* : PROCEDURE(VAR http: Client);
               Connect* : PROCEDURE(VAR http: Client): BOOLEAN;
            Disconnect* : PROCEDURE(VAR http: Client);
                  Read* : PROCEDURE(VAR http: Client; VAR buf: ARRAY OF CHAR; bytesToRead: LONGINT): BOOLEAN;
               ReadBuf* : PROCEDURE(VAR http: Client; VAR buf: ARRAY OF CHAR; VAR n: LONGINT): BOOLEAN; (* returns number of read bytes in n *)
                 Write* : PROCEDURE(VAR http: Client; buf: ARRAY OF CHAR): BOOLEAN;
  END;

PROCEDURE dumpHeaders(VAR hdrs: headers);
VAR
  i: LONGINT;
BEGIN
  i := 0;
  REPEAT
    Out.Int(i, 0); Out.String("  "); Out.String(hdrs^[i]^); Out.Ln;
    INC(i)
  UNTIL i = LEN(hdrs^);
END dumpHeaders;

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

PROCEDURE clearstate(VAR http: Client);
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
 UNTIL (val[i-1] = 0X) OR (i = Strings.Length(buff)-1);
 RETURN val;
END getHeader;

PROCEDURE connector(VAR http: Client): BOOLEAN;
BEGIN
  http^.connectionFlag := FALSE;
  IF http^.trn IS bsdSocket THEN
    http^.connectionFlag := Internet.Connect(http^.host^, http^.port^, http^.trn(bsdSocket).socket);
  ELSE
    Out.String("http client is not initialized with bsd socket"); Out.Ln;
    HALT(5);
  END;
  RETURN http^.connectionFlag;
END connector;

PROCEDURE disconnector(VAR http: Client);
BEGIN
  IF http^.trn IS bsdSocket THEN
    Internet.Disconnect(http^.trn(bsdSocket).socket);
  ELSE
    Out.String("http client is not initialized with bsd socket"); Out.Ln;
    HALT(5);
  END;
END disconnector;

PROCEDURE reader(VAR http: Client; VAR buf: ARRAY OF CHAR; bytesToRead: LONGINT): BOOLEAN;
BEGIN
  http^.connectionFlag := FALSE;
  IF http^.trn IS bsdSocket THEN
    IF bytesToRead = -1 THEN
      http^.connectionFlag := Internet.Read(http^.trn(bsdSocket).socket, buf)
    ELSE
      http^.connectionFlag := Internet.ReadBytes(http^.trn(bsdSocket).socket, buf, bytesToRead)
    END;
  ELSE
    Out.String("http client is not initialized with bsd socket"); Out.Ln;
    HALT(5);
  END;
  RETURN http^.connectionFlag
END reader;

PROCEDURE readBuf(VAR http: Client; VAR buf: ARRAY OF CHAR; VAR n: LONGINT): BOOLEAN;
BEGIN
  http^.connectionFlag := FALSE;
  IF http^.trn IS bsdSocket THEN
    http^.connectionFlag := Internet.ReadBuf(http^.trn(bsdSocket).socket, buf, n);
  ELSE
    Out.String("http client is not initialized with bsd socket"); Out.Ln;
    HALT(5);
  END;
  RETURN http^.connectionFlag
END readBuf;

PROCEDURE writer(VAR http: Client; buf: ARRAY OF CHAR): BOOLEAN;
BEGIN
  http^.connectionFlag := FALSE;
  IF http^.trn IS bsdSocket THEN
    http^.connectionFlag := Internet.Write(http^.trn(bsdSocket).socket, buf);
  ELSE
     Out.String("http client is not initialized with bsd socket"); Out.Ln;
    HALT(5);
  END;
  RETURN http^.connectionFlag
END writer;

PROCEDURE readHeader(VAR http: Client):strTypes.pstring;
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
    http^.connectionFlag := http.Read(http, buff^, -1);
    header[i] := buff[0];
    IF (header[i] = 0DX) THEN
      http^.connectionFlag := http.Read(http, buff^, -1);
      INC(i); header[i] := buff[0];
      IF (header[i] = 0AX) THEN
        http^.connectionFlag := http.Read(http, buff^, -1);
        INC(i); header[i] := buff^[0];
        IF header[i] = 0DX THEN
          http^.connectionFlag := http.Read(http, buff^, -1);
          INC(i); header[i] := buff^[0];
          IF header[i] = 0AX THEN headerBool := TRUE END;
        END;
      END;
    END;
    INC(i);
    header[i] := 0X;
  UNTIL headerBool;
  RETURN header
END readHeader;

PROCEDURE processHeader(VAR http: Client; VAR hdr: ARRAY OF CHAR);
VAR
  len, i, j: INTEGER;
  key: ARRAY 64 OF CHAR;
  val: ARRAY 512 OF CHAR;
  res: SHORTINT;
  isLengthFound: BOOLEAN;
BEGIN
  isLengthFound := FALSE;
  len := Strings.Length(hdr);

  (* getting string like 'HTTP/1.1 200 OK', hopefully *)
  http^.rspnPstrings := strUtils.string2pstrings(hdr);
strUtils.string2pstring(http^.rspnPstrings^[0]^, http^.rspnFirstLine);
  i := 1;
  REPEAT
    j := strUtils.Pos(':', http^.rspnPstrings^[i]^, 0);
    Strings.Extract(http^.rspnPstrings^[i]^, 0, j, key);
    strUtils.getTillEOL(http^.rspnPstrings^[i]^, j+1, val);
    IF key = hdrDate THEN strUtils.string2pstring(val, http^.rspnDate) END;
    IF key = hdrServer THEN strUtils.string2pstring(val, http^.rspnServer) END;
    IF key = hdrLastModified THEN strUtils.string2pstring(val, http^.rspnLastModified) END;
    IF key = hdrETag THEN strUtils.string2pstring(val, http^.rspnETag) END;
    IF key = hdrAcceptRanges THEN strUtils.string2pstring(val, http^.rspnAcceptRanges) END;
    IF key = hdrContentLength THEN
      isLengthFound := TRUE;
      IntStr.StrToInt(val, http^.rspnContentLength, res);
      IF res # IntStr.strAllRight THEN
        Out.String("expected content lengith is not number"); Out.Ln; HALT(1)
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

   (* this implementation reallocates,
      it is necessary when the content length is not known *)
PROCEDURE getKnownLengthRealloc(VAR http: Client): strTypes.pstring;
VAR
  buff, tmpBuff: strTypes.pstring;
  readFailure: BOOLEAN; eof: BOOLEAN;
  readThisTime, readAll: LONGINT;
BEGIN
    readThisTime := 0; readAll := 0;
    buff := NIL;
    NEW(tmpBuff, http^.rspnContentLength);
    readFailure := FALSE; eof := FALSE;
    REPEAT
      Empty(tmpBuff);
      http^.connectionFlag := http.ReadBuf(http, tmpBuff^, readThisTime);
      IF readThisTime < 0 THEN readFailure := TRUE; Out.String("read failure"); Out.Ln END;
      IF readThisTime = 0 THEN eof := TRUE END;
      readAll := readAll + readThisTime;
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
END getKnownLengthRealloc;

(* the following is without unnecessary reallocations *)
PROCEDURE getKnownLength(VAR http: Client): strTypes.pstring;
VAR
  buff, tmpBuff: strTypes.pstring;
  readFailure: BOOLEAN; eof: BOOLEAN;
  readThisTime, readAll, curpos: LONGINT;
BEGIN
    curpos := 0;
    readThisTime := 0; readAll := 0;
    buff := NIL;
    NEW(tmpBuff, http^.rspnContentLength);
    NEW(buff, http^.rspnContentLength);
    readFailure := FALSE; eof := FALSE;
    REPEAT
      Empty(tmpBuff);
      http^.connectionFlag := http.ReadBuf(http, tmpBuff^, readThisTime);
      IF readThisTime < 0 THEN readFailure := TRUE; Out.String("read failure"); Out.Ln END;
      IF readThisTime = 0 THEN eof := TRUE END;
      readAll := readAll + readThisTime;
      Out.Char('.');
        strUtils.copyBytes(tmpBuff^, buff^, curpos, readThisTime);
        curpos := curpos + readThisTime;
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

PROCEDURE getNextChunkSize(VAR http: Client): LONGINT;
VAR
  tmp: ARRAY 2 OF CHAR;
  len: ARRAY 64 OF CHAR;
  i: INTEGER;
  out: LONGINT; res: SHORTINT;
BEGIN
  strUtils.zeroStr(len);
  i := 0;
  REPEAT
    http^.connectionFlag := http.Read(http, tmp, 1);
    len[i] := tmp[0];
    INC(i)
  UNTIL (i = LEN(len)) OR (tmp[0] = 0AX) ;
  fixChunkStr(len);
  hexIntStr.StrToInt(len, out, res);
  IF res # hexIntStr.strAllRight THEN Out.String("failed to get next chunk size"); Out.Ln; HALT(5); END;
  IF out < 0 THEN Out.String("next chunk size negative, this indicates bug in the http module, halting"); Out.Ln; HALT(5); END;
  RETURN out;
END getNextChunkSize;

PROCEDURE expectCRLF(VAR http: Client);
  VAR
    tmp, ref: POINTER TO ARRAY OF CHAR;
BEGIN
  NEW(tmp, 3); NEW(ref, 3);
  ref^[0] := 0DX;
  ref^[1] := 0AX;
  http^.connectionFlag := http.Read(http, tmp^, 2);
  IF tmp^ # ref^ THEN Out.String("crlf expected, got "); Out.String(tmp^); Out.Ln; HALT(5); END;
END expectCRLF;

PROCEDURE getChunked(VAR http: Client): strTypes.pstring;
VAR
  buff, tmpBuff, smBuff: strTypes.pstring;
  readFailure: BOOLEAN; eof: BOOLEAN;
  nextChunkSize, readAll, i: LONGINT;
BEGIN
    readAll := 0;
    buff := NIL; tmpBuff := NIL;
    readFailure := FALSE; eof := FALSE;
    REPEAT
      nextChunkSize := getNextChunkSize(http);
      IF nextChunkSize > 0 THEN
         NEW(tmpBuff, nextChunkSize+1);
         NEW(smBuff, 3);
         i := 0;
         REPEAT
           http^.connectionFlag := http.Read(http, smBuff^, 1);
           tmpBuff[i] := smBuff[0]; INC(i); Out.Char('.');
         UNTIL i = nextChunkSize;
           expectCRLF(http);
         readAll := readAll + nextChunkSize;
         IF buff = NIL THEN
           strUtils.appendNumChars(tmpBuff, nextChunkSize, buff, 0);
         ELSE
           strUtils.appendNumChars(tmpBuff, nextChunkSize, buff, LEN(buff^));
         END;
      ELSE
        eof := TRUE
      END;
      Empty(tmpBuff);
    UNTIL eof OR readFailure OR ~http^.connectionFlag;
  RETURN buff;
END getChunked;


PROCEDURE sendHeaders(VAR http: Client);
VAR
  i: INTEGER;
BEGIN
    i := 0;
    REPEAT
      http^.connectionFlag := http.Write(http, http^.reqHeader[i]^);
      INC(i)
    UNTIL i = LEN(http^.reqHeader^);
END sendHeaders;

PROCEDURE headersToString*(hdrs: headers; VAR ln: LONGINT): strUtils.pstring;
VAR
  i, j, all, alli: LONGINT;
  pstr: strUtils.pstring;
BEGIN
  (* calculating size *)
  i := 0; all := 0;
  REPEAT
    j := 0;
    REPEAT
      INC(j)
    UNTIL j = LEN(hdrs^[i]^);
    all := all + j;
    INC(i)
  UNTIL i = LEN(hdrs^);
     Out.String(" all is "); Out.Int(all, 0); Out.Ln;

  NEW(pstr, all);
  i := 0; alli := 0;
  REPEAT
    j := 0;
    REPEAT
      IF hdrs^[i]^[j] # 0X THEN
        pstr[alli] := hdrs^[i]^[j];
               Out.String("line num: "); Out.Int(i, 0);
               Out.String("; char num: "); Out.Int(j, 0);
               Out.String("; array index: "); Out.Int(alli, 0);
               Out.String("; ord: "); Out.Int(ORD(pstr[alli]), 0);
               Out.String("; val: '"); Out.Char(pstr[alli]); Out.Char("'");
               Out.Ln;
        INC(alli);
      END;
      INC(j);
    UNTIL j = LEN(hdrs^[i]^);
    INC(i)
  UNTIL i = LEN(hdrs^);
  pstr[alli] := 0X;
               Out.String("line num: "); Out.Int(i, 0);
               Out.String("; char num: "); Out.Int(j, 0);
               Out.String("; array index: "); Out.Int(alli, 0);
               Out.String("; ord: "); Out.Int(ORD(pstr[alli]), 0);
               Out.String("; val: '"); Out.Char(pstr[alli]); Out.Char("'");
               Out.Ln;
  ln := alli+1;
  RETURN pstr
END headersToString;

PROCEDURE get*(VAR http: Client): strTypes.pstring;
VAR
  header: strTypes.pstring;
BEGIN
  http^.clearState(http);
  http^.connectionFlag := http.Connect(http);
  IF ~http^.connectionFlag THEN
    Out.String("Connection failed");
    Out.Ln;
    HALT(5)
  END;
    sendHeaders(http);
    header := readHeader(http);
    processHeader(http, header^);
    IF http^.rspnContentLength # 0 THEN
      (*http^.rspnBody := getKnownLength(http)*)
      http^.rspnBody := getKnownLength(http)
    ELSIF ((http^.rspnTransferEncoding # NIL) & (http^.rspnTransferEncoding^ = "chunked")) THEN
      http^.rspnBody := getChunked(http)
    END;
  http.Disconnect(http);
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
  COPY(key, header^);
  Strings.Append(": ", header^);
  Strings.Append(val, header^);


  tmp := Strings.Length(header^);
  header^[tmp] := 0DX;
  header^[tmp+1] := 0AX;
  header^[tmp+2] := 0X;
  RETURN header
END nextHeaderLine;

PROCEDURE formReqHeader(VAR http: Client);
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

PROCEDURE setuseragent*(VAR http: Client; ua: ARRAY OF CHAR);
BEGIN
  strUtils.string2pstring(ua, http^.userAgent)
END setuseragent;

PROCEDURE save(VAR http: Client);
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
     NEW(out1, Strings.Length(defName));
     COPY(defName, out1^);
  ELSE
    strUtils.RemoveRightChars(out0^, '/');
    pos := strUtils.Rpos(out0^, '/');
    Strings.Extract(out0^, pos+1, Strings.Length(out0^)-pos-1, out1^);
  END;
  F := Files.New(out1^);
  IF F # NIL THEN
    Files.Set(R, F, 0);
    i := 0;
    REPEAT
      Files.Write(R, http^.rspnBody[i]);
      INC(i)
    UNTIL i >= size;
    Files.Register(F);
  ELSE
    Out.String("failed to create file "); Out.String(out1^); Out.Ln;
  END
END save;

PROCEDURE Create*(host, port, path: ARRAY OF CHAR): Client;
VAR
  http: Client;
  socket: bsdSocket;
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
  (*dumpHeaders(http^.reqHeader);*)


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

  NEW(socket);
  http^.trn := socket;
  http.Connect := connector;
  http.Disconnect := disconnector;
  http.Read := reader;
  http.ReadBuf := readBuf;
  http.Write := writer;
  RETURN http
END Create;

END http.
