unit CodaMinaArray;
{$mode objfpc}{$H+}
interface
{
  base:basearray[1024] of pint32;
  []->basearray[1024/2048...] of T
  []
  []
  []
  ..
  ..
  Algorithm :概念： 2D 當1D 在用，延申3D 當2D 在用也是可以的
  Ex:1024 for basearr length
  ibase=1,p= idx / 1024, pos=idx % 1024
  add(idx): if base[p]=null then base[p]=new basearr,if p>ibase then ibase=p。 base[p][pos]=T
  get(idx): if base[p]=null then return default(T)。 return base[p][pos]
  size = ibase * 1024
  loop get:  要小於size()
  remove(idx): if base[p]=null then return default(T) else return base[p][pos]
  要刪除全空的 basearr 嗎？ 不主動刪，提供trancate 給使用者想.
  
  自動加大：除第一頁外，其它頁放到AVL-Tree 中
  存的結構：pageRecord
  
  另外：
  create 時只給想要的容量，
  其它的，自己算出最好的分配方式，
  就不要自動加大的功能了。
}
	
type
  generic TCodaMinaAVLTree<T> = class
  type
    Comp_func = function (a, b: T): Integer of object;
		TClearFunc=procedure (value:T) of object;
    PAVLNode = ^TAVLNode;
    TAVLNode = record
      Balance: Integer;
      Data: T;
      Left: PAVLNode;
      Parent: PAVLNode;
      Right: PAVLNode;
    end;
  private
    FCount: Integer;
    Root: PAVLNode;
    cmp: Comp_func;
		Scavenger:TClearFunc;
    freehead,freetail:PAVLNode;
    procedure BalanceAfterDelete(ANode: PAVLNode);
    procedure BalanceAfterInsert(ANode: PAVLNode);
    function FindInsertPos(Data: T): PAVLNode;
    procedure AddNode(ANode: PAVLNode);
    procedure freeNode(x: PAVLNode);
    function NewNode():PAVLNode;
    procedure printTreeNode(n:PAVLNode; offs:integer);
    procedure DeleteNode(ANode: PAVLNode);
    function FindPrecessor(ANode: PAVLNode): PAVLNode;
    function FindSuccessor(ANode: PAVLNode): PAVLNode;
    procedure Delete(ANode: PAVLNode);
    function Find(keyData: T): PAVLNode;
  public
    constructor Create(c: Comp_func;lScavenger:TClearFunc=nil);
    destructor Destroy; override;
    function Add(Data: T): PAVLNode;
    procedure Clear;
    function Find(searchData: T;out returnData:T): boolean;
    procedure Remove(Data: T);
    procedure printTree();
    property Count: Integer read FCount;
  end;
  
	generic TCodaMinaArray<T> = class
    type
		  TClearFunc = procedure (AValue: T);
		  TCreateFunc = function():T;
			PT=^T;
			PPT=^PT;
			pPageRecord=^TPageRecord;
			TPageRecord=record
			  baseIndex:uint32;
			  basearr:PPT;
			  basecount:puint32;//how many elements in basearr[x]
			  elementCount:uint32;//elements in this page
			end;
			avltree=specialize TCodaMinaAVLTree<pPageRecord>;//調整成吃object.method,就可以省去Scavenger
		public
		  
			constructor create(_basesize:uint32=1024;_autoextend:boolean=true;lScavenger:TClearFunc=nil);
			destructor destroy();override;
      function add(idx:uint32;val:T):boolean;
      function get(idx:uint32;out _out:T):boolean;
			function get(idx:uint32):T;
			procedure setVal(idx:uint32;val:T);
			procedure clear();
			function remove(idx:uint32):T;
      procedure truncate();
      function Count():uint32;
      function empty():boolean;
      function size():uint32;
      function capacity():uint32;
      function sparseRatio():double;
      function last():T;
      function append(val:T):boolean;
			procedure appendfrom(source:specialize TCodaMinaArray<T>);
			property items[idx:uint32]:T read get write setVal;default; 
		private
			ibase,basesize:uint32;//ibase=slot count
			currpos:uint32;//current position
			maxpos:uint32;
			basearr:PPT;
			basecount:puint32;//how many elements in basearr[x]
			elementcount:uint32;//total elements of all pages
			pagetree:avltree;
			pagecount:uint32;// when > 0 means pagetree are in use
			autoextend:boolean;
      Scavenger:TClearFunc;
    	function cmpuint(a,b:TCodaMinaArray.pPageRecord):integer;
    	procedure avlscavenger(a:TCodaMinaArray.pPageRecord);
    	
	end;

	
