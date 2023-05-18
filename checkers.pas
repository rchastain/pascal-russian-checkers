
(********************************************************
                 ---Russian Checkers---
 ver 4.x

 @author     Nifont.,  2004-2011
 @compiler   Turbo Pascal 7.2
 @site       http://serg-nifont/narod.ru
 @mail       serg.nifont@yandex.ru
 @CPU        >= 1.6 mg
 
 
 GNU GENERAL PUBLIC LIS. (2)
 
 
**********************************************************)

uses
{$IFDEF UNIX}
  CThreads,
{$ENDIF}
  SysUtils,
  ptcGraph,
  ptcCrt,
  ptcMouse,
  hash,
  def,
  history;

var
  __hashCut: LongInt;

const
  z = 0;

{0016}
  CUNING_ENABLE = true; { 0..3 - хитрость, отнять от D4, F4, C5, E5}
  CENTER_VALUE = 4; { w_pawn_score tbl, D4, F4, C5, E5 }

  w_pawn_score: array[TSquare] of integer =
  (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

    0, z, 4, z, 1, z, 2, z, 4, 0,
    0, 4, z, 4, z, 2, z, 4, z, 0,
    0, z, 4, z, 4, z, 4, z, 2, 0,
    0, 1, z, 4, z, 4, z, 2, z, 0,
    0, z, 2, z, 4, z, 4, z, 1, 0,
    0, 2, z, 4, z, 4, z, 4, z, 0,
    0, z, 4, z, 2, z, 4, z, 3, 0,
    0, 4, z, 3, z, 3, z, 5, z, 0,

    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );

  w_pawn_temp: array[TSquare] of integer =
  (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 8, 8, 8, 8, 8, 8, 8, 8, 0,
    0, 7, 7, 7, 7, 7, 7, 7, 7, 0,
    0, 6, 6, 6, 6, 6, 6, 6, 6, 0,
    0, 5, 5, 5, 5, 5, 5, 5, 5, 0,
    0, 4, 4, 4, 4, 4, 4, 4, 4, 0,
    0, 3, 3, 3, 3, 3, 3, 3, 3, 0,
    0, 2, 2, 2, 2, 2, 2, 2, 2, 0,
    0, 1, 1, 1, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );

  king_score: array[TSquare] of integer =
  (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

    0, z, 3, z, 0, z, 2, z, 4, 0,
    0, 3, z, 3, z, 2, z, 4, z, 0,
    0, z, 3, z, 4, z, 4, z, 2, 0,
    0, 0, z, 4, z, 5, z, 2, z, 0,
    0, z, 2, z, 5, z, 4, z, 0, 0,
    0, 2, z, 4, z, 4, z, 3, z, 0,
    0, z, 4, z, 2, z, 3, z, 3, 0,
    0, 4, z, 2, z, 0, z, 3, z, 0,

    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );

var
  rnd_tbl: array[TSquare] of integer;

const
  dir: array[0..3] of integer = (11, 9, -9, -11);
  up: array[0..3] of TColor = (black, black, white, white);

var
  pRndScore: array[TSquare] of integer;
  pos: array[TSquare] of TIndex;
  pieces: array[TSquare] of TPiece;
  color: array[TSquare] of TColor;
  row, column: array[TSquare] of 0..9;
  PList: array[TIndex] of TPieceItem;
  pRnd: array[TIndex] of integer;
  PStart, PStop: array[white..black] of TIndex;
  game_list: array[0..Max_Game + Max_Ply] of TMove;
  game_cnt, game_max: integer;
  tree: array[0..Max_Ply * 40] of TMove;
  capTree: array[0..1000] of TIndex;
{ sortVal:array[0..Max_Ply*40] of LongInt;}
  treeCnt, capTreeCnt: array[0..Max_Ply] of integer;
  mtl, stMainScore: array[white..black] of integer;
  pCnt: array[white..black, pawn..king] of integer;
  ply: integer;
  side, xside: TColor;
  BitNumber: array[0..128] of byte;
  startTime, currTime, cntPos: LongInt;
  timeOver: boolean;
  searchDepth, searchScore: integer;
  sideMachin: TColor;
  root_side: TColor;
  glHashPawns, glHashKings: boolean;
  glDepth: integer;

const
  maxTime: integer = 3;
procedure InsertPiece(i: TIndex); forward;
procedure RemovePiece(i: TIndex); forward;
function LibLook(var mv: TMove): boolean; forward;
procedure InitRndMoveOrder; forward;
procedure SqValue(i: TIndex; isInc: boolean); forward;
procedure PrepareEvaluate; forward;

function max(v1, v2: integer): integer;
begin
  if v1 > v2 then max := v1
  else max := v2;
end;

function min(v1, v2: integer): integer;
begin
  if v1 > v2 then min := v2
  else min := v1;
end;

procedure InitNewGame;
  procedure InitVar;
  var
    j: integer;
  begin
    for j := 0 to high(pos) do
    begin
      row[j] := j div 10;
      column[j] := j mod 10;
    end;
    for j := 0 to 7 do
      BitNumber[1 shl j] := j;
  end;
  procedure ClearBoard;
  var
    j: integer;
  begin
    for j := 0 to high(pos) do
      if (row[j] = 0) or (row[j] = 9) or
        (column[j] = 0) or (column[j] = 9) then
        pos[j] := OutIndex
      else
        pos[j] := EmptyIndex;

    with PList[EmptyIndex] do
    begin
      iPiece := nopiece;
      iColor := neutral;
      iEnable := false;
    end;
    with PList[OutIndex] do
    begin
      iPiece := nopiece;
      iColor := out;
      iEnable := false;
    end;
    for j := low(TSquare) to high(TSquare) do
    begin
      pieces[j] := nopiece;
      color[j] := neutral;
    end;
  end;
  procedure InitStartPos;
  const

    s: array[TSquare] of byte =
    (
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 2, 0, 2, 0, 2, 0, 2, 0,
      0, 2, 0, 2, 0, 2, 0, 2, 0, 0,
      0, 0, 2, 0, 2, 0, 2, 0, 2, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
      0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
      0, 0, 1, 0, 1, 0, 1, 0, 1, 0,
      0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0
      );

  var
    j: integer;
    color: TColor;
  begin
    PStart[white] := 0; PStop[white] := 0;
    PStart[black] := 12; PStop[black] := 12;
    for j := 0 to high(s) do
      if s[j] <> 0 then
      begin
        if s[j] = 1 then color := white
        else color := black;
        with PList[PStop[color]] do
        begin
          iPiece := pawn;
          iColor := color;
          iEnable := true;
          iSquare := j;
        end;
        InsertPiece(PStop[color]);
        inc(PStop[color]);
      end;
    dec(PStop[white]);
    dec(PStop[black]);
  end;

  {0016}
  {уровень хитрости ?!}
  procedure RandomCenterSquare;
  const
    values: array[0..10] of integer =
    (0, 1, 1, 2, 2, 2, 3, 3, 3, 3, 3);
  var
    v: integer;
  begin

    if CUNING_ENABLE then
    begin

      randomize;

      v := CENTER_VALUE - values[random(high(values) + 1)];

      w_pawn_score[ord(D4)] := v;
      w_pawn_score[ord(F4)] := v;
      w_pawn_score[ord(C5)] := v;
      w_pawn_score[ord(E5)] := v;

       {??}
       {OutTextXY(0, 0, IntToStr(v));}

    end;

  end;

