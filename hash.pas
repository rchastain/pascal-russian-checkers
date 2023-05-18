unit hash;

interface

const
  HSIZE = 1 shl 11;
  H_EMPTY = 0;
  H_ALPHA = 1;
  H_EXACT = 2;
  H_BETA = 3;
type
  TKey = record
    key0, key1: LongInt;
  end;
  THItem = record
    hKey: TKey;
    hScore: integer;
    hDepth, hFlag: byte;
    hMoveIndex: integer;
  end;
  PHItem = ^THItem;
  THTable = array[0..1, 0..HSIZE - 1] of THItem;

procedure HashInit;
procedure HashClear;
procedure HashInsert(score, depth, color, flag, move_index: integer);
procedure HashStep(c, p, sq: integer);
function HashLook(color: integer): PHItem;

var
  key: TKey;
implementation
const
  c_max = 1;
  p_max = 1;
  sq_max = 127;
var
  randTable: array[0..c_max, 0..p_max, 0..sq_max] of TKey;
  hashTable: ^THTable;

procedure HashInit;
var
  c, p, sq: integer;
begin
  randomize;
  for c := 0 to c_max do
    for p := 0 to p_max do
      for sq := 0 to sq_max do
        with randTable[c, p, sq] do
        begin
          Key0 := (LongInt(random($FFFF)) shl 31) xor (LongInt(random($FFFF)) shl 15) xor LongInt(random($FFFF));
          Key1 := (LongInt(random($FFFF)) shl 31) xor (LongInt(random($FFFF)) shl 15) xor LongInt(random($FFFF));
        end;
  key.key0 := 0;
  key.key1 := 0;
  if hashTable = nil then
    GetMem(hashTable, sizeof(THTable));
end;

procedure HashClear;
begin
  fillchar(hashTable^, sizeof(THTable), 0);
end;

procedure HashInsert(score, depth, color, flag, move_index: integer);
begin
  with hashTable^[color, key.key0 and (HSIZE - 1)] do
    if hDepth <= depth then
    begin
      hScore := score;
      hFlag := flag;
      hDepth := depth;
      hKey := key;
      hMoveIndex := move_index;
    end;
end;

function HashLook(color: integer): PHItem;
begin
  HashLook := @hashTable^[color, key.key0 and (HSIZE - 1)];
end;

procedure HashStep(c, p, sq: integer);
begin
  with randTable[c, p, sq] do
  begin
    key.key0 := key.key0 xor key0;
    key.key1 := key.key1 xor key1;
  end;
end;

end.