implementation

  function TCodaMinaArray.cmpuint(a,b:pPageRecord):integer;
  begin
    if (a^.baseIndex=b^.baseIndex) then
      exit(0);
    if (a^.baseIndex>b^.baseIndex) then
      exit(1);
    exit(-1);
  end;
  procedure TCodaMinaArray.avlscavenger(a:pPageRecord);
  var
    i,j:integer;
  begin
    for i := 0 to basesize-1 do
    begin
      if a^.basearr[i]<>nil then
      begin
        for j := 0 to basesize-1 do
        begin
          if Scavenger<>nil then
          begin
  				  Scavenger(a^.basearr[i][j]);
  				end;
        end;
        freemem(a^.basearr[i]);
      end;
    end;
		freemem(a^.basearr);
		freemem(a^.basecount);
    freemem(a);
  end;
	constructor TCodaMinaArray.create(_basesize:uint32=1024;_autoextend:boolean=true;lScavenger:TClearFunc=nil);
	begin
	  Scavenger:=lScavenger;
	  ibase:=1;
		currpos:=0;
		maxpos:=0;
		elementcount:=0;
		pagecount:=0;
		autoextend:=_autoextend;
		if autoextend=true then
		begin
		  pagetree:=avltree.create(@cmpuint,@avlscavenger);
		end;
		basesize:=_basesize;
		basearr := allocmem(sizeof(PT)*basesize);
		basecount := allocmem(sizeof(uint32)*basesize);
	end;
	
  destructor TCodaMinaArray.destroy();
  var
    i:integer;
	begin
	  clear();
		for i := 0 to basesize-1 do
      if basearr[i]<>nil then
      begin
        freemem(basearr[i]);
      end;
	  pagetree.free;
		freemem(basearr);
		freemem(basecount);
	end;
	
	function TCodaMinaArray.empty():boolean;
	begin
		result := maxpos = 0;
	end;
	
	function TCodaMinaArray.size():uint32;
	begin
		result := maxpos;
	end;
	
	function TCodaMinaArray.Count():uint32;
	begin
		result := elementcount;
	end;
	
	function TCodaMinaArray.capacity():uint32;
	begin
		result := basesize*basesize;
	end;

  function TCodaMinaArray.sparseRatio():double;
  begin
    result := 0.0;
  end;	
  function TCodaMinaArray.append(val:T):boolean;
  begin
    result := add(currpos,val);
    inc(currpos);
  end;
  procedure TCodaMinaArray.setVal(idx:uint32;val:T);
  begin
    add(idx,val);
  end;
  //after call add(idx,val), if idx the largest than, currpos will change to idx+1.
  //                         if not, so append(val) will append to currpos.
  function TCodaMinaArray.add(idx:uint32;val:T):boolean;
  var
    p,ipos:uint32;
    pr:pPageRecord;
    tr:TPageRecord;
  begin
    p:=idx div basesize;
    ipos:=idx mod basesize;
    result:=true;
    if p>=basesize then
    begin
      if autoextend=false then
        exit(false);
      //data add to extended page
      {
        ex: 10240001, p=102401 div 1024=10000, pos=102401 % 1024=1
        p>1024
        baseindex=p*1024=10240000;
      }
      tr.baseindex:=p*basesize;
      p:=(idx-tr.baseindex) div basesize;
      ipos:=(idx-tr.baseindex) mod basesize;
      if not pagetree.find(@tr,pr) then
      begin
        pagecount:=pagecount+1;
        pr:=allocmem(sizeof(TpageRecord));
        if pr=nil then
          exit(false);
    		pr^.basearr := allocmem(sizeof(PT)*basesize);
        if pr^.basearr=nil then
          exit(false);
    		pr^.basecount := allocmem(sizeof(uint32)*basesize);
        if pr^.basecount=nil then
          exit(false);
        if pr^.basearr[p]=nil then
        begin
          pr^.basearr[p]:=allocmem(sizeof(T)*basesize);
          if pr^.basearr[p]=nil then
            exit(false);
          pr^.basecount[p]:=0;
          ibase:=ibase+1;
        end;
        pr^.baseindex:=tr.baseindex;
        pagetree.add(pr);
      end;
      pr^.basearr[p][ipos]:=val;
      pr^.basecount[p]:=basecount[p]+1;
      pr^.elementcount:=pr^.elementcount+1;
      elementcount:=elementcount+1;
      if idx>maxpos then
      begin
        maxpos:=idx;
      end;
      exit(true);
    end;
    
    if basearr[p]=nil then
    begin
      basearr[p]:=allocmem(sizeof(T)*basesize);
      if basearr[p]=nil then
      begin
        exit(false);
      end;
      basecount[p]:=0;
      ibase:=ibase+1;
    end;
    basearr[p][ipos]:=val;
    basecount[p]:=basecount[p]+1;
    elementcount:=elementcount+1;
    if idx>maxpos then
    begin
      maxpos:=idx;
    end;
  end;

  function TCodaMinaArray.get(idx:uint32;out _out:T):boolean;
  var
    pr:ppagerecord;
    p,ipos:uint32;
    tr:TPageRecord;
	begin
	  p:=idx div basesize;
	  if p >= basesize then
	  begin
	    tr.baseindex:=p*basesize;
	    if not pagetree.find(@tr,pr) then
	    begin
	      exit(false);
	    end;
      p:=(idx-tr.baseindex) div basesize;
      ipos:=(idx-tr.baseindex) mod basesize;
      _out:=pr^.basearr[p][ipos];
	    exit(true);
	  end;
	  result:=false;
	  if basearr[p]=nil then
	  begin
	    exit(false);
	  end;
		if (idx <= maxpos) then
		begin
      ipos:=idx mod basesize;
			_out := basearr[p][ipos];
			result := true;
		end;
	end;

	function TCodaMinaArray.get(idx:uint32):T;
	begin
	  if not get(idx,result) then
	  begin
	    result := default(T);
	  end;
	end;

	function TCodaMinaArray.last():T;
	begin
		result := get(maxpos);
	end;
	//give it back to you, i am not handling the free memory problem.
  function TCodaMinaArray.remove(idx:uint32):T;
  var
    p,ipos:uint32;
    pr:ppagerecord;
    tr:Tpagerecord;
  begin
    p:=idx div basesize;
	  if p > basesize then
	  begin
	    tr.baseindex:=p*basesize;
	    if not pagetree.find(@tr,pr) then
	    begin
	      exit(default(T));
	    end;
      p:=(idx-tr.baseindex) div basesize;
	    if pr^.basecount[p]=0 then
	    begin
	      exit(default(T));
	    end;
      ipos:=(idx-tr.baseindex) mod basesize;
			pr^.basearr[p][ipos]:=default(T);
			pr^.basecount[p]:=basecount[p]-1;
			pr^.elementcount:=pr^.elementcount-1;
			elementcount:=elementcount-1;
	    exit(pr^.basearr[p][ipos]);
	  end;
    result:=default(T);
		if (basecount[p]>0) and (idx < maxpos) then
		begin
      ipos:=idx mod basesize;
      result := basearr[p][ipos];
			basearr[p][ipos]:=default(T);
			basecount[p]:=basecount[p]-1;
			elementcount:=elementcount-1;
		end;    
  end;
  
	procedure TCodaMinaArray.truncate();
  var
    i:integer;
	begin
    for i:=0 to basesize -1 do
    begin
      if basecount[i]=0 then
      begin
        freemem(basearr[i]);
      end;
    end;
    if autoextend then
    begin
      pagetree.free;
      pagetree:=avltree.create(@cmpuint,@avlscavenger);
    end;
	end;

	procedure TCodaMinaArray.clear();
	var
	  i,j:integer;
		tk:TTypeKind;
	begin
	  //https://www.freepascal.org/docs-html/rtl/system/ttypekind.html
	  //tk := GetTypeKind(T);
    //if tk in [tkObject,tkRecord,tkClass,tkDynbasearray,tkPointer] then
		//begin
		  if Scavenger<>nil then
			begin
    		for i := 0 to basesize-1 do
    		 for j := 0 to basesize-1 do
    		 begin
    			  Scavenger(basearr[i][j]);
    			  if basearr[i]<>nil then
    			   basearr[i][j]:=default(T);
         end;
         basecount[i]:=0;
			end
			else
			begin
    		for i := 0 to basesize-1 do
    		 for j := 0 to basesize-1 do
    		 begin
    		   if basearr[i]<>nil then
    			  basearr[i][j]:=default(T);
         end;
         basecount[i]:=0;
			end;
		//end;
		pagetree.clear;
		elementcount:=0;
		maxpos := 0;
		currpos := 0;
		ibase := 0;
	end;
	//一個一個抓，一個一個ADD？
	procedure TCodaMinaArray.appendfrom(source:specialize TCodaMinaArray<T>);
	var
	  i:uint32;
	begin
    for i:=0 to source.size() do
    begin
      append(source.get(i));
    end;
	end;
	
	constructor TCodaMinaAVLTree.Create(c: Comp_func;lScavenger:TClearFunc=nil);