var
  c: TColor;
begin
  {00011  CLEAR VAR }

  for c := white to black do
  begin
    mtl[c] := 0;
    stMainScore[c] := 0;
    pCnt[c, pawn] := 0;
    pCnt[c, king] := 0;

  end;

{0016}

  InitVar;
  HashInit;
  ClearBoard;
  InitStartPos;
  RandomCenterSquare; {for defferent cuning play style}
  game_cnt := 0;
  game_max := game_cnt;
  side := white;
  xside := black;
  sideMachin := black;
  InitRndMoveOrder;
end;

function GetFirst(v: LongInt): integer;
begin
  v := v and -v; {FIRST BIT SELECT}
  if (v and $FFFF) <> 0 then
  begin
    if (v and $FF) <> 0 then GetFirst := BitNumber[v]
    else GetFirst := BitNumber[v shr 8] + 8;
  end else
  begin
    if (v and $FF0000) <> 0 then GetFirst := BitNumber[v shr 16] + 16
    else GetFirst := BitNumber[v shr 24] + 24;
  end;
end;

function PopCnt(v: LongInt): integer;
var
  cnt: integer;
begin
  cnt := 0;
  while v <> 0 do
  begin
    inc(cnt);
    v := v and (v - 1);
  end;
  PopCnt := cnt;
end;

function Promote(n: integer): boolean;
begin
  Promote := false;
  if side = white then
  begin
    if row[n] = 1 then Promote := true;
  end else
  begin
    if row[n] = 8 then Promote := true;
  end;
end;

procedure InsertPiece(i: TIndex);
begin
  with PList[i] do
  begin
    iEnable := true;
    pos[iSquare] := i;
    pieces[iSquare] := iPiece;
    color[iSquare] := iColor;
    inc(mtl[iColor], value[iPiece]);
    inc(pCnt[iColor, iPiece]);
 {00011}

    SqValue(i, true);
    HashStep(ord(iColor), ord(iPiece), ord(iSquare));
  end;
end;

procedure RemovePiece(i: TIndex);
begin
  with PList[i] do
  begin
    iEnable := false;
    pos[iSquare] := EmptyIndex;
    pieces[iSquare] := nopiece;
    color[iSquare] := neutral;
    dec(mtl[iColor], value[iPiece]);
    dec(pCnt[iColor, iPiece]);
    SqValue(i, false);
    HashStep(ord(iColor), ord(iPiece), ord(iSquare));
  end;
end;

procedure MakeMove(var mv: TMove);
var
  i: integer;
  capIndex: LongInt;
begin
  with mv do
  begin
    capIndex := mCapIndex;
    while capIndex <> 0 do
    begin
      i := GetFirst(capIndex);
      RemovePiece(i);
      capIndex := capIndex and (capIndex - 1); {CLEAR FIRST}
    end;
    i := pos[mFrom];
    RemovePiece(i);
    PList[i].iPiece := mNewPiece;
    PList[i].iSquare := mTo;
    InsertPiece(i);
  end;
end;

procedure UnMakeMove(var mv: TMove);
var
  i: integer;
  capIndex: LongInt;
begin
  with mv do
  begin
    capIndex := mCapIndex;
    while capIndex <> 0 do
    begin
      i := GetFirst(capIndex);
      InsertPiece(i);
      capIndex := capIndex and (capIndex - 1); {CLEAR FIRST}
    end;
    i := pos[mTo];
    RemovePiece(i);
    PList[i].iPiece := mPiece;
    PList[i].iSquare := mFrom;
    InsertPiece(i);
  end;
end;

procedure Generate(var findCap: boolean);
var
  cnt, capCnt, j, i, itemp, from, u, d: integer;
  startPiece: TPiece;
  stack: array[0..11] of integer;
  top: integer;
  capIndex: LongInt;
  procedure Push(n: integer);
  begin
    stack[top] := n;
    inc(top);
    capIndex := capIndex or (LongInt(1) shl pos[n]);
  end;
  function Pop: integer;
  var
    n: integer;
  begin
    dec(top);
    n := stack[top];
    capIndex := capIndex and not (LongInt(1) shl pos[n]);
    Pop := n;
  end;
  procedure ChangeSide(n: integer);
  begin
    with PList[pos[n]] do
      if iColor = white then iColor := black
      else iColor := white;
  end;
  procedure Link(from, _to: integer; newPiece: TPiece);
  var
    j: integer;
  begin
    if top > 0 then {captures}
      if not findCap then
      begin
        findCap := true;
        cnt := treeCnt[ply];
      end;
    with tree[cnt] do
    begin
      mFrom := from;
      mTo := _to;
      mIndex := cnt; { start index, (sort change) }
      mPiece := startPiece;
      mNewPiece := newPiece;
      mCapIndex := capIndex;
        {0002}
      if capIndex = 0 then
        mSortVal := histTable[side, newPiece, mTo]
      else
        mSortVal := histTable[side, newPiece, mTo] + PopCnt(capIndex);
    end;
    inc(cnt);
  end;
  function CapKing(n, d: integer): boolean;
  label
    loop;
  var
    save, k, j: integer;
    cap: boolean;
    function Empty: boolean;
    begin
      Empty := top <= save;
    end;
  begin
    cap := false;
    save := top;
    loop:
    while pos[n] = EmptyIndex do
      n := n + d;
    if PList[pos[n]].iColor = xside then
      if pos[n + d] = EmptyIndex then
      begin
        Push(n);
        ChangeSide(n);
        n := n + 2 * d;
        goto loop;
      end;
    while not Empty do
    begin
      j := stack[top - 1];
      n := n - d;
      while n <> j do
      begin
        for k := 0 to 3 do
          if dir[k] <> d then
            if dir[k] <> -d then
              if CapKing(n, dir[k]) then
                cap := true;
         { if not cap then Link(from,n,king);}
        n := n - d;
      end;
      {?????}
      if not cap then
      begin
        k := n + d;
        while pos[k] = EmptyIndex do
        begin
          Link(from, k, king);
          k := k + d;
        end;
      end;
       {????}

      cap := true;
      Pop;
      ChangeSide(n);
    end;
    CapKing := cap;
  end;
  function CapPawn(n, d: integer): boolean;
  var
    cap: boolean;
    k: integer;
  begin
    cap := false;
    if pos[n] = EmptyIndex then
      if PList[pos[n + d]].iColor = xside then
        if pos[n + d + d] = EmptyIndex then
        begin
          Push(n + d);
          ChangeSide(n + d);
          for k := 0 to 3 do
            if dir[k] <> -d then
              if Promote(n + d + d) then
              begin
                if CapKing(n + d + d, dir[k]) then
                  cap := true;
              end else
              begin
                if CapPawn(n + d + d, dir[k]) then
                  cap := true;
              end;
          if not cap then
            if Promote(n + d + d) then
              Link(from, n + d + d, king)
            else
              Link(from, n + d + d, pawn);
          Pop;
          ChangeSide(n + d);
          cap := true;
        end;
    CapPawn := cap;
  end;
