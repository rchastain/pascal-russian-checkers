
unit history;
interface
uses def;

const
  MAX_HIST = 1000000;
type
  THist = LongInt;
  PHist = ^THist;

var
  histCutVal, histMaxVal: array[white..black] of THist;
  histTable: array[white..black, pawn..king, 0..127] of THist;
procedure HistClear(game_cnt: integer);
procedure HIstWrite(oldAlpha, alpha, beta: integer;
  c: TColor; p: TPiece; sq: TSquare);
procedure HistZerro;

procedure DebugHist(r: boolean);

implementation
const
  debug = false;
  center: array[TSquare] of integer =
  (
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 3, 0, 0, 0, 2, 0, 4, 0,
    0, 3, 0, 3, 0, 2, 0, 4, 0, 0,
    0, 0, 3, 0, 5, 0, 4, 0, 2, 0,
    0, 0, 0, 5, 0, 7, 0, 2, 0, 0,
    0, 0, 2, 0, 7, 0, 5, 0, 0, 0,
    0, 2, 0, 4, 0, 5, 0, 3, 0, 0,
    0, 0, 4, 0, 2, 0, 3, 0, 3, 0,
    0, 4, 0, 2, 0, 0, 0, 3, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    );

function Zoom(val: LongInt): LongInt;
begin
  Zoom := val div 3 * 2;
end;

procedure HistZerro;
var
  c: TColor; p: TPiece; sq: TSquare;
begin
  for c := white to black do
    for p := pawn to king do
      for sq := low(TSquare) to high(TSquare) do
        histTable[c, p, sq] := 0;
end;

procedure HistClear(game_cnt: integer);
var
  c: TColor; p: TPiece; sq: TSquare;
  find: boolean;
begin
  if debug then DebugHist(true);

  randomize;
  if game_cnt < 4 then
  begin {начало игры - приоритет центра}

    for c := white to black do
    begin
      find := false;
      for p := pawn to king do
      begin
        for sq := low(TSquare) to high(TSquare) do
        begin
          histTable[c, p, sq] := random(center[sq] * 2);
        end; {for sq}
      end; {for p}
      histMaxVal[c] := 32;
      histCutVal[c] := 0;
    end; {for c}

  end else
  begin { запомним только лучшие точки предыдущего обдумывания }
    for c := white to black do
    begin
      find := false;
      for p := pawn to king do
      begin
        for sq := low(TSquare) to high(TSquare) do
        begin

          if (histTable[c, p, sq] >= histCutVal[c]) and
            (histCutVal[c] > 0)
            then
            begin
            histTable[c, p, sq] := 2 + random(3);
            find := true;
          end else
            histTable[c, p, sq] := 0;
        end; {for sq}
      end; {for p}

      if find then
      begin
        histMaxVal[c] := 4;
        histCutVal[c] := Zoom(4);
      end else
      begin
        histMaxVal[c] := 0;
        histCutVal[c] := 0;
      end;
    end; {for c}
  end;
  if debug then DebugHist(false);
  {
     fillchar(histTable,sizeof(histTable),0);
     fillchar(histCutVal,sizeof(histCutVal),0);
     fillchar(histMaxVal,sizeof(histMaxVal),0);
  }
end;

procedure HIstWrite(oldAlpha, alpha, beta: integer;
  c: TColor; p: TPiece; sq: TSquare);
var
  ptr: PHist;
begin
  ptr := @histTable[c, p, sq];
  {0002}
  inc(ptr^, 1 + random(2));
  if (alpha > oldAlpha + valueP * 2) then
    inc(ptr^, 2 + random(3));
  if (ptr^ >= MAX_HIST) then
  begin
    for p := pawn to king do
      for sq := low(TSquare) to high(TSquare) do
        histTable[c, p, sq] := histTable[c, p, sq] div 2;

    HistMaxVal[c] := MAX_HIST div 2;
    HistCutVal[c] := Zoom(HistMaxVal[c]);
  end else if ptr^ > HistMaxVal[c] then
  begin

    HistMaxVal[c] := ptr^;
    HistCutVal[c] := Zoom(ptr^);

  end;

end;

procedure DebugHist(r: boolean);
var
  c: TColor;
  p: TPiece;
  x, y: integer;
  f: Text;
begin
  assign(f, 'test');
  if r then
    rewrite(f)
  else
    append(f);

  for c := white to black do
  begin
    for p := pawn to king do
    begin
      for y := 1 to 9 do
      begin
        for x := 1 to 9 do
        begin
          write(f, histTable[c, p, y * 10 + x]: 8);
        end;
        writeln(f);
      end;
      writeln(f);
    end;
    writeln(f);
    writeln(f);
  end;

  close(f);

end;

end.