begin
  inherited Create;
  cmp := c;
  FCount := 0;
  Root := nil;
  freehead:=nil;
  freetail:=nil;
	Scavenger:=lScavenger;
end;

destructor TCodaMinaAVLTree.Destroy;
var
  p:PAVLNode;
begin
  Clear;
  p:=freehead;
  while p<>nil do
  begin
    freehead:=freehead^.right;
    dispose(p);
    p:=freehead;
  end;
  inherited Destroy;
end;
procedure TCodaMinaAVLTree.freeNode(x: PAVLNode);
begin
  if x=nil then
     exit;
  x^.parent:=nil;
  x^.left:=nil;
  x^.Balance:=0;
  x^.Right:=nil;
	if Scavenger<>nil then
	begin
	  Scavenger(x^.Data);
	end;
  if freehead=nil then
  begin
    freehead:=x;
  end
  else
  begin
    freetail^.right:=x;
  end;
  freetail:=x;
end;
function TCodaMinaAVLTree.NewNode():PAVLNode;
begin
  if freehead=nil then
  begin
    result:=new(PAVLNode);
    result^.Balance:=0;
    result^.Left:=nil;
    result^.Right:=nil;
    result^.Parent:=nil;
  end
  else
  begin
    result:=freehead;
    freehead:=freehead^.right;
  end;
