unit CodaMinaLockFreeSkipList2;

interface
{$mode ObjFPC}{$H+}
uses
SysUtils, Math;


const
  MaxLevel = 16;    // ~lg(MaxInt)
  p = 0.5;         // 1/4

type

  generic TCodaMinaLockFreeSkipList<TKEY,TValue>=class
  type
    cmp_func=function(key1, key2:TKEY):integer;
    PNode = ^TNode;

    TNode = record
      Key : TKEY;
      Next: array of PNode;
      Data: TValue;
    end;
  private
    FHead, FTail: PNode;
    FLevel : Byte;

    FCurrent: PNode;
    cmpf:cmp_func;
    function MakeNode(lvl:integer;key:TKey; Value: TValue):PNode;
    function RandomLevel: Integer;
    procedure DeleteNode(var x: PNode);
    function GetEOF: Boolean;
  public
    constructor Create(c:cmp_func);
    destructor  Destroy; override;

    procedure Insert(AKey: TKEY;const NewValue: TValue);
    function  Search(Akey: TKEY;var outValue:TValue):boolean;
    procedure Delete(AKey : TKEY);
    procedure First;
    procedure Next;
    function  Value: TValue;
    procedure setCompareFunction(c:cmp_func);
  published
    property EOF: Boolean read GetEOF;
  end;

implementation

{ TCodaMinaLockFreeSkipList }
procedure TCodaMinaLockFreeSkipList.setCompareFunction(c:cmp_func);
begin
  cmpf:=c;
end;
constructor TCodaMinaLockFreeSkipList.Create(c:cmp_func);
var
  i:integer;
begin
  FHead := MakeNode(1, default(TKey),default(TValue));
  FTail := MakeNode(1, default(TKey),default(TValue));
  for i:=0 to MaxLevel-1 do
    FHead^.Next[i] := FTail;
  FLevel  := MaxLevel;
  cmpf:=c;
end;

procedure TCodaMinaLockFreeSkipList.Delete(AKey: TKey);
var
  i: Integer;
  x: PNode;
  Left: array of PNode;
begin
  if cmpf=nil then
    exit;
  SetLength(Left, FLevel);
  x := FHead;
  for I := FLevel - 1 downto 0 do
  begin
    while (High(x^.Next) >= i) and (cmpf(x^.Next[i]^.key , AKey)<0) do
      x := x^.Next[i];
    Left[i] := x;
  end;

  x := x^.Next[0];
  if cmpf(x^.Key,AKey)=0 then
  begin
    for I := 0 to FLevel - 1 do
    begin
      if Left[i]^.Next[i] <> x then Break;
      Left[i]^.next[i] := x^.Next[i];
    end;

    DeleteNode(x);

    while (FLevel > 1) and (FHead^.Next[FLevel - 1] = FTail) do
      Dec(FLevel);
    SetLength(FHead^.Next, FLevel);
  end;
end;

procedure TCodaMinaLockFreeSkipList.DeleteNode(var x: PNode);
begin
  SetLength(x^.next, 0);
  Dispose(x);
end;

procedure TCodaMinaLockFreeSkipList.First;
begin
  FCurrent := FHead^.Next[0];
end;

destructor TCodaMinaLockFreeSkipList.Destroy;
var
  x: PNode;
begin
  First;
  while not GetEof do
  begin
    x := FCurrent;
    Next;
    DeleteNode(x);
  end;
  DeleteNode(FCurrent);
  DeleteNode(FHead);

  inherited Destroy;
end;

function TCodaMinaLockFreeSkipList.GetEOF: Boolean;
begin
  Result := FCurrent^.Key = MaxInt;
end;

procedure TCodaMinaLockFreeSkipList.Insert(AKey: TKey;const NewValue: Tvalue);
var
  i, lvl: Integer;
  x: PNode;
  Left: array of PNode;
begin
  if cmpf=nil then
    exit;
  SetLength(Left, FLevel);
  x := FHead;
  for I := FLevel - 1 downto 0 do
  begin
    while (High(x^.Next) >= i) and (cmpf(x^.Next[i]^.key , AKey)<0) do
      x := x^.Next[i];
    Left[i] := x;
  end;

  x := x^.Next[0];
  if (x<>nil) and (cmpf(x^.Key , AKey)=0) then
     x^.Data := NewValue
  else 
  begin
    lvl := RandomLevel;

    x := MakeNode(lvl, AKey,NewValue);
    x^.Data := NewValue;

    if lvl > FLevel then
    begin
      SetLength(FHead^.Next, lvl);
      SetLength(Left, lvl);
      for I := FLevel + 1 to lvl do
      begin
        FHead^.Next[i - 1] := FTail;
        Left[i - 1] := FHead;
      end;
      FLevel := lvl;
    end;

    for I := 0 to High(x^.Next) do
    begin
      x^.Next[i] := Left[i]^.Next[i];
      Left[i]^.next[i] := x;
    end;
  end;
end;

function TCodaMinaLockFreeSkipList.MakeNode(lvl:integer;key:TKey; Value: TValue):PNode;
var
  i: Integer;
begin
  Result := New(PNode);
  SetLength(Result^.Next, lvl);
  for i:= 0 to lvl - 1 do
    Result^.Next[i] := nil;
  Result^.Key := key;
  Result^.data := Value;
end;

procedure TCodaMinaLockFreeSkipList.Next;
begin
  FCurrent := FCurrent^.Next[0];
end;

function TCodaMinaLockFreeSkipList.RandomLevel: Integer;
begin
  Result := 1;
  while (Random(100)/100 < p) and (Result < MaxLevel) do
    Inc(Result);
end;

function TCodaMinaLockFreeSkipList.Search(Akey: TKEY;var outValue:TValue): boolean;
var
  i: Integer;
  x: PNode;
begin
  if cmpf=nil then
    exit(false);
  x := FHead;
  for I := FLevel - 1 downto 0 do
    while (High(x^.Next) >= i) and (cmpf(x^.Next[i]^.key , AKey)<0) do
      x := x^.Next[i];
  x := x^.Next[0];
  if cmpf(x^.Key , AKey)=0 then
    FCurrent := x
  else
  begin
    FCurrent := nil;
    exit(false);
  end;
  outValue := x^.Data;
  result:=true;
end;

function TCodaMinaLockFreeSkipList.Value: TValue;
begin
  if FCurrent <> nil then
    Result := FCurrent^.Data
  else
    Result := default(TValue);
end;

end.
