{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaLockFreeHashMap;
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
interface
uses murmur3,math,SyncObjs,sysutils;

const 
  DEFAULT_INITIAL_CAPACITY = 16;
  MAXIMUM_CAPACITY = 1 shl 30;
  DEFAULT_LOAD_FACTOR = 0.75;
  TREEIFY_THRESHOLD = 8;
  UNTREEIFY_THRESHOLD = 6;
  MIN_TREEIFY_CAPACITY = 64;
type
      
    generic TCodaMinaLockFreeHashMap<TKey, TValue>=class

    type
      TClearFunc = procedure (AValue: TValue);
      PKeyPair=^TkeyPair;
      TkeyPair=record
        K:TKEY;
        V:TValue;
      end;
      PhashNode=^THashNode;
      THashNode=record
        hash:UInt32;
        K:Tkey;
        V:Tvalue;
        next:PhashNode;
      end;
      TNodelist=^PHashNode;
      THashIterator = record
    		type
     	    ahashmap=specialize TCodaMinaLockFreeHashMap<TKey,TValue>;	 
        private
          FHash: ahashmap;
          FCurrent: ahashmap.PkeyPair;
    			globalindex:INTEGER;
    			globalPhashNode:ahashmap.PhashNode;
        public 
          function Next: Boolean;
    			procedure Reset;
          property Current: ahashmap.PkeyPair read FCurrent;
      end;
    private
    table:TNodelist;
    size:UInt32;
    modCount:UInt32;
    threshold:UInt32;
    loadFactor:double;
		oldCap,newCap,globalj,currentcapacity:UInt32;
    resizing,freememowner:UInt32;
		oldTab:TNodelist;
    protected
      globalindex:INTEGER;
      globalPhashNode,freelist:PhashNode;
      Scavenger:TClearFunc;
      function GetValue(const Key:TKey):TValue;
      procedure SetValue(const Key:TKey;const Value:TValue);
      function    newNode(hash:UInt32; Key:Tkey;value:Tvalue; next:phashnode):phashnode;
      procedure   freeNode(p:phashnode);
      function    putVal(hash:UInt32; Key:Tkey; value:Tvalue; onlyIfAbsent,evict:boolean):TValue;
      procedure reCalcSize();
			procedure relocatechunks();
      function    getNode(hash:UInt32; key:TKey):phashnode;
      function    removeNode(hash:UInt32;key:TKey;value:TValue;matchValue,movable:boolean):phashnode;
      function    tableSizeFor(cap:UInt32):UInt32;
			function loopNext(k:PKeyPair;var startindex:integer;var startphash:PhashNode):boolean;
    public
      resizecount,collisioncount,slotcount:UInt32;
      binoccupied,slotoccupied,longestBinCount:Uint32;

      function    gethashvalue(key:Tkey):UInt32;
      
      constructor Create(initialCapacity:Int32;aloadFactor:double;lScavenger:TClearFunc=nil);
      constructor Create(initialCapacity:Int32;lScavenger:TClearFunc=nil);
      constructor Create(lScavenger:TClearFunc=nil);
      function    getsize():UInt32;
      function    isEmpty():boolean;
      function    TryGetValue(const Key:TKey;out v:TValue):boolean;
      function    get(K:Tkey):TValue;
      
      function    containsKey(key:Tkey):boolean;
      function    put(K:Tkey; V:Tvalue):Tvalue;

      function    remove(key:TKey):TValue;
      
      function    containsValue( value:Tvalue):boolean;
      function    getloadFactor():double;
      procedure   clear();
      function    capacity():UInt32;
      procedure  add(const Key:TKey;const Value:TValue);
      destructor destroy();override;
			function GetIterator: THashIterator;
      function getAvgBinCount():Uint32;
			function GetCollisionRatio():double;
      property Values[const Key:TKey]:TValue read GetValue write SetValue; default;
      property Count:UInt32 read size;
			property Slots:UInt32 read capacity;
    end;
implementation
    function TCodaMinaLockFreeHashMap.THashIterator.Next: Boolean;
    begin
      Result := FHash.loopNext(FCurrent,globalindex,globalPhashNode);
    end;

    procedure TCodaMinaLockFreeHashMap.THashIterator.Reset;
		begin
       globalindex:=0;
       globalPhashNode:=nil;
		end;
		
    function TCodaMinaLockFreeHashMap.GetIterator: THashIterator;
    begin
      Result.FHash:=self;
      Result.reset();
    end;
    function TCodaMinaLockFreeHashMap.gethashvalue(key:Tkey):UInt32;
    var
      data:pbyte;
      pcrd:pcardinal;
      len:cardinal;
    begin
      if TypeInfo(key) = TypeInfo(string) then
      begin
        len:=length(pstring(@key)^);
        data:=pbyte(key);
      end
      else
      begin
        len  := sizeof(TKey);
        data := @key;
      end;
      result:=MurmurHash3_x86_32(data,len,17943);
      result:=result xor (result shr 16);
      //
    end;
    function TCodaMinaLockFreeHashMap.tableSizeFor(cap:UInt32):UInt32;
    var
      n:Int32;
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

    constructor TCodaMinaLockFreeHashMap.Create(initialCapacity:Int32;aloadFactor:double;lScavenger:TClearFunc);
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
        currentcapacity:=0;
        binoccupied:=0;
        resizecount:=0;
        longestBinCount:=0;
        slotoccupied:=0;
				freelist:=nil;
				resizing:=0;
        Scavenger:=lScavenger;
    end;
    constructor TCodaMinaLockFreeHashMap.Create(initialCapacity:Int32;lScavenger:TClearFunc);
    begin
      Create(initialCapacity, DEFAULT_LOAD_FACTOR,lScavenger);
    end;

    constructor TCodaMinaLockFreeHashMap.Create(lScavenger:TClearFunc=nil);
    begin
      loadFactor := DEFAULT_LOAD_FACTOR; // all other fields defaulted
      threshold := tableSizeFor(DEFAULT_INITIAL_CAPACITY);
      Create(DEFAULT_INITIAL_CAPACITY, DEFAULT_LOAD_FACTOR,lScavenger);
      freelist:=nil;
    end;

    function TCodaMinaLockFreeHashMap.getsize():UInt32;
    begin
        result := size;
    end;

    function TCodaMinaLockFreeHashMap.isEmpty():boolean;
    begin
      result:=false;
      if size=0 then
        result:=true;
    end;

    function TCodaMinaLockFreeHashMap.get(K:Tkey):TValue;
    var
      e:phashNode;
    begin
      e := getNode(gethashvalue(k), k);
      if e=nil then
      begin
        result:=default(TValue);
      end
      else
      begin
            result:=e^.V;
      end;
    end;
    function TCodaMinaLockFreeHashMap.getAvgBinCount:Uint32;
    begin
      result:=1;
      if binoccupied>0 then
        result:=size div binoccupied;
    end;
    function TCodaMinaLockFreeHashMap.TryGetValue(const Key:TKey;out v:TValue):boolean;
    var
      d:TValue;
    begin
      v:=get(Key);
      d:=default(TValue);
      if (comparemem(@v , @d,sizeof(TValue))) then
        result:=false
      else
        result:=true;
    end;
    function TCodaMinaLockFreeHashMap.GetValue(const Key:TKey):TValue;
    begin
        result:=get(Key);
    end;
    procedure TCodaMinaLockFreeHashMap.SetValue(const Key:TKey;const Value:TValue);
    begin
        put(Key, Value);
    end;
    procedure TCodaMinaLockFreeHashMap.add(const Key:TKey;const Value:TValue);
    begin
        put(Key, Value);
    end;

    function TCodaMinaLockFreeHashMap.getNode(hash:UInt32; key:TKey):phashnode;
    var
      first,e:phashnode;
      n,m:UInt32;
    begin
      n := currentcapacity;
      if n<>0 then
      begin
			  m:=(n - 1) and hash;
        first := table[m];
        if first<> nil then
        begin
          if (first^.hash = hash) then // always check first node
          begin
            if first^.K=key then
            begin
              exit(first);
            end;
          end;
          inc(collisioncount);
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
              inc(collisioncount);
            until (e = nil);
          end;
        end;
      end;
      result := nil;
    end;

    function TCodaMinaLockFreeHashMap.containsKey(key:Tkey):boolean;
    begin
        result:=false;
        if  (getNode(gethashvalue(key), key) <> nil) then
          result:=true;
    end;

    function TCodaMinaLockFreeHashMap.put(K:Tkey; V:Tvalue):Tvalue;
    begin
        result:=putVal(gethashvalue(k), k, v, false, true);
    end;

    function TCodaMinaLockFreeHashMap.putVal(hash:UInt32; Key:Tkey; value:Tvalue; onlyIfAbsent,evict:boolean):TValue;
    var
      p,e,nd:phashnode;
      n,i,binCount:UInt32;
      K:TKEY;
      oldValue,d:TValue;
			ltable:TNodelist;
    begin
      if (currentcapacity=0) or (size > threshold) or (resizing>0) then
      begin
			  if InterlockedCompareExchange(resizing,1,0)=0 then
				begin
				  reCalcSize();
				end;
			  while resizing=1 do
				begin
				  sleep(10);
				end;
				relocateChunks();
				resizing:=0;
      end;
      ltable:=table;
      n:=currentcapacity;
      i := ((n - 1)  and hash) ;
      p := ltable[ i];
			d:=default(TValue);
      if p=nil then
      begin
        ltable[i] := newNode(hash, key, value, nil);
      end
      else
      begin
        k := p^.k;
        if (p^.hash = hash) and (k=key) then
        begin
            e := p;
            slotoccupied:=slotoccupied+1;
        end
        else
        begin
          binCount := 0;
          InterlockedIncrement(collisioncount);
          InterlockedIncrement(binoccupied);
          while (true) do
          begin
            e := p^.next;

            if (e = nil) then
            begin
              nd:=newNode(hash, key, value, nil);
						  while true do
							begin
  							if InterlockedCompareExchange(p^.next,nd,nil)=nil then
  							  break;
							  p := p^.next;
							end;
              break;
            end
            else
            if (e^.hash = hash) then
            begin
              k := e^.k;
              if (k = key) then
                break;
            end;
            p := e;
            InterlockedIncrement(collisioncount);
            InterlockedIncrement(binCount);
          end;
        end;
        if longestBinCount<binCount then
        begin
          longestBinCount:=binCount;
        end;
        if (e <> nil) then
        begin // existing mapping for key
          oldValue := e^.v;
          if (onlyIfAbsent=false)  or  (comparemem(@oldValue , @d,sizeof(TValue))) then
          begin
              e^.v := value;
          end;
          exit(oldValue);
        end;
      end;
			InterlockedIncrement(modCount);
      InterlockedIncrement(size);
      result := default(TValue);
    end;
    procedure TCodaMinaLockFreeHashMap.reCalcSize();
		var
      j, oldThr,newThr:UInt32;
      ft:double;
		begin
		  
      oldTab := table;
      oldCap := currentcapacity;
      oldThr := threshold;
      newThr := 0;
      inc(resizecount);
      collisioncount:=0;
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
          newThr := UInt32(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
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
      table:=AllocMem(sizeof(pHashNode)*newCap);
      slotcount:=newCap;
      currentcapacity:=newCap;
			inc(resizing);
			globalj:=high( uint32 );
			freememowner:=0;
		end;
		procedure TCodaMinaLockFreeHashMap.relocatechunks();
		var
		  j,i:uint32;
		  e,loHead,loTail,hiHead,hiTail,next:phashnode;
		begin
      if (oldCap > 0) then
      begin
			  j:=InterlockedIncrement(globalj);
        while j<oldcap do
		    begin
          e := oldTab[j];
          if (e <> nil) then
          begin
            oldTab[j] := nil;
            if (e^.next = nil) then
            begin
						  i:=((newCap - 1) and e^.hash);
              table[i] := e;
            end
            else 
            begin // preserve order
              loHead := nil;
              loTail := nil;
              hiHead := nil;
              hiTail := nil;
              repeat
                next := e^.next;
                inc(collisioncount);
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
					j:=InterlockedIncrement(globalj);
        end;
      end;
			if InterlockedCompareExchange(freememowner,1,0)=0 then
			begin
				Freemem(oldTab,oldCap*sizeOf(pHashNode));
			end;
		end;

    function TCodaMinaLockFreeHashMap.remove(key:TKey):TValue;
    var
      e:phashnode;
    begin
      result := default(TValue);
      e:= removeNode(gethashvalue(key), key, default(Tvalue), false, true);
      if e <> nil then
      begin
        result:=e^.v;
        freeNode(e);
      end;
    end;

    function TCodaMinaLockFreeHashMap.removeNode(hash:UInt32;key:TKey;value:TValue;matchValue,movable:boolean):phashnode;
    var
      tab:TNodeList;
      p,node,e:phashnode;
      n, index:UInt32;
      k:TKey;
      v:TValue;
    begin
      tab := table;
      if (tab <> nil) then
      begin
        n := currentcapacity;
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
              if (matchValue=false) or  (comparemem(@v , @value,sizeof(TValue))) then
              begin
                if (node = p) then
                begin
                    tab[index] := node^.next;
                end
                else
                begin
                    p^.next := node^.next;
                end;
                InterlockedIncrement(modCount);
                InterlockedDecrement(size);
                exit(node);
              end;
            end;
          end;
        end;
      end;
      result := nil;
    end;

    procedure TCodaMinaLockFreeHashMap.clear();
    var
      tab:TNodeList;
      p,n:phashnode;
      i:UInt32;
    begin
      InterlockedIncrement(modCount);
      tab := table;
      if (tab <> nil) and (size > 0) then
      begin
        size := 0;
        for i := 0 to currentcapacity-1 do
        begin
          if tab[i] <> nil then
          begin
            p:=tab[i]^.next;
						n:=p;
            while (n<>nil) do
            begin
						  n:=p^.next;
              freeNode(p);
              p:=n;
            end;
            freeNode(tab[i]);
          end;
          tab[i] := nil;
        end;
      end;
    end;
    destructor TCodaMinaLockFreeHashMap.destroy();
    var
      p:phashnode;
    begin
      clear();
      while freelist<>nil do
      begin
        p:=freelist;
        freelist:=freelist^.next;
        dispose(p);
      end;
      freemem(table);
			inherited;
    end;

    function TCodaMinaLockFreeHashMap.loopNext(k:PKeyPair;var startindex:integer;var startphash:PhashNode):boolean;
    var
      tab:TNodeList;
      i:UInt32;
    begin
      tab := table;
      result:=false;
      if (tab <> nil) and (size > 0) then
      begin
        for i := startindex to currentcapacity-1 do
        begin
          if tab[i] <> nil then
          begin
            if startphash=nil then
            begin
              k^.K:=tab[i]^.K;
              k^.V:=tab[i]^.V;
              startphash:=tab[i]^.next;
              if startphash=nil then
                 startindex:=i+1
              else
                  startindex:=i;
              result:=true;
              exit;
            end
            else
            begin
              k^.K:=startphash^.K;
              k^.V:=startphash^.V;
              startphash:=startphash^.next;
              if startphash=nil then
	              startindex:=startindex+1;
              result:=true;
              exit;
            end;
          end;
        end;
      end;
    end;
    
    function  TCodaMinaLockFreeHashMap.containsValue( value:Tvalue):boolean;
    var
      tab:TNodeList;
      v:TValue;
      i:UInt32;
      e:phashnode;
    begin
      tab := table;
      if (tab <> nil) and (size > 0) then
      begin
        for i := 0 to  currentcapacity-1 do
        begin
          e := tab[i];
          while e<>nil do
          begin
            v := e^.v;
            if (comparemem(@v , @value,sizeof(TValue))) then
              exit(true);
            e := e^.next;
          end;
        end;
      end;
      result:=false;
    end;

    function TCodaMinaLockFreeHashMap.getloadFactor():double;
    begin
       result:=loadFactor;
    end;
    function TCodaMinaLockFreeHashMap.capacity():UInt32;
    begin
      if table<> nil then
        result:=currentcapacity
      else
      if (threshold > 0) then
        result:=threshold
      else
        result:=DEFAULT_INITIAL_CAPACITY;
    end;
    function TCodaMinaLockFreeHashMap.GetCollisionRatio():double;
    begin
      result:= collisioncount/size;
    end;
    function TCodaMinaLockFreeHashMap.newNode(hash:Uint32; Key:Tkey;value:Tvalue; next:phashnode):phashnode;
    begin
      if freelist<>nil then
      begin
        result:=freelist;
        freelist:=freelist^.next;
      end
      else
      begin
        result := new(phashnode);
      end;
      result^.hash := hash;
      result^.K:=key;
      result^.V:=value;
      result^.next:=next;
    end;
    procedure TCodaMinaLockFreeHashMap.freeNode(p:phashnode);
    begin
      p^.hash:=0;
			if Scavenger<>nil then
			begin
			  Scavenger(p^.V);
			end;
      if freelist<>nil then
      begin
        p^.next:=freelist;
      end
      else
      begin
        p^.next:=nil;
      end;
      freelist:=p;
    end;    
end.