end;
function TCodaMinaAVLTree.Add(Data: T): PAVLNode;
begin
  Result := NewNode();
  Result^.Data := Data;
  AddNode(Result);
end;

procedure TCodaMinaAVLTree.AddNode(ANode: PAVLNode);
var
  InsertPos: PAVLNode;
  InsertComp: Integer;

  // add a node. If there are already nodes with the same value it will be
  // inserted rightmost

begin
  ANode^.Left := nil;
  ANode^.Right := nil;
  inc(FCount);
  if Root <> nil then
  begin
    InsertPos := FindInsertPos(ANode^.Data);
    InsertComp := cmp(ANode^.Data, InsertPos^.Data);
    ANode^.Parent := InsertPos;
    if InsertComp < 0 then
    begin
      // insert to the left
      InsertPos^.Left := ANode;
    end
    else
    begin
      // insert to the right
      InsertPos^.Right := ANode;
    end;
    BalanceAfterInsert(ANode);
  end
  else
  begin
    Root := ANode;
    ANode^.Parent := nil;
  end;
end;

procedure TCodaMinaAVLTree.BalanceAfterDelete(ANode: PAVLNode);
var
  OldParent, OldRight, OldRightLeft, OldLeft, OldLeftRight, OldRightLeftLeft,
    OldRightLeftRight, OldLeftRightLeft, OldLeftRightRight: PAVLNode;
