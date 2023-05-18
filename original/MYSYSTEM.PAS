unit mysystem;

interface

function TickCount:LongInt;
procedure delay(ms:word);
procedure sound(freq : real);
procedure nosound;
function IntToStr(I: Longint): String;

implementation


  function IntToStr(I: Longint): String;
    var
       S: string[11];
  begin
      Str(I, S);
      IntToStr := S;
  end;


function TickCount:LongInt;
var
 timer:LongInt absolute $40:$6C;
begin
  TickCount := timer * 1000  div  18;
end;

procedure delay(ms:word);
var
 t0,t1:LongInt;
begin
    t0 := TickCount;
    while true do begin
      t1 := TickCount;
      if t1 < t0 then t0 := t1;
      if t1-t0 >= ms then break;
    end;
end;


procedure sound(freq : real);
const 
        freq0 = 1.19318e6;
var 
        count : word;
        b : byte;
begin
        count := round(freq0/freq);
        b := port[$61];
        if b and $03 = 0 then
        begin
                b := b or $03;
                port[$61] := b;
                port[$43] := $B6;
        end;
        b := Lo(count);
        port[$42] := b;
        b := Hi(count);
        port[$42] := b;
end;

procedure nosound;
var
        x : byte;
begin
        port[$61] := port[$61] and $FC;
end;



end.
