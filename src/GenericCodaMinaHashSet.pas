Unit GenericCodaMinaHashSet;
interface
uses mymurmur3;
const prime_1 = 73;
 prime_2 = 5009;

type
  generic TCodaMinaHashSet<T>=class
    private
      caps2,mask,capacity,nitems,n_deleted_items,curIndex:integer;
      items:array of uInt32;
      values:array of T;
      procedure rehash();
      function add(value:uint32;item:T):boolean;
      function calcHash(key:T):uint32;
    public
      function contain(item:T):boolean;
      function remove(item:T):boolean;
      function add(item:T):boolean;
      destructor destroy;
      function itemsCount():Integer;
      constructor create(caps:integer);
      procedure startIterate();
      function IterateNext(var a:T):boolean;
      procedure IntersectWith(aset:TCodaMinaHashSet);
      procedure UnionWith(aset:TCodaMinaHashSet);
      function Overlaps(aset:TCodaMinaHashSet):boolean;
      function SetEquals(aset:TCodaMinaHashSet):boolean;
      function IsSupersetOf(aset:TCodaMinaHashSet):boolean;
      function IsSubsetOf(aset:TCodaMinaHashSet):boolean;
  end;
implementation
constructor TCodaMinaHashSet.create(caps:integer);
begin
  caps2    := 0;
  while caps>0 do
  begin
    caps:=caps shr 1;
    inc(caps2);
  end;
  capacity := (1 shl caps2);
  mask     := capacity - 1;
  setlength(items,capacity);
  setlength(values,capacity);
  nitems   := 0;
  n_deleted_items := 0;
end;
procedure TCodaMinaHashSet.startIterate();
begin
  curIndex:=-1;
end;
function TCodaMinaHashSet.IterateNext(var a:T):boolean;
begin
  inc(curIndex);
  while (curIndex<length(items)) do
  begin
    if (items[curIndex] > 0) then
      break;
    inc(curIndex);
  end;
  if (curIndex<length(items)) then
  begin
    a:=values[curIndex];
    result:=true;
  end
  else
  begin
    result:=false;
  end;
end;
function TCodaMinaHashSet.itemsCount():Integer;
begin
  result := nitems;
end;
procedure TCodaMinaHashSet.IntersectWith(aset:TCodaMinaHashSet);
var
  s:T;
begin
  startIterate();
  while IterateNext(s) do
  begin
    if not aset.contain(s) then
    begin
      remove(s);
    end;
  end;
end;
procedure TCodaMinaHashSet.UnionWith(aset:TCodaMinaHashSet);
var
  s:T;
begin
  aset.startIterate();
  while aset.IterateNext(s) do
  begin
    add(s);
  end;
end;
function TCodaMinaHashSet.IsSubsetOf(aset:TCodaMinaHashSet):boolean;
var
  s:T;
begin
  if aset.itemsCount()<itemsCount() then
    exit(false);
  startIterate();
  while IterateNext(s) do
  begin
    if not aset.contain(s) then
      exit(false);
  end;
  result:=true;
end;
function TCodaMinaHashSet.IsSupersetOf(aset:TCodaMinaHashSet):boolean;
var
  s:T;
begin
  if aset.itemsCount()>itemsCount() then
    exit(false);
  aset.startIterate();
  while aset.IterateNext(s) do
  begin
    if not contain(s) then
      exit(false);
  end;
  result:=true;
end;
function TCodaMinaHashSet.SetEquals(aset:TCodaMinaHashSet):boolean;
var
  s:T;
begin
  if aset.itemsCount()<>itemsCount() then
    exit(false);
  aset.startIterate();
  while aset.IterateNext(s) do
  begin
    if not contain(s) then
      exit(false);
  end;
  result:=true;
end;
function TCodaMinaHashSet.Overlaps(aset:TCodaMinaHashSet):boolean;
var
  s:T;
begin
  if aset.itemsCount()<itemsCount() then
  begin
    startIterate();
    while IterateNext(s) do
    begin
      if aset.contain(s) then
        exit(true);
    end;
  end
  else
  begin
    aset.startIterate();
    while aset.IterateNext(s) do
    begin
      if contain(s) then
        exit(true);
    end;
  end;
  result:=false;
end;
destructor TCodaMinaHashSet.destroy;
begin
  inherited destroy;
  setlength(items,0);
  setlength(values,0);
end;
function TCodaMinaHashSet.calcHash(key:T):uint32;
var
  data:pbyte;
  pcrd:pUint32;
  len:Uint32;
begin
  if TypeInfo(key) = TypeInfo(string) then
  begin
   len:=length(pstring(@key)^);
   data:=pbyte(key);
  end
  else
  begin
    len  := sizeof(T);
    data := @key;
  end;
  result :=MurmurHash3_x86_32(data,len,17943);
end;
function TCodaMinaHashSet.add(item:T):boolean;
begin
  result := add(calcHash(item),item);
end;
function TCodaMinaHashSet.add(value:Uint32;item:T):boolean;
var
  ii:integer;
begin
  ii   := mask and (prime_1 * value);
  rehash();
  while (items[ii] <> 0) and (items[ii] <> -1) do
  begin
    if (items[ii] = value) and (values[ii] = item) then
    begin
      exit(false);
    end
    else 
    begin
          //* search free slot */
      ii := mask and (ii + prime_2);
    end;
  end;
  inc(nitems);
  if (items[ii] = -1) then
  begin
    dec(n_deleted_items);
  end;
  items[ii] := value;
  values[ii]:= item;
  writeln(stdout,item,' at ',ii);
  result := true;
end;

procedure TCodaMinaHashSet.rehash();
var
  old_items:array of uint32;
  old_values:array of T;
  old_capacity,ii:integer;
begin
  if (nitems + n_deleted_items >= round(capacity * 0.85)) then
  begin
    old_items := items;
    old_values:= values;
    old_capacity := capacity;
    capacity := (capacity shl 1);
    mask := capacity - 1;
    setlength(items ,capacity);
    setlength(values,capacity);
    nitems := 0;
    n_deleted_items := 0;
    for ii := 0 to old_capacity-1 do
    begin
      add(old_items[ii],old_values[ii]);
    end;
    setlength(old_items,0);
  end;
end;

function TCodaMinaHashSet.remove(item:T):boolean;
var
  value,ii:integer;
begin
  value := calcHash(item);
  ii := mask and (prime_1 * value);

  while (items[ii] <> 0) do
  begin
    if (items[ii] = value)  and (values[ii] = item) then
    begin
      items[ii] := -1;
      dec(nitems);
      inc(n_deleted_items);
      exit(true);
    end 
    else 
    begin
      ii := mask and (ii + prime_2);
    end;
  end;
  result := false;
end;

function TCodaMinaHashSet.contain(item:T):boolean;
var
  value,ii:integer;
begin
  value := calcHash(item);
  ii    := mask and (prime_1 * value);

  while (items[ii] <> 0) do
  begin
    if (items[ii] = value) then
    begin
      exit(true)
    end
    else
    begin
      ii := mask and (ii + prime_2);
    end;
  end;
  result := false;
end;
end.