begin
  if (ANode = nil) then
    exit;
  if ((ANode^.Balance = +1) or (ANode^.Balance = -1)) then
    exit;
  OldParent := ANode^.Parent;
  if (ANode^.Balance = 0) then
  begin
    // Treeheight has decreased by one
    if (OldParent <> nil) then
    begin
      if (OldParent^.Left = ANode) then
        Inc(OldParent^.Balance)
      else
        Dec(OldParent^.Balance);
      BalanceAfterDelete(OldParent);
    end;
    exit;
  end;
  if (ANode^.Balance = +2) then
  begin
    // Node is overweighted to the right
    OldRight := ANode^.Right;
    if (OldRight^.Balance >= 0) then
    begin
      // OldRight^.Balance=={0 or -1}
      // rotate left
      OldRightLeft := OldRight^.Left;
      if (OldParent <> nil) then
      begin
        if (OldParent^.Left = ANode) then
          OldParent^.Left := OldRight
        else
          OldParent^.Right := OldRight;
      end
      else
        Root := OldRight;
      ANode^.Parent := OldRight;
      ANode^.Right := OldRightLeft;
      OldRight^.Parent := OldParent;
      OldRight^.Left := ANode;
      if (OldRightLeft <> nil) then
        OldRightLeft^.Parent := ANode;
      ANode^.Balance := (1 - OldRight^.Balance);
      Dec(OldRight^.Balance);
      BalanceAfterDelete(OldRight);
    end
    else
    begin
      // OldRight^.Balance=-1
      // double rotate right left
      OldRightLeft := OldRight^.Left;
      OldRightLeftLeft := OldRightLeft^.Left;
      OldRightLeftRight := OldRightLeft^.Right;
      if (OldParent <> nil) then
      begin
        if (OldParent^.Left = ANode) then
          OldParent^.Left := OldRightLeft
        else
          OldParent^.Right := OldRightLeft;
      end
      else
        Root := OldRightLeft;
      ANode^.Parent := OldRightLeft;
      ANode^.Right := OldRightLeftLeft;
      OldRight^.Parent := OldRightLeft;
      OldRight^.Left := OldRightLeftRight;
      OldRightLeft^.Parent := OldParent;
      OldRightLeft^.Left := ANode;
      OldRightLeft^.Right := OldRight;
      if (OldRightLeftLeft <> nil) then
        OldRightLeftLeft^.Parent := ANode;
      if (OldRightLeftRight <> nil) then
        OldRightLeftRight^.Parent := OldRight;
      if (OldRightLeft^.Balance <= 0) then
        ANode^.Balance := 0
      else
        ANode^.Balance := -1;
      if (OldRightLeft^.Balance >= 0) then
        OldRight^.Balance := 0
      else
        OldRight^.Balance := +1;
      OldRightLeft^.Balance := 0;
      BalanceAfterDelete(OldRightLeft);
    end;
  end
  else
  begin
    // Node.Balance=-2
    // Node is overweighted to the left
    OldLeft := ANode^.Left;
    if (OldLeft^.Balance <= 0) then
    begin
      // rotate right
      OldLeftRight := OldLeft^.Right;
      if (OldParent <> nil) then
      begin
        if (OldParent^.Left = ANode) then
          OldParent^.Left := OldLeft
        else
          OldParent^.Right := OldLeft;
      end
      else
        Root := OldLeft;
      ANode^.Parent := OldLeft;
      ANode^.Left := OldLeftRight;
      OldLeft^.Parent := OldParent;
      OldLeft^.Right := ANode;
      if (OldLeftRight <> nil) then
        OldLeftRight^.Parent := ANode;
      ANode^.Balance := (-1 - OldLeft^.Balance);
      Inc(OldLeft^.Balance);
      BalanceAfterDelete(OldLeft);
    end
    else
    begin
      // OldLeft^.Balance = 1
      // double rotate left right
      OldLeftRight := OldLeft^.Right;
      OldLeftRightLeft := OldLeftRight^.Left;
      OldLeftRightRight := OldLeftRight^.Right;
      if (OldParent <> nil) then
      begin
        if (OldParent^.Left = ANode) then
          OldParent^.Left := OldLeftRight
        else
          OldParent^.Right := OldLeftRight;
      end
      else
        Root := OldLeftRight;
      ANode^.Parent := OldLeftRight;
      ANode^.Left := OldLeftRightRight;
      OldLeft^.Parent := OldLeftRight;
      OldLeft^.Right := OldLeftRightLeft;
      OldLeftRight^.Parent := OldParent;
      OldLeftRight^.Left := OldLeft;
      OldLeftRight^.Right := ANode;
      if (OldLeftRightLeft <> nil) then
        OldLeftRightLeft^.Parent := OldLeft;
      if (OldLeftRightRight <> nil) then
        OldLeftRightRight^.Parent := ANode;
      if (OldLeftRight^.Balance >= 0) then
        ANode^.Balance := 0
      else
        ANode^.Balance := +1;
      if (OldLeftRight^.Balance <= 0) then
        OldLeft^.Balance := 0
      else
        OldLeft^.Balance := -1;
      OldLeftRight^.Balance := 0;
      BalanceAfterDelete(OldLeftRight);
    end;
  end;
end;

procedure TCodaMinaAVLTree.BalanceAfterInsert(ANode: PAVLNode);
var
  OldParent, OldParentParent, OldRight, OldRightLeft, OldRightRight, OldLeft,
    OldLeftLeft, OldLeftRight: PAVLNode;
