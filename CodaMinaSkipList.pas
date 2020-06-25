{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaSkipList;

interface
{$mode ObjFPC}{$H+}

const
  MaxLevel=20; 
  inf=MaxInt;

type
  generic TCodaMinaSkipList<TValue>=class
  type 
    Snode=^Skiptype;
    Skiptype=record
      key:Integer;
      value:TValue;
      next:array[1..MaxLevel] of Snode;
    end;
    Listtype=record
      level:integer;
      header,tail:Snode;
    end;
  private
    List : Listtype; 
    emptyNode : Skiptype; 
    //update : array[1..MaxLevel] of Snode; 

    function RandomLevel() : integer; 

  public
    property GetList : Listtype read List write List; 

    function Search(key : Integer; var res : TValue) : boolean; 
    procedure Insert(key : Integer; value : TValue); 
    procedure Remove(key : Integer); 

    constructor Create();
end;

implementation

constructor TCodaMinaSkipList.Create();
var
  i:integer;
begin
  
  fillchar(Emptynode,sizeof(Emptynode),0);
  List.level:=1;
  Randomize;
  
  new(List.header);
  List.header^:=Emptynode;
  List.header^.key:=-inf;

  new(List.tail);
  List.tail^:=Emptynode;
  List.tail^.key:=inf;

  for i:=1 to MaxLevel do
    List.header^.next[i]:=List.tail;

  //for i:=1 to MaxLevel do
  //  update[i]:=List.header;
end;

function TCodaMinaSkipList.RandomLevel : integer;
var
  lev : integer;
begin
  lev := 1;
  while random < 0.5 do lev := lev + 1;
  result := lev;
end;

function TCodaMinaSkipList.Search(key : Integer; var res : TValue) : boolean;
var
  x:Snode;
  i:integer;
begin
  x:=List.header;

  for i:=List.level downto 1 do
  begin
    while x^.next[i]^.key < key do
      x:=x^.next[i];
  end;

  x:=x^.next[1];
  if x^.key=key then
  begin
    res := x^.value;
    result := true
  end
  else
   result := false;
end;

Procedure TCodaMinaSkipList.Insert(key : Integer; value : TValue);
var
  x:Snode;
  lvl, i : integer;
  update : array[1..MaxLevel] of Snode;
begin
  x:=List.header;

  for i := List.level downto 1 do
  begin
    while x^.next[i]^.key < key do
       x := x^.next[i];
    update[i] := x;
  end;

  if x^.next[1]^.key = key then
  begin
    x:=x^.next[1];
    x^.value:= value;
  end 
  else
  begin

    lvl := RandomLevel;
    if lvl > List.level then 
    begin
      for i := List.level + 1 to lvl do
        update[i] := List.header;
      List.level := lvl;
    end;

    new(x);
    x^ := Emptynode;
    x^.key := key;
    x^.value := value;

    for i:=1 to lvl do 
    begin
      x^.next[i] := update[i]^.next[i];
      update[i]^.next[i] := x;
    end;
  end;
end;

Procedure TCodaMinaSkipList.Remove(key : Integer);
var
  x:Snode;
  i:integer;
  update:array[1..MaxLevel] of Snode;
begin
  x:=List.header;

  for i:=List.level downto 1 do 
  begin
    while x^.next[i]^.key<key do x:=x^.next[i];
    update[i]:=x;
  end;

  if x^.next[1]^.key = key then 
  begin
    x:=x^.next[1];
    for i:=1 to List.level do 
    begin
      if update[i]^.next[i]^.key <> key then break;
      update[i]^.next[i]:=x^.next[i];
    end;
    dispose(x);

    while (List.level > 1) and (List.header^.next[List.level] = List.tail) do
      dec(List.level);
  end;
end;

end.