begin
  cnt := treeCnt[ply];
  capCnt := CapTreeCnt[ply];
  findCap := false;
  if ply < Max_Ply - 1 then
  begin
    top := 0;
    capIndex := 0;
    for itemp := PStart[side] to PStop[side] do
    begin
      i := pRnd[itemp];
      with PList[i] do
        if iEnable then
        begin
        { RemovePiece(i);}
          pos[iSquare] := EmptyIndex;
          from := iSquare;
          startPiece := iPiece;
          if iPiece = pawn then
          begin
            for j := 0 to 3 do
            begin
              d := dir[j];
              u := from + d;
              if pos[u] = EmptyIndex then
              begin
                if not findCap then
                  if up[j] = side then
                  begin
                    if Promote(u) then
                      Link(from, u, king)
                    else
                      Link(from, u, pawn);
                  end;
              end else if PList[pos[u]].iColor = xside then
              begin
                {RECURSIVE CAPTURES}
                if pos[u + d] = EmptyIndex then
                  CapPawn(from, d);
              end;
            end;
          end else
          begin {king}
            for j := 0 to 3 do
            begin
              d := dir[j];
              u := from + d;
              while pos[u] = EmptyIndex do
              begin
                if not findCap then Link(from, u, king);
                u := u + d;
              end;
              if (PList[pos[u]].iColor = xside) and
                (pos[u + d] = EmptyIndex) then
                begin
               {RECIRSIVE CAPTURE SEARCH}
                CapKing(u - d, d);
              end;
            end;
          end;
{         InsertPiece(i);}
          pos[iSquare] := i;
        end; {if}
    end; {for}
  end; {if}
  treeCnt[ply + 1] := cnt;
  CapTreeCnt[ply + 1] := capCnt;
end;

{
function GetTickCount64:LongInt;
var
 timer:LongInt absolute $40:$6C;
begin
  GetTickCount64 := timer * 1000  div  18;
end;
}

procedure TimeReset;
begin
  startTime := GetTickCount64;
  currTime := startTime;
  timeOver := false;
  cntPos := 0;
end;

function TimeUp: boolean;
begin
  inc(cntPos);
  if not timeOver then
    if (cntPos and $FFF) = 0 then
    begin
      currTime := GetTickCount64;
      if currTime < startTime then startTime := currTime;
      if currTime - startTime >= maxTime * 1000 then
        timeOver := true;
    end;
  TimeUp := timeOver;
end;

procedure PrepareEvaluate;
var
  c: TColor;
  i: integer;
  j, add, sqVal: integer;
begin

  glHashPawns := (pCnt[white, pawn] + pCnt[black, pawn]) > 0;
  glHashKings := (pCnt[white, king] + pCnt[black, king]) > 0;

  if game_cnt < 6 then
  begin { random debut - first moves }
    for j := low(king_score) to high(king_score) do
      rnd_tbl[j] := random(king_score[j] + 1);
  end else
  begin
    for j := low(king_score) to high(king_score) do
      rnd_tbl[j] := 0;
  end;

  for c := white to black do
  begin
    stMainScore[c] := 0;
    for i := PStart[c] to PStop[c] do
      with PList[i] do
        if iEnable then
          SqValue(i, true);
  end;
end;

procedure SqValue(i: TIndex; isInc: boolean);
var
  s0: integer;
begin
  s0 := 0; {s1 := 0;}

  {00014}
  with PList[i] do
  begin
    if iPiece = pawn then
    begin
       {010}
      if iColor = black then
      begin

        inc(s0, w_pawn_score[99 - iSquare]);
        inc(s0, w_pawn_temp[99 - iSquare]);

      end else
      begin

        inc(s0, w_pawn_score[iSquare]);
        inc(s0, w_pawn_temp[iSquare]);

      end;
    end else
    begin

      inc(s0, king_score[iSquare]);
     {0014}
      inc(s0, 60); { MAX STRATEG BONUS }

    end;

   {003}

    if isInc then
    begin
      inc(stMainScore[iColor], s0);
    end else
    begin
      dec(stMainScore[iColor], s0);
    end;

  end; {with}
end;

function Evaluate(alpha, beta: integer): integer;
var
  w_score, b_score: integer;
begin

  w_score := mtl[white] + stMainScore[white];
  b_score := mtl[black] + stMainScore[black];

 {0014}
 {Премия за первую дамку}
  if pCnt[white, king] > 0 then w_score := w_score + valueP;
  if pCnt[black, king] > 0 then b_score := b_score + valueP;

 {3 дамки загоняют одну - стратегическая оценка для сильнейшей стороны выключена}

(****************
 if mtl[black] = valueK then
  if mtl[black] < mtl[white] then
   if stMainScore[black] = KING_ON_A1H8_VALUE then
    inc(bScore, 20);

 if mtl[white] = valueK then
  if mtl[white] < mtl[black] then
   if stMainScore[white] = KING_ON_A1H8_VALUE then
    inc(wScore, 20);
****************)

 {010}
 {00011}
 (**************************
 if pcnt[white,pawn] + pcnt[black,pawn] = 0 then begin
 
   if mtl[black] = valueK then
     if mtl[white] >= 3*valueK then
      if stMainScore[black] < KING_ON_A1H8_VALUE then
        w_score := mtl[white] + valueK; {Без стратегической оценки}


   if mtl[white] = valueK then
    if mtl[black] >=  3*valueK then
      if stMainScore[white] < KING_ON_A1H8_VALUE then
        b_score := mtl[black] + valueK; {Без стратегической оценки}


 end;
 **********************)

  if side = white then
    evaluate := w_score - b_score
  else
    evaluate := b_score - w_score;