begin
  OldParent := ANode^.Parent;
  if (OldParent = nil) then
    exit;
  if (OldParent^.Left = ANode) then
  begin
    // Node is left son
    dec(OldParent^.Balance);
    if (OldParent^.Balance = 0) then
      exit;
    if (OldParent^.Balance = -1) then
    begin
      BalanceAfterInsert(OldParent);
      exit;
    end;
    // OldParent^.Balance=-2
    if (ANode^.Balance = -1) then
    begin
      // rotate
      OldRight := ANode^.Right;
      OldParentParent := OldParent^.Parent;
      if (OldParentParent <> nil) then
      begin
        // OldParent has GrandParent. GrandParent gets new child
        if (OldParentParent^.Left = OldParent) then
          OldParentParent^.Left := ANode
        else
          OldParentParent^.Right := ANode;
      end
      else
      begin
        // OldParent was root node. New root node
        Root := ANode;
      end;
      ANode^.Parent := OldParentParent;
      ANode^.Right := OldParent;
      OldParent^.Parent := ANode;
      OldParent^.Left := OldRight;
      if (OldRight <> nil) then
        OldRight^.Parent := OldParent;
      ANode^.Balance := 0;
      OldParent^.Balance := 0;
    end
    else
    begin
      // Node.Balance = +1
      // double rotate
      OldParentParent := OldParent^.Parent;
      OldRight := ANode^.Right;
      OldRightLeft := OldRight^.Left;
      OldRightRight := OldRight^.Right;
      if (OldParentParent <> nil) then
      begin
        // OldParent has GrandParent. GrandParent gets new child
        if (OldParentParent^.Left = OldParent) then
          OldParentParent^.Left := OldRight
        else
          OldParentParent^.Right := OldRight;
      end
      else
      begin
        // OldParent was root node. new root node
        Root := OldRight;
      end;
      OldRight^.Parent := OldParentParent;
      OldRight^.Left := ANode;
      OldRight^.Right := OldParent;
      ANode^.Parent := OldRight;
      ANode^.Right := OldRightLeft;
      OldParent^.Parent := OldRight;
      OldParent^.Left := OldRightRight;
      if (OldRightLeft <> nil) then
        OldRightLeft^.Parent := ANode;
      if (OldRightRight <> nil) then
        OldRightRight^.Parent := OldParent;
      if (OldRight^.Balance <= 0) then
        ANode^.Balance := 0
      else
        ANode^.Balance := -1;
      if (OldRight^.Balance = -1) then
        OldParent^.Balance := 1
      else
        OldParent^.Balance := 0;
      OldRight^.Balance := 0;
    end;
  end
  else
  begin
    // Node is right son
    Inc(OldParent^.Balance);
    if (OldParent^.Balance = 0) then
      exit;
    if (OldParent^.Balance = +1) then
    begin
      BalanceAfterInsert(OldParent);
      exit;
    end;
    // OldParent^.Balance = +2
    if (ANode^.Balance = +1) then
    begin
      // rotate
      OldLeft := ANode^.Left;
      OldParentParent := OldParent^.Parent;
      if (OldParentParent <> nil) then
      begin
        // Parent has GrandParent . GrandParent gets new child
        if (OldParentParent^.Left = OldParent) then
          OldParentParent^.Left := ANode
        else
          OldParentParent^.Right := ANode;
      end
      else
      begin
        // OldParent was root node . new root node
        Root := ANode;
      end;
      ANode^.Parent := OldParentParent;
      ANode^.Left := OldParent;
      OldParent^.Parent := ANode;
      OldParent^.Right := OldLeft;
      if (OldLeft <> nil) then
        OldLeft^.Parent := OldParent;
      ANode^.Balance := 0;
      OldParent^.Balance := 0;
    end
    else
    begin
      // Node.Balance = -1
      // double rotate
      OldLeft := ANode^.Left;
      OldParentParent := OldParent^.Parent;
      OldLeftLeft := OldLeft^.Left;
      OldLeftRight := OldLeft^.Right;
      if (OldParentParent <> nil) then
      begin
        // OldParent has GrandParent . GrandParent gets new child
        if (OldParentParent^.Left = OldParent) then
          OldParentParent^.Left := OldLeft
        else
          OldParentParent^.Right := OldLeft;
      end
      else
      begin
        // OldParent was root node . new root node
        Root := OldLeft;
      end;
      OldLeft^.Parent := OldParentParent;
      OldLeft^.Left := OldParent;
      OldLeft^.Right := ANode;
      ANode^.Parent := OldLeft;
      ANode^.Left := OldLeftRight;
      OldParent^.Parent := OldLeft;
      OldParent^.Right := OldLeftLeft;
      if (OldLeftLeft <> nil) then
        OldLeftLeft^.Parent := OldParent;
      if (OldLeftRight <> nil) then
        OldLeftRight^.Parent := ANode;
      if (OldLeft^.Balance >= 0) then
        ANode^.Balance := 0
      else
        ANode^.Balance := +1;
      if (OldLeft^.Balance = +1) then
        OldParent^.Balance := -1
      else
        OldParent^.Balance := 0;
      OldLeft^.Balance := 0;
    end;
  end;
