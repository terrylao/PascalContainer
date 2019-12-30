{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaHashMap;
interface
uses murmur3,math;

const 

  DEFAULT_INITIAL_CAPACITY = 16;
  MAXIMUM_CAPACITY = 1 shl 30;
  DEFAULT_LOAD_FACTOR = 0.75;
  TREEIFY_THRESHOLD = 8;
  UNTREEIFY_THRESHOLD = 6;
  MIN_TREEIFY_CAPACITY = 64;
type

     generic TCodaMinaHashMap<TKey, TValue>=class
    
    type
      PhashNode=^THashNode;
      THashNode=record
        hash:Integer;
        K:Tkey;
        V:Tvalue;
        next:PhashNode;
      end;
      TNodelist=array of pHashNode;
    private
    table:TNodelist;
    size:integer;
    modCount:integer;
    threshold:integer;
    loadFactor:double;
    protected
     function GetValue(const Key:TKey):TValue;
     procedure SetValue(const Key:TKey;const Value:TValue);
    public
      function    gethashvalue(key:Tkey):integer;
      function    tableSizeFor(cap:integer):integer;
      constructor Create(initialCapacity:integer;aloadFactor:double);
      constructor Create(initialCapacity:integer);
      constructor Create();
      function    getsize():integer;
      function    isEmpty():boolean;
      function    TryGetValue(const Key:TKey;out v:TValue):boolean;
      function    get(K:Tkey):TValue;
      function    getNode(hash:integer; key:TKey):phashnode;
      function    containsKey(key:Tkey):boolean;
      function    put(K:Tkey; V:Tvalue):Tvalue;
      function    putVal(hash:integer; Key:Tkey; value:Tvalue; onlyIfAbsent,evict:boolean):TValue;
      procedure    resize();
      function    remove(key:TKey):TValue;
      function    removeNode(hash:integer;key:TKey;value:TValue;matchValue,movable:boolean):phashnode;
      function    containsValue( value:Tvalue):boolean;
      function    getloadFactor():double;
      function    newNode(hash:integer; Key:Tkey;value:Tvalue; next:phashnode):phashnode;
      procedure   clear();
      function    capacity():integer;
      procedure  add(const Key:TKey;const Value:TValue);
      property Values[const Key:TKey]:TValue read GetValue write SetValue; default;
    end;
implementation
    function TCodaMinaHashMap.gethashvalue(key:Tkey):integer;
    var
      data:pbyte;
      pcrd:pcardinal;
      len:cardinal;
    begin
      if TypeInfo(key) = TypeInfo(string) then
      begin
        ////writeln('it is string!!');
        data:=pbyte(key);
        pcrd:=@data[-8];
        len  := pcrd[0];
      end
      else
      begin
        len  := sizeof(TKey);
        data := @key;
      end;
      result:=MurmurHash3_x86_32(data,len,17943);//120ms
      if result<0 then
      begin
        result:=result*-1;
      end;
      result:=result xor (result shr 16);
      //
    end;

    function TCodaMinaHashMap.tableSizeFor(cap:integer):integer;
    var
      n:integer;
    begin
      n := cap - 1;
      n :=n or  (n shr 1 );
      n :=n or  (n shr 2 );
      n :=n or  (n shr 4 );
      n :=n or  (n shr 8 );
      n :=n or  (n shr 16);
      if n<0 then
      result:= 1 
      else
      if n >= MAXIMUM_CAPACITY   then
      result:=MAXIMUM_CAPACITY
      else
      result := n + 1;
    end;

    constructor TCodaMinaHashMap.Create(initialCapacity:integer;aloadFactor:double);
    begin
        if (initialCapacity < 0) then
            initialCapacity := DEFAULT_INITIAL_CAPACITY;
        if (initialCapacity > MAXIMUM_CAPACITY) then
            initialCapacity := MAXIMUM_CAPACITY;
        if (loadFactor <= 0) or (isNaN(loadFactor)) then
          loadFactor := DEFAULT_LOAD_FACTOR
        else
          loadFactor := aloadFactor;
        threshold := tableSizeFor(initialCapacity);
    end;

    constructor TCodaMinaHashMap.Create(initialCapacity:integer);
    begin
      Create(initialCapacity, DEFAULT_LOAD_FACTOR);
    end;

    constructor TCodaMinaHashMap.Create();
    begin
      loadFactor := DEFAULT_LOAD_FACTOR; // all other fields defaulted
      threshold := tableSizeFor(DEFAULT_INITIAL_CAPACITY);
      Create(DEFAULT_INITIAL_CAPACITY, DEFAULT_LOAD_FACTOR);
    end;

    function TCodaMinaHashMap.getsize():integer;
    begin
        result := size;
    end;

    function TCodaMinaHashMap.isEmpty():boolean;
    begin
      result:=false;
      if size=0 then
        result:=true;
    end;

    function TCodaMinaHashMap.get(K:Tkey):TValue;
    var
      e:phashNode;
    begin
      e := getNode(gethashvalue(k), k);
      if e=nil then
        exit(default(TVALUE));
      result:=e^.V;
    end;
    function TCodaMinaHashMap.TryGetValue(const Key:TKey;out v:TValue):boolean;
    begin
      v:=get(Key);
      if v<>default(TValue) then
        result:=true
      else
        result:=false;
    end;
    function TCodaMinaHashMap.GetValue(const Key:TKey):TValue;
    begin
        result:=get(Key);
    end;
    procedure TCodaMinaHashMap.SetValue(const Key:TKey;const Value:TValue);
    begin
        put(Key, Value);
    end;
    procedure TCodaMinaHashMap.add(const Key:TKey;const Value:TValue);
    begin
        put(Key, Value);
    end;

    function TCodaMinaHashMap.getNode(hash:integer; key:TKey):phashnode;
    var
      first,e:phashnode;
      n:integer;
    begin
      n := length(table);
      if n>0 then
      begin
        first := table[(n - 1) and hash];
        if first<> nil then
        begin
          if (first^.hash = hash) then // always check first node
          begin
            if first^.K=key then
            begin
              exit(first);
            end;
          end;
          e := first^.next;
          if (e <> nil) then 
          begin
            repeat 
              if (e^.hash = hash) then
              begin
                if (e^.K = key) then
                begin
                  exit(e);
                end;
              end;
              e := e^.next;
            until (e = nil);
          end;
        end;
      end;
      result := nil;
    end;
    function TCodaMinaHashMap.containsKey(key:Tkey):boolean;
    begin
        result:=false;
        if  (getNode(gethashvalue(key), key) <> nil) then
          result:=true;
    end;

    function TCodaMinaHashMap.put(K:Tkey; V:Tvalue):Tvalue;
    begin
        result:=putVal(gethashvalue(k), k, v, false, true);
    end;

    function TCodaMinaHashMap.putVal(hash:integer; Key:Tkey; value:Tvalue; onlyIfAbsent,evict:boolean):TValue;
    var
      p,e:phashnode;
      n,i,binCount:integer;
      K:TKEY;
      oldValue:TValue;
    begin
      if length(table)=0 then
      begin
        resize();
      end;
      n:=length(table);
      i := ((n - 1)  and hash) ;
      p := table[ i];
      if p=nil then
      begin
        table[i] := newNode(hash, key, value, nil);
      end
      else
      begin
        k := p^.k;
        if (p^.hash = hash) and (k=key) then
        begin
            e := p;
        end
        else
        begin
          binCount := 0;
          while (true) do
          begin
            e := p^.next;
            if (e = nil) then
            begin
              p^.next := newNode(hash, key, value, nil);
              break;
            end;
            if (e^.hash = hash) then
            begin
              k := e^.k;
              if (k = key) then
                break;
            end;
            p := e;
            binCount:=binCount+1;
          end;
        end;
        if (e <> nil) then
        begin // existing mapping for key
          oldValue := e^.v;
          if (onlyIfAbsent=false)  or  (oldValue = default(TValue)) then
          begin
              e^.v := value;
          end;
          exit(oldValue);
        end;
      end;
      modCount:=modCount+1;
      size:=size+1;
      if (size > threshold) then
          resize();
      result := default(TValue);
    end;

    procedure TCodaMinaHashMap.resize();
    var
      oldTab:TNodelist;
      j, oldCap,oldThr,newCap,newThr:integer;
      ft:double;
      e,loHead,loTail,hiHead,hiTail,next:phashnode;
    begin
      oldTab := table;
      oldCap := length(oldTab);
      oldThr := threshold;
      newThr := 0;
      if (oldCap > 0) then
      begin
        if (oldCap >= MAXIMUM_CAPACITY) then
        begin
          threshold := MAXINT;
          exit;
        end
        else 
        begin
          newCap := oldCap shl 1;
          if (newCap  < MAXIMUM_CAPACITY) and (oldCap >= DEFAULT_INITIAL_CAPACITY) then
            newThr := oldThr shl 1; // double threshold
        end;
      end
      else 
      if (oldThr > 0) then// initial capacity was placed in threshold
      begin
          newCap := oldThr;
      end
      else
      begin               // zero initial threshold signifies using defaults
          newCap := DEFAULT_INITIAL_CAPACITY;
          newThr := integer(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
      end;
      if (newThr = 0) then
      begin
        ft     := double(newCap * loadFactor);
        if (newCap < MAXIMUM_CAPACITY) and (ft < double(MAXIMUM_CAPACITY)) then
        begin
          newThr := round(ft);
        end
        else
        begin
          newThr := MAXINT ;
        end;
      end;
      threshold := newThr;
      table:=nil;
      SetLength(table,newCap);
      if (oldCap > 0) then
      begin
        j := 0;
        while (j < oldCap) do
        begin
          e := oldTab[j];
          if (e <> nil) then
          begin
            oldTab[j] := nil;
            if (e^.next = nil) then
            begin
              table[((newCap - 1) and e^.hash)] := e;
            end
            else 
            begin // preserve order
              loHead := nil;
              loTail := nil;
              hiHead := nil;
              hiTail := nil;
              repeat
                next := e^.next;
                if ((e^.hash and oldCap) = 0) then
                begin
                  if (loTail = nil) then
                  begin
                    loHead := e;
                  end
                  else
                  begin
                    loTail^.next := e;
                  end;
                  loTail := e;
                end
                else
                begin
                  if (hiTail = nil) then
                  begin
                    hiHead := e;
                  end
                  else
                  begin
                    hiTail^.next := e;
                  end;
                  hiTail := e;
                end;
                e := next;
              until (e = nil);
              if (loTail <> nil) then
              begin
                loTail^.next := nil;
                table[j] := loHead;
              end;
              if (hiTail <> nil) then
              begin
                hiTail^.next := nil;
                table[j + oldCap] := hiHead;
              end;
            end;
          end;
          j:=j+1;
        end;
      end;
      SetLength(oldTab,0);
    end;

    function TCodaMinaHashMap.remove(key:TKey):TValue;
    var
      e:phashnode;
    begin
      result := default(TValue);
      e:= removeNode(gethashvalue(key), key, default(Tvalue), false, true);
      if e <> nil then
        result:=e^.v;
    end;

    function TCodaMinaHashMap.removeNode(hash:integer;key:TKey;value:TValue;matchValue,movable:boolean):phashnode;
    var
      tab:TNodeList;
      p,node,e:phashnode;
      n, index:integer;
      k:TKey;
      v:TValue;
    begin
      tab := table;
      if (tab <> nil) then
      begin
        n := length(tab);
        if n > 0 then
        begin
          index := (n - 1);
          p := tab[ index and hash];
          if (p <> nil) then
          begin
            node := nil;
            if (p^.hash = hash) then
            begin
              k := p^.k;
              if (k = key) then
                node := p;
            end;
            
            if node=nil then
            begin
              e := p^.next;
              if ( e <> nil) then
              begin
                repeat
                  if (e^.hash = hash) then
                  begin
                    k := e^.k;
                    if k=key then
                    begin
                        node := e;
                        break;
                    end;
                  end;
                  p := e;
                  e := e^.next;
                until (e = nil);
              end;
            end;
            if (node <> nil) then
            begin
              v := node^.v;
              if (matchValue=false) or  (v = value) then
              begin
                if (node = p) then
                begin
                    tab[index] := node^.next;
                end
                else
                begin
                    p^.next := node^.next;
                end;
                modCount:=modCount+1;
                size:=size-1;
                exit(node);
              end;
            end;
          end;
        end;
      end;
      result := nil;
    end;
    procedure TCodaMinaHashMap.clear();
    var
      tab:TNodeList;
      i:integer;
    begin
      modCount:=modCount+1;
      tab := table;
      if (tab <> nil) and (size > 0) then
      begin
        size := 0;
        for i := 0 to length(tab)-1 do
          tab[i] := nil;
      end;
    end;

    function  TCodaMinaHashMap.containsValue( value:Tvalue):boolean;
    var
      tab:TNodeList;
      v:TValue;
      i:integer;
      e:phashnode;
    begin
      tab := table;
      if (tab <> nil) and (size > 0) then
      begin
        for i := 0 to  length(tab)-1 do
        begin
          e := tab[i];
          while e<>nil do
          begin
            v := e^.v;
            if (v = value) then
              exit(true);
            e := e^.next;
          end;
        end;
      end;
      result:=false;
    end;

    function TCodaMinaHashMap.getloadFactor():double;
    begin
       result:=loadFactor;
    end;
    function TCodaMinaHashMap.capacity():integer;
    begin
      if table<> nil then
        result:=length(table)
      else
      if (threshold > 0) then
        result:=threshold
      else
        result:=DEFAULT_INITIAL_CAPACITY;
    end;

    function TCodaMinaHashMap.newNode(hash:integer; Key:Tkey;value:Tvalue; next:phashnode):phashnode;
    var
      p:phashnode;
    begin
      p:=new(phashnode);
      p^.hash := hash;
      p^.K:=key;
      p^.V:=value;
      p^.next:=next;
      result := p;
    end;
end.