end;

procedure Pick(low, high: integer);
var
  maxI, j: integer;
  maxVal: LongInt;
  temp: TMove;
begin
  maxI := low;
  maxVal := tree[maxI].mSortVal;
  for j := low + 1 to high do
    if tree[j].mSortVal > maxVal then
    begin
      maxVal := tree[j].mSortVal;
      maxI := j;
    end;
  if maxI <> low then
  begin
    temp := tree[low];
    tree[low] := tree[maxI];
    tree[maxI] := temp;
  end;
end;

var
  find_cap, threat: array[0..MAX_PLy] of boolean;
var
  do_reduction, iid_enable: boolean;
var
  find_mv_cnt: integer;

function Search(alpha, beta, depth, in_mv: integer; var out_mv: integer): integer;

label
  skipSearch;

  function Pawn_Rank_7(var mv: TMove; c: TColor): boolean;
  begin
    pawn_rank_7 := false;
    with mv do
      if mNewPiece = pawn then
        if ((c = white) and (row[mTo] = 2)) or
          ((c = black) and (row[mTo] = 7)) then
          pawn_rank_7 := true;

  end;

var
  j, k, tmp, cnt, margin, oldAlpha: integer;
  mv: PMove;

  moveFrom, moveTo: integer;
  tempMove: TMove;
  lgCnt, nextDepth, m_cnt: integer;

  c0: TColor;
  tmp_mv_i, old_alpha: integer;
  save_do_reduction: boolean;

begin

  old_alpha := alpha;
  c0 := side;

  if TimeUp then exit;
  if ply >= Max_Ply - 2 then
  begin
    Search := Evaluate(alpha, beta);
    exit;
  end;

  cnt := treeCnt[ply + 1] - treeCnt[ply];
  if cnt = 0 then
  begin
    Search := -infinity + ply;
    exit;
  end;
  if (ply = 0) and (cnt = 1) then exit;

 {try hash table}
  if (ply > 0) and (depth > 0) then
    with HashLook(ord(side))^ do
      if (hDepth >= depth) and (hKey.key0 = key.key0)
        and (hKey.key1 = key.key1) then
        case hFLag of
          H_ALPHA: if hScore <= alpha then
            begin
              Search := hScore;
              exit;
            end;
          H_EXACT:
            begin
              Search := hScore;
              out_mv := hMoveIndex;
              exit;
            end;
          H_BETA: if hScore >= beta then
            begin
              Search := hScore;
              out_mv := hMoveIndex;
              exit;
            end;
        end;

  {00012}
  if depth <= 0 then
  begin {captures only search }
    if not find_Cap[ply] then
    begin
      Search := Evaluate(alpha, beta);
      exit;
    end;
  end;

  if ply = 0 then
    glDepth := depth;

  lgCnt := 0;
  m_cnt := 0;

 {00011}

  {******
  if ply > 0 then
   if (in_mv >= treeCnt[ply]) and (in_mv < treeCnt[ply+1])
      then  tree[in_mv].mSortVal := MAX_HIST + 1000;
  *******}

  if ply > 0 then
    if (in_mv >= treeCnt[ply]) and (in_mv < treeCnt[ply + 1]) then
      for j := treeCnt[ply] to treeCnt[ply + 1] - 1 do
        with tree[j] do
          if mIndex = in_mv then
          begin
            mSortVal := MAX_HIST + 1000 + depth;
            break;
          end;

  tmp_mv_i := treeCnt[ply + 1] + random(12);

  for j := treeCnt[ply] to treeCnt[ply + 1] - 1 do
  begin
    Pick(j, treeCnt[ply + 1] - 1);
    mv := @tree[j];
    MakeMove(mv^);
    inc(m_cnt);
    game_list[game_cnt + ply] := mv^;

    nextDepth := depth - 1;

     {00012}

    side := opSide[side]; xside := opSide[xside]; inc(ply);

    Generate(find_Cap[ply]);

    if treeCnt[ply + 1] - treeCnt[ply] = 0 then
    begin
      tmp := infinity - ply;
      goto skipSearch;
    end;

    threat[ply] := find_cap[ply] or Pawn_Rank_7(mv^, c0);

     {0001  search}
     {
     if(depth>2) and (alpha<0) and not threat[ply] and
       (-Evaluate(-(alpha+1),-alpha)<=alpha) then
        tmp := -Search(-(alpha+1),-alpha,nextDepth div 2,tmp_mv_i, tmp_mv_i)
     else tmp := alpha+1;

    if tmp > alpha then
    }
    tmp := -Search(-beta, -alpha, nextDepth, tmp_mv_i, tmp_mv_i);

    skipSearch:
    side := opSide[side]; xside := opSide[xside]; dec(ply);

    UnMakeMove(mv^);
    if TimeUp then break;
    if tmp > -infinity + 100 then inc(lgCnt);

    if tmp > alpha then
    begin
      out_mv := mv^.mIndex; {0002 search}
      oldAlpha := alpha;
      alpha := tmp;
      if ply = 0 then
      begin
        mv^.mSortVal := LongInt(MAX_HIST) + LongInt(depth) * 100 + find_mv_cnt;
        inc(find_mv_cnt);
      end;
      if (depth > 0) {and (mv^.mCapIndex = 0) } then
        HistWrite(oldAlpha, alpha, beta, side, mv^.mNewPiece, mv^.mTo);
      if ply = 0 then
      begin
        searchDepth := depth;
        searchScore := alpha;
      end;

      if depth > 0 then
      begin
        if alpha >= beta then
          HashInsert(alpha, depth, ord(side), H_BETA, mv^.mIndex)
        else
          HashInsert(alpha, depth, ord(side), H_EXACT, mv^.mIndex);
      end;

    end;
    if alpha >= beta then
    begin
      Search := alpha;
      exit;
    end;
  end;

  if alpha <= old_alpha then
    if depth > 0 then
      HashInsert(alpha, depth, ord(side), H_ALPHA, -1);
  Search := alpha;

end;