end;

procedure TCodaMinaAVLTree.Clear;
  // Clear
begin
  DeleteNode(Root);
  Root := nil;
  FCount := 0;
end;
procedure TCodaMinaAVLTree.DeleteNode(ANode: PAVLNode);
begin
  if ANode <> nil then
  begin
    if ANode^.Left <> nil then
      DeleteNode(ANode^.Left);
    if ANode^.Right <> nil then
      DeleteNode(ANode^.Right);
  end;
  freeNode(ANode);
end;


procedure TCodaMinaAVLTree.Delete(ANode: PAVLNode);
var
  OldParent, OldLeft, OldRight, Successor, OldSuccParent, OldSuccLeft,
    OldSuccRight: PAVLNode;
  OldBalance: Integer;
begin
  OldParent := ANode^.Parent;
  OldBalance := ANode^.Balance;
  ANode^.Parent := nil;
  ANode^.Balance := 0;
  if ((ANode^.Left = nil) and (ANode^.Right = nil)) then
  begin
    // Node is Leaf (no children)
    if (OldParent <> nil) then
    begin
      // Node has parent
      if (OldParent^.Left = ANode) then
      begin
        // Node is left Son of OldParent
        OldParent^.Left := nil;
        Inc(OldParent^.Balance);
      end
      else
      begin
        // Node is right Son of OldParent
        OldParent^.Right := nil;
        Dec(OldParent^.Balance);
      end;
      BalanceAfterDelete(OldParent);
    end
    else
    begin
      // Node is the only node of tree
      Root := nil;
    end;
    dec(FCount);
    FreeNode(ANode);
    exit;
  end;
  if (ANode^.Right = nil) then
  begin
    // Left is only son
    // and because DelNode is AVL, Right has no childrens
    // replace DelNode with Left
    OldLeft := ANode^.Left;
    ANode^.Left := nil;
    OldLeft^.Parent := OldParent;
    if (OldParent <> nil) then
    begin
      if (OldParent^.Left = ANode) then
      begin
        OldParent^.Left := OldLeft;
        Inc(OldParent^.Balance);
      end
      else
      begin
        OldParent^.Right := OldLeft;
        Dec(OldParent^.Balance);
      end;
      BalanceAfterDelete(OldParent);
    end
    else
    begin
      Root := OldLeft;
    end;
    dec(FCount);
    FreeNode(ANode);
    exit;
  end;
  if (ANode^.Left = nil) then
  begin
    // Right is only son
    // and because DelNode is AVL, Left has no childrens
    // replace DelNode with Right
    OldRight := ANode^.Right;
    ANode^.Right := nil;
    OldRight^.Parent := OldParent;
    if (OldParent <> nil) then
    begin
      if (OldParent^.Left = ANode) then
      begin
        OldParent^.Left := OldRight;
        Inc(OldParent^.Balance);
      end
      else
      begin
        OldParent^.Right := OldRight;
        Dec(OldParent^.Balance);
      end;
      BalanceAfterDelete(OldParent);
    end
    else
    begin
      Root := OldRight;
    end;
    dec(FCount);
    FreeNode(ANode);
    exit;
  end;
  // DelNode has both: Left and Right
  // Replace ANode with symmetric Successor
  Successor := FindSuccessor(ANode);
  OldLeft := ANode^.Left;
  OldRight := ANode^.Right;
  OldSuccParent := Successor^.Parent;
  OldSuccLeft := Successor^.Left;
  OldSuccRight := Successor^.Right;
  ANode^.Balance := Successor^.Balance;
  Successor^.Balance := OldBalance;
  if (OldSuccParent <> ANode) then
  begin
    // at least one node between ANode and Successor
    ANode^.Parent := Successor^.Parent;
    if (OldSuccParent^.Left = Successor) then
      OldSuccParent^.Left := ANode
    else
      OldSuccParent^.Right := ANode;
    Successor^.Right := OldRight;
    OldRight^.Parent := Successor;
  end
  else
  begin
    // Successor is right son of ANode
    ANode^.Parent := Successor;
    Successor^.Right := ANode;
  end;
  Successor^.Left := OldLeft;
  if OldLeft <> nil then
    OldLeft^.Parent := Successor;
  Successor^.Parent := OldParent;
  ANode^.Left := OldSuccLeft;
  if ANode^.Left <> nil then
    ANode^.Left^.Parent := ANode;
  ANode^.Right := OldSuccRight;
  if ANode^.Right <> nil then
    ANode^.Right^.Parent := ANode;
  if (OldParent <> nil) then
  begin
    if (OldParent^.Left = ANode) then
      OldParent^.Left := Successor
    else
      OldParent^.Right := Successor;
  end
  else
    Root := Successor;
  // delete Node as usual
  Delete(ANode);
end;
function TCodaMinaAVLTree.Find(searchData: T;out returnData:T): boolean;
var
  p:PAVLNode;
begin
  p:=find(searchData);
  if p=nil then
     exit(false);
  returnData:=p^.data;
  result:=true;
end;
function TCodaMinaAVLTree.Find(keyData: T): PAVLNode;
var
  Comp: Integer;
begin
  Result := Root;
  while (Result <> nil) do
  begin
    Comp := cmp(keyData, Result^.Data);
    if Comp = 0 then
      exit;
    if Comp < 0 then
    begin
      Result := Result^.Left;
    end
    else
    begin
      Result := Result^.Right;
    end;
  end;
  result:=nil;
end;

function TCodaMinaAVLTree.FindInsertPos(Data: T): PAVLNode;
var
  Comp: Integer;
begin
  Result := Root;
  while (Result <> nil) do
  begin
    Comp := cmp(Data, Result^.Data);
    if Comp < 0 then
    begin
      if Result^.Left <> nil then
        Result := Result^.Left
      else
        exit;
    end
    else
    begin
      if Result^.Right <> nil then
        Result := Result^.Right
      else
        exit;
    end;
  end;
end;


function TCodaMinaAVLTree.FindPrecessor(ANode: PAVLNode): PAVLNode;
begin
  Result := ANode^.Left;
  if Result <> nil then
  begin
    while (Result^.Right <> nil) do
      Result := Result^.Right;
  end
  else
  begin
    Result := ANode;
    while (Result^.Parent <> nil) and (Result^.Parent^.Left = Result) do
      Result := Result^.Parent;
    Result := Result^.Parent;
  end;
end;


function TCodaMinaAVLTree.FindSuccessor(ANode: PAVLNode): PAVLNode;
begin
  Result := ANode^.Right;
  if Result <> nil then
  begin
    while (Result^.Left <> nil) do
      Result := Result^.Left;
  end
  else
  begin
    Result := ANode;
    while (Result^.Parent <> nil) and (Result^.Parent^.Right = Result) do
      Result := Result^.Parent;
    Result := Result^.Parent;
  end;
end;

procedure TCodaMinaAVLTree.Remove(Data: T);
var
  ANode: PAVLNode;
begin
  ANode := Find(Data);
  if ANode <> nil then
    Delete(ANode);
end;

procedure TCodaMinaAVLTree.printTreeNode(n:PAVLNode; offs:integer);
var
  i:integer;
begin
    for i := 0 to offs-1  do
      write(stdout,' ');
    
    if n=nil then
    begin
      writeln(stdout,'(nil)');
      exit;
    end;
    if offs=0 then
//      write(stdout,'[*] ',integer(n),'=',n^.data,' Balance=',n^.Balance)
    else
    if (n^.Left = nil) and (n^.Right = nil) then
//      write(stdout,'[L] ',integer(n),'=',n^.data,' Balance=',n^.Balance)
    else 
//      write(stdout,'[I] ',integer(n),'=',n^.data,' Balance=',n^.Balance);

    writeln(stdout);
    for i := 0 to   offs  do
        write(stdout,' ');

    printTreeNode(n^.Left, offs + 1);
    for i := 0 to   offs  do
        write(stdout,' ');
    printTreeNode(n^.Right, offs + 1);
end;
procedure TCodaMinaAVLTree.printtree();
begin
  printTreeNode(root, 0);
end;       
end.