{///// main search}

function main_search(alpha, beta, depth, in_mv: integer;
  var out_mv: integer; exclude_mv: integer): integer;

label
  skipSearch;

  function Pawn_Rank_7(var mv: TMove; c: TColor): boolean;
  begin
    pawn_rank_7 := false;
    with mv do
      if mNewPiece = pawn then
        if ((c = white) and (row[mTo] = 2)) or
          ((c = black) and (row[mTo] = 7)) then
          pawn_rank_7 := true;

  end;

var
  j, k, tmp, cnt, margin, oldAlpha: integer;
  mv: PMove;

  moveFrom, moveTo: integer;
  tempMove: TMove;
  lgCnt, nextDepth, m_cnt: integer;

  c0: TColor;
  tmp_mv_i, foo_mv_i: integer;
  save_do_reduction: boolean;
  fixed_depth: integer;
  peeck_depth: integer;
{ start_score:integer;}
  t: integer;
  old_score, nd: integer;
  old_alpha, hash_mv: integer;
begin

  old_alpha := alpha;
  hash_mv := -1;

{00011}

  fixed_depth := 2; {Max(glDepth div 2, 2);}

  c0 := side;

  if TimeUp then exit;
  if ply >= Max_Ply - 2 then
  begin
    main_search := Evaluate(alpha, beta);
    exit;
  end;

  cnt := treeCnt[ply + 1] - treeCnt[ply];
  if cnt = 0 then
  begin
    main_search := -infinity + ply;
    exit;
  end;
  if (ply = 0) and (cnt = 1) then exit;

 {try hash table}

  if (ply > 0) and (depth > 0) then
    with HashLook(ord(side))^ do
      if (hKey.key0 = key.key0) and (hKey.key1 = key.key1) then
      begin

        if hMoveIndex > 0 then
          hash_mv := hMoveIndex;

        if exclude_mv <= 0 then
          if hDepth >= depth then
            case hFLag of

              H_EXACT:
                begin

                  main_search := hScore;
                  out_mv := hMoveIndex;
                  exit;

                end;
              H_BETA: if hScore >= beta then
                begin

                  main_search := hScore;
                  out_mv := hMoveIndex;
                  exit;
                end;
              H_ALPHA: if hScore <= alpha then
                begin

                  main_search := hScore;
                  exit;

                end;
            end;
      end;

  if depth <= 0 then
  begin {captures only search }
    if not find_Cap[ply] then
    begin
      main_search := Evaluate(alpha, beta);
      exit;
    end;
  end;

  if ply = 0 then
    glDepth := depth;

  lgCnt := 0;
  m_cnt := 0;

  {00011}

  { ASSIGN SORT VALUE FOR BEST MOVES  }
  if ply > 0 then
    if (in_mv > 0) or (hash_mv > 0) then
      for j := treeCnt[ply] to treeCnt[ply + 1] - 1 do
        with tree[j] do
          if mIndex = in_mv then
          begin

            mSortVal := MAX_HIST + 1000 + depth;

          end else if mIndex = hash_mv then
          begin

            mSortVal := MAX_HIST + 100;

          end;

  tmp_mv_i := -1;

  for j := treeCnt[ply] to treeCnt[ply + 1] - 1 do
  begin
    Pick(j, treeCnt[ply + 1] - 1);
    mv := @tree[j];
    inc(m_cnt);

     {00011}

    if (mv^.mIndex = exclude_mv)
      then continue;

    MakeMove(mv^);
    game_list[game_cnt + ply] := mv^;

    nextDepth := depth - 1;

    side := opSide[side]; xside := opSide[xside]; inc(ply);

    Generate(find_Cap[ply]);

    if treeCnt[ply + 1] - treeCnt[ply] = 0 then
    begin
      tmp := infinity - ply;
      goto skipSearch;
    end;

    threat[ply] := find_cap[ply] or Pawn_Rank_7(mv^, c0);
     {
     if(ply>2) and (ply<searchdepth) and threat[ply] then begin
       nextDepth := depth;
     end;
     }

  {0001 main_search}
    if nextDepth <= fixed_depth then
    begin

      tmp := -Search(-beta, -alpha,
        nextDepth,
        tmp_mv_i, tmp_mv_i);

    end else
    begin

{00012}
      tmp := -Search(-beta, -alpha,
        nextDepth - 2,
        tmp_mv_i, tmp_mv_i);
      if (tmp > alpha) then
      begin
        tmp := -Main_Search(-beta, -alpha,
          nextDepth,
          tmp_mv_i, tmp_mv_i, -1);
      end;

(*
    tmp := -Search(-beta,-alpha,
                    fixed_depth,
                    tmp_mv_i, tmp_mv_i);

    peeck_depth := fixed_depth+1;

    while (peeck_depth <= nextDepth)  do
    begin
     tmp := -Main_Search(-beta,-alpha,
                         peeck_depth,
                         tmp_mv_i, tmp_mv_i, -1);

     {EXACT SCORE}
     if tmp < -infinity + max_ply then
      if tmp < beta then
       break;
     if tmp > infinity - max_ply then
      if tmp > alpha then
       break;

     {CUT}
  if peeck_depth > (depth shr 2) then
  begin

     { SEARCH OTHER MOVE FOR CUT ?! }
     if peeck_depth < nextDepth then
      if tmp <= alpha then
      begin

       if treeCnt[ply+1]-treeCnt[ply] = 1 then
         tmp := alpha + 1
       else if find_cap[ply] then
         tmp := alpha + 1
       else
         tmp := -Main_Search(-(alpha+1),-alpha,
                            peeck_depth,
                            tmp_mv_i, foo_mv_i, tmp_mv_i);
      end;

     if tmp <= alpha then
        break;

  end;

     inc(peeck_depth);
    end;

  *)
    end;

    skipSearch:
    side := opSide[side]; xside := opSide[xside]; dec(ply);

    UnMakeMove(mv^);
    if TimeUp then break;
    if tmp > -infinity + 100 then inc(lgCnt);

    if tmp > alpha then
    begin
      out_mv := mv^.mIndex;
      oldAlpha := alpha;
      { alpha := tmp; }{003}

      if ply = 0 then
      begin
         {0002}
        mv^.mSortVal := LongInt(MAX_HIST) + LongInt(depth) * 100 + find_mv_cnt;
        inc(find_mv_cnt);
        if tmp < beta then
          alpha := tmp - 1 {003   >= alpha, for random move order }
        else
          alpha := tmp; {003}
      end else
        alpha := tmp; {003}

      if (depth > 0) {and (mv^.mCapIndex = 0) } then
        HistWrite(oldAlpha, alpha, beta, side, mv^.mNewPiece, mv^.mTo);
      if ply = 0 then
      begin
        searchDepth := depth;
        searchScore := alpha;
      end;

       {0002}
      if exclude_mv <= 0 then
        if depth > 0 then
        begin
          if alpha >= beta then
            HashInsert(alpha, depth, ord(side), H_BETA, mv^.mIndex)
          else
            HashInsert(alpha, depth, ord(side), H_EXACT, mv^.mIndex);
        end;

    end;
    if alpha >= beta then
    begin
       { if random(3) = 0 then
           main_search:= beta
        else }
      main_search := alpha;
      exit;
    end;
  end;

  if exclude_mv <= 0 then
    if depth > 0 then
      if alpha <= old_alpha then
        HashInsert(alpha, depth, ord(side), H_ALPHA, -1); {0002}
  main_search := alpha;

end;

{///// end main search}

function SearchMove(var mv: TMove): boolean;
var
  a, b, score, d, tmp_mv_i: integer;
begin
   {010}
  root_side := side;
  glDepth := 0;
  __hashCut := 0;
  searchDepth := 0;
  searchScore := 0;
  TimeReset;
  HashClear;
  HistClear(game_cnt);
  InitRndMoveOrder;
  PrepareEvaluate;
  iid_enable := true;
     {(pcnt[white,pawn] > 3) and (pcnt[black,pawn] > 3);}
  if (random(5) > 2) and LibLook(mv) then
  begin
    SearchMove := true;
    exit;
  end;
  find_mv_cnt := 0;
  randomize;
   {0002}
  Generate(find_Cap[ply]);
  if treeCnt[1] > 0 then
    tree[random(treeCnt[1])].msortval := 50;

  d := 3;
  searchScore := 0;
  score := 0;
   {0002}
  while (d < Max_Ply - 10) and not timeup do
  begin

    glDepth := d;

    if (score < -valueK) or (score > valueK) then
    begin
      score := main_search(-infinity, infinity, d, -1, tmp_mv_i, -1);
    end else
    begin

     {
       a := score - 16;
       b := score + 24 + random(8);
     }
      {0002}
      a := -INFINITY;
      b := INFINITY;

      score := main_search(a, b, d, -1, tmp_mv_i, -1);
      if timeup then break;
      if score >= b then score := main_search(b, infinity, d, -1, tmp_mv_i, -1)
      else if score <= a then score := main_search(-infinity, a, d, -1, tmp_mv_i, -1);

    end;
    d := d + 1;
  end;

  if treeCnt[1] - treeCnt[0] > 0 then
  begin
    Pick(0, treeCnt[1] - 1);
    mv := tree[0];
    SearchMove := true;
  end else SearchMove := false;
{   t := HashStatus;}
end;

{случайный порядок ходов для того, чтобы программа изменяла
стиль игры и выбирала различные перемещения}

procedure InitRndMoveOrder;
 { инициализует в массиве промежуток от low до high
  и перемешивает его случайным образом}
  procedure RandomArray(var v: array of integer; low, high: integer);
  var
    j, i0, i1, tmp: integer;
  begin
    for j := low to high do
      v[j] := j;
    for j := 0 to 100 do
    begin
      i0 := random(high - low + 1) + low;
      i1 := random(high - low + 1) + low;
      tmp := v[i0];
      v[i0] := v[i1];
      v[i1] := tmp;
    end;
  end;

begin
  RandomArray(pRnd, PStart[white], PStop[white]);
  RandomArray(pRnd, PStart[black], PStop[black]);
end;

function LibLook(var mv: TMove): boolean;
label
  nextLine;
const
  lib: array[0..23] of PChar =
  (
  {КОЛ}
    'c3d4 b6a5   d4c5 d6b4   a3c5',
    'c3b4 b6a5   b4c5 d6b4   a3c5',
  {J<HFNYSQ RJK}
    'c3b4 f6e5   g3h4 e5f4   e3g5 h6f4',
  {ТЫЧОК}
    'c3d4 f6g5   d4c5 b6d4   e3c5 d6b4   a3c5',
    'c3b4 f6e5   b4c5 b6d4   e3c5 d6b4   a3c5',
  {обратный тычок}
    'c3d4 f6g5   b2c3 g5f4   g3e5 d6f4   e3g5 h6f4',
  {городская партия}
    'c3d4 d6c5   b2c3 f6g5',
    'c3d4 d6c5   d2c3 f6g5',
  {обратная городская партия}
    'c3b4 f6e5   e3f4 g7f6   b4a5 f6g5   b2c3 g5e3   d2f4',
    'c3b4 f6e5   e3f4 g7f6   d2e3',
    'c3b4 f6e5   e3f4 e7f6   b4a5 f6g5   b2c3 g5e3   d2f4',
  {отыгрыш - спокойная позиция}
    'c3d4 d6c5   b2c3 c7d6   c3b4 b6a5   d4b6 a5c7',
  {отыгрыш с разменом вперед}
    'c3d4 d6c5   b2c3 c7d6   c3b4 b6a5   d4b6 a5c3   d2b4 a7c5',
  {старая партия - закрытая позиция}
    'c3d4 d6c5   b2c3 e7d6',
  {перккресток - обоюдная связка, острая игра}
    'c3d4 d6e5   b2c3 e7d6   e3f4',
  {обратный перекресток}
    'c3d4 d6e5   b2c3 e7d6   g3h4',
  {косяк - закрытое начало}
    'c3b4 f6g5   g3f4 g7f6   b2c3 b6c5',
  {обратный косяк}
    'c3b4 f6g5   g3f4 g7f6   b2c3 f6e5',
  {игра Петрова - игра по углам, острая}
    'g3h4 b6a5   f2g3 c7b6   e3f4 d6c5',
  {цнтральная партия - белые в центр, черные окружают}
    'c3d4 f6g5   g3f4 g7f6   b2c3',
  {игра Бодянского}
    'a3b4 b6a5   b2a3 c7b6',
  {обратная игра Бодянского}
    'c3d4 h6g5   g3h4',
  {игра Каулена}
    'g3f4 f6e5   h2g3',
  { игра Филлипова}
    'e3d4 d6e5  a3b4 h6g5'
    );
  function GetMove(s: PChar; var from, _to: integer): boolean;
  begin
    if strlen(s) >= 4 then
    begin
      from := (ord(s[0]) - ord('a')) + 1 +
        ((7 - (ord(s[1]) - ord('1'))) + 1) * 10;
      _to := (ord(s[2]) - ord('a')) + 1 +
        ((7 - (ord(s[3]) - ord('1'))) + 1) * 10;
      GetMove := true;
    end else GetMove := false;
  end;
  procedure SkipMove(var s: PChar);
  var
    j: integer;
  begin
    j := 0;
    while (s[j] <> #0) and (s[j] <> ' ') do
      inc(j);
    while (s[j] <> #0) and (s[j] = ' ') do
      inc(j);
    s := @s[j];
  end;
  procedure RandHlat(var hlat: array of integer);
    procedure swap(var N1, N2: integer);
    var
      tmp: integer;
    begin
      tmp := N1; N1 := N2; N2 := tmp;
    end;
    function RandInt(low, high: integer): integer;
    begin
      RandInt := random(high - low + 1) + low;
    end;
  var
    j, k: integer;
  begin
    for j := low(hlat) to high(hlat) do
      hlat[j] := j;
   {004}

    for j := low(hlat) to high(hlat) do
    begin
      k := RandInt(j, high(hlat));
      swap(hlat[j], hlat[k]);
    end;

  end;

var
  hlat: array[low(lib)..high(lib)] of integer;
  j, k, from, _to: integer;
  s: PChar;
  findCap: boolean;
begin
  LibLook := false;
  if game_cnt < 16 then
  begin
    RandHlat(hlat);
    Generate(findCap);
    for j := low(lib) to high(lib) do
    begin
      s := lib[hlat[j]];
      for k := 0 to game_cnt - 1 do
      begin
        if not GetMove(s, from, _to) then goto nextLine;
        with game_list[k] do
          if (mFrom <> from) or (mTo <> _to) then
            goto nextLine;
        SkipMove(s);
      end;
      if not GetMove(s, from, _to) then goto nextLine;
      for k := 0 to treeCnt[1] - 1 do
        with tree[k] do
          if (mFrom = from) and (mTo = _to) then
          begin
            mv := tree[k];
            LibLook := true;
            exit;
          end;
      nextLine:
    end {for j}
  end;
end;

const
  ch_width = 40;
  ch_height = 40;
  brd_left = 100;
  brd_top = 20;
  desc: array[TSquare] of byte =
  (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 1, 0, 1, 0, 1, 0,
    0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
    0, 0, 1, 0, 1, 0, 1, 0, 1, 0,
    0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
    0, 0, 1, 0, 1, 0, 1, 0, 1, 0,
    0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
    0, 0, 1, 0, 1, 0, 1, 0, 1, 0,
    0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );
var
  showSave: array[TSquare] of LongInt;
  sel: array[TSquare] of byte;

procedure ShowPos;
  procedure ShowSquare(x, y: integer);
  var
    v: array[1..4] of PointType;
  begin
    SetColor(ptcGraph.white);
    SetFillStyle(3, ptcGraph.white);
    v[1].x := x; v[1].y := y;
    v[2].x := x + ch_width; v[2].y := y;
    v[3].x := x + ch_width; v[3].y := y + ch_height;
    v[4].x := x; v[4].y := y + ch_height;
    FillPoly(4, v);
  end;
  procedure ShowWhitePawn(x, y: integer);
  begin
    SetColor(ptcGraph.white);
    SetFillStyle(6, ptcGraph.white);
    FillEllipse(x + ch_width div 2,
      y + ch_height div 2,
      ch_width div 2 - 6,
      ch_height div 2 - 6);
  end;
  procedure ShowBlackPawn(x, y: integer);
  begin
    SetColor(ptcGraph.white);
    SetFillStyle(0, ptcGraph.white);
    FillEllipse(x + ch_width div 2,
      y + ch_height div 2,
      ch_width div 2 - 6,
      ch_height div 2 - 6);
  end;
  procedure ShowKingLabel(x, y: integer);
  begin
    SetColor(ptcGraph.white);
    SetFillStyle(1, ptcGraph.white);
    FillEllipse(x + ch_width div 2,
      y + ch_height div 2,
      4,
      4);
  end;
  procedure ShowSel(x, y: integer);
  begin
    SetColor(ptcGraph.white);
    Rectangle(x + 2, y + 2, x + ch_width - 2, y + ch_height - 2);
  end;
  procedure ShowCap(x, y: integer);
  begin
    SetColor(ptcGraph.white);
    Line(x + 2, y + 2, x + ch_width - 2, y + ch_height - 2);
    Line(x + ch_width - 2, y + 2, x + 2, y + ch_height - 2);
  end;
  function IntToStr(I: Longint): string;
  var
    S: string[11];
  begin
    Str(I, S);
    IntToStr := S;
  end;

  procedure ShowSearchStatus;
  var
    v: array[1..4] of PointType;
    x, y, W, H: integer;
  begin

   {00011}

    exit;

    W := 100;
    H := 60;
    x := GetMaxX - W - 20;
    y := GetMaxY - H - 20;
    SetColor(ptcGraph.white);
    SetFillStyle(3, ptcGraph.black);
    v[1].x := x; v[1].y := y;
    v[2].x := x + W; v[2].y := y;
    v[3].x := x + W; v[3].y := y + H;
    v[4].x := x; v[4].y := y + H;
    FillPoly(4, v);
    OutTextXY(x + 4, y + 10, 'depth ' + IntToStr(searchDepth));
    OutTextXY(x + 4, y + 34, 'score ' + IntToStr(searchScore));

  end;

const
  firstShow: boolean = true;
  msg1 = 'Russian Checkers';
  menu: array[0..1] of string =
  (

    'Cntrl-W   new ',
    'Esc       exit'

{
   'Cntrl-A   move (go)',

   'Cntrl-Z   undo',
   'Cntrl-X   redo',

   'Cntrl-S   save ',
   'Cntrl-D   load',
   }
    );

  liters: array[0..7] of char = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h');
var
  j, left, top: integer;
  t: LongInt;
begin
  if firstShow then
  begin
    firstShow := false;
    for j := 0 to high(TSquare) do
      showSave[j] := -1;

     {header}
    SetTextStyle(DefaultFont, HorizDir, 2);
    OutTextXY((GetMaxX - TextWIdth(msg1)) div 2, 14, msg1);
     {menu}
    left := GetMaxY;
    top := 270 + 30;
    SetTextStyle(DefaultFont, HorizDir, 1);
    for j := low(menu) to high(menu) do
    begin
      OutTextXY(left, top, menu[j]);
      top := top + 20;
    end;
     {board notation}
    left := brd_left + ch_width + ch_width div 2;
    top := brd_top + 9 * ch_height + 4;
    for j := 0 to 7 do
    begin
      OutTextXY(left, top, liters[j]);
      left := left + ch_width;
    end;

    left := brd_left + ch_width - 12;
    top := brd_top + ch_height + ch_height div 2;
    for j := 8 downto 1 do
    begin
      OutTextXY(left, top, IntToStr(j));
      top := top + ch_height;
    end;

    SetTextStyle(DefaultFont, HorizDir, 1);
  end;

  for j := 0 to high(TSquare) do
    if desc[j] = 1 then
      with PList[pos[j]] do
      begin
        t := LongInt(sel[j]) or
          (LongInt(iPiece) shl 4) or
          (LongInt(iColor) shl 8) or
          (LongInt(iEnable) shl 12) or
          (LongInt(iSquare) shl 16);
        if showSave[j] <> t then
        begin
          showSave[j] := t;
          left := brd_left + column[j] * ch_width;
          top := brd_top + row[j] * ch_height;
          ShowSquare(left, top);
          if iColor = black then
          begin
            ShowBLackPawn(left, top);
            if iPiece = king then
              ShowKingLabel(left, top);
          end else if iColor = white then
          begin
            ShowWhitePawn(left, top);
            if iPiece = king then
              ShowKingLabel(left, top);
          end;
          if sel[j] = 1 then
          begin
            if pos[j] = EmptyIndex then
              ShowSel(left, top)
            else
              ShowCap(left, top);
          end else if sel[j] = 2 then
            ShowSel(left, top);
        end;
      end;
  ShowSearchStatus;
end;

function MouseClick(var N: integer): boolean;
var
  countPress, mx, my, x, y, j: integer;

begin
  MouseClick := false;

  GetMouseState(mx, my, countPress);

  if countPress > 0 then
  begin
    x := (mx - brd_left) div ch_width;
    y := (my - brd_top) div ch_height;
    if (word(x) < 10) and (word(y) < 10) then
    begin
      j := y * 10 + x;
      if desc[j] = 1 then
      begin
        N := j;
        MouseClick := true;
      end;
    end;
  end;
end;

procedure beep;
begin
end;

const
  FILE_NAME = 'lastgame.dat';
var
  grDriver: smallint;
  grMode: smallint;
  ErrCode: Integer;
  N, j: integer;
  selN: integer;
  findCap: boolean;
  c: char;
  f: file;
  save_game_cnt, save_game_max: integer;
  capIndex: LongInt;
  mv: TMove;

procedure Go;
begin
  fillchar(sel, sizeof(sel), 0);

  ShowPos;
  if SearchMove(mv) then
  begin
    MakeMove(mv);
    side := opSide[side];
    xside := opSide[xside];
    game_list[game_cnt] := mv;
    inc(game_cnt);
    game_max := game_cnt;
    sel[mv.mFrom] := 2;
    sel[mv.mTo] := 2;
    ShowPos;
  end else
  begin
    beep;
  end;
end;
begin

  grDriver := VGA; grMode := VgaHi;
  WindowTitle := 'Russian Checkers';
  InitGraph(grDriver, grMode, '');

  ErrCode := GraphResult;
  if ErrCode <> grOk then
    Writeln('Graphics error:', GraphErrorMsg(ErrCode))
  else
  begin
    if paramCount = 1 then
    begin
      Val(ParamStr(1), maxTime, errCode);
      if maxTime < 3 then maxTime := 3
      else if maxTime > 30 then maxTime := 30;
    end;

    randomize;
    InitNewGame;

    ShowPos;

    selN := -1;
    while true do
    begin

      if keypressed then
      begin
        c := ReadKey;
        case ord(c) of
          27: break; {Esc, exit}
          ord('f'):
            Evaluate(-INFINITY, INFINITY);
          19:
            begin {Cntrl-S,  save game}
              Assign(f, FILE_NAME);
              Rewrite(f, 1);
              BlockWrite(f, game_list, sizeof(game_list));
              BlockWrite(f, game_cnt, sizeof(game_cnt));
              BlockWrite(f, game_max, sizeof(game_max));
              Close(f);
            end;
          4:
            begin {Cntrl-D, load game}
{$I-}
              Assign(f, FILE_NAME);

              Reset(f, 1);
{$I+}
              if IOResult = 0 then
              begin
                InitNewGame;
                BlockRead(f, game_list, sizeof(game_list));
                BlockRead(f, game_cnt, sizeof(game_cnt));
                BlockRead(f, game_max, sizeof(game_max));
                Close(f);
                for j := 0 to game_cnt - 1 do
                begin
                  MakeMove(game_list[j]);
                  side := opSide[side];
                  xside := opSide[xside];
                end;
                fillchar(sel, sizeof(sel), 0);
                ShowPos;
              end else beep;
            end; {case}
          1:
            begin {Cntrl-A,  Go}

              Go;
            end;
          26:
            begin {Cntrl-Z,  Back}
              if game_cnt > 0 then
              begin
                dec(game_cnt);
                side := opSide[side];
                xside := opSide[xside];
                UnMakeMove(game_list[game_cnt]);
                fillchar(sel, sizeof(sel), 0);
                ShowPos;
              end else beep;
            end;
          24:
            begin {Cntrl-X, Next}
              if game_cnt < game_max then
              begin
                MakeMove(game_list[game_cnt]);
                inc(game_cnt);
                side := opSide[side];
                xside := opSide[xside];
                fillchar(sel, sizeof(sel), 0);
                ShowPos;
              end else beep;
            end;
          23:
            begin {Cntrl-W, new game WHITE}
              InitNewGame;
              fillchar(sel, sizeof(sel), 0);
              ShowPos;
            end;
          0:
            begin
              c := ReadKey;

            end;
        end;
      end;

      if MouseClick(N) then
        with PList[pos[N]] do
        begin
          if iColor = side then
          begin {SELECT FROM SQUARE}
            selN := N;
            capIndex := 0;
            fillchar(sel, sizeof(sel), 0);
            Generate(findCap);
            for j := 0 to treeCnt[1] - 1 do
              with tree[j] do
                if mFrom = selN then
                  sel[mTo] := 1;
            ShowPos;
          end else if iColor = xside then
          begin {SELECT CAPTURE PIECE}
            Generate(findCap);
            if findCap then
              for j := 0 to treeCnt[1] - 1 do
                with tree[j] do
                  if mFrom = selN then
                    if (mCapIndex and (LongInt(1) shl pos[N])) <> 0 then
                    begin
                      capIndex := capIndex or (LongInt(1) shl pos[N]);
                      sel[N] := 1;
                      ShowPos;
                      break;
                    end;

          end else if sel[N] = 1 then
          begin
            Generate(findCap);
            for j := 0 to treeCnt[1] - 1 do
              with tree[j] do
                if mFrom = selN then
                  if mTo = N then
                    if (capIndex = 0) or (capIndex = mCapIndex) then
                    begin
                      {MAKE MOVE AND INSERT TO GAME-LIST}
                      MakeMove(tree[j]);
                      side := opSide[side];
                      xside := opSide[xside];
                      game_list[game_cnt] := tree[j];
                      inc(game_cnt);
                      game_max := game_cnt;
                      fillchar(sel, sizeof(sel), 0);
                      ShowPos;
                      if side = sideMachin then
                        Go;
                      break;
                    end;
          end;
        end;

    end; {main loop}

    CloseGraph;
  end;

end.
