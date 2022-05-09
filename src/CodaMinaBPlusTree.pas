{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaBPlusTree;

 {$mode ObjFPC}{$H+}{$BITPACKING ON}{$GOTO ON}  
 //{$define debug}
interface

const 
     abc=1;
type

  generic TCodaMinaBPlusTree<TKEY,TVALUE>=class
    type
            TClearFunc=procedure (value:TVALUE);
	    ttree_cmp_func=function(key1, key2:TKEY):integer;
	    pBPNodeRec=^TBPNodeRec;
	    TBPNodeRec=record
	      parent:pBPNodeRec;
	      max:integer;
	      isleaf:integer;
	      keys:array of TKEY;
	      data:array of TValue;
	      childs:array of pBPNodeRec;//if isleaf the childs[0]=left sibling, childs[1]=right sibling
	    end;
	    TBPTreeRec=record
        root,freeNode,freeLeafNode:pBPNodeRec;
        keys_per_node,half_keys_per_node:integer;
        cmp_func:ttree_cmp_func;
	Scavenger:TClearFunc;
	    end;
    private
      bptree:TBPTreeRec;
      function allocatenode(isleaf:boolean):pBPNodeRec;
      procedure insertIntoNode(pos:integer;n:pBPNodeRec;key:TKEY;value:Tvalue);
      function binarySearch(n:pBPNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
      procedure splitInsert(n,n2,child2:pBPNodeRec;var key:TKEY;var value:Tvalue);
      procedure removeInNode(pos:integer;n:pBPNodeRec);
      procedure freeANode(n:pBPNodeRec);
      function getFreeNode(isleaf:boolean):pBPNodeRec;
      procedure rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBPNodeRec);
      procedure printTreeNode(n:pBPNodeRec;offs:integer);
    public
      constructor create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10;lScavenger:TClearFunc=nil);
      function Find(key:TKEY):TVALUE;
      function delete(key:TKEY):boolean;
      function Add(key:TKEY;value:Tvalue):boolean;
      procedure printtree();
	end;
implementation
constructor TGenericBPlusTree.create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10;lScavenger:TClearFunc=nil);
var
  i:integer;
  p:pBPNodeRec;
begin
  bptree.root := nil;
  bptree.freeNode := nil;
  bptree.keys_per_node := recordcount;
  bptree.half_keys_per_node := recordcount div 2;
  bptree.cmp_func := cmpf;
	bptree.Scavenger:=lScavenger;
  for i:=0 to capacity do
  begin
    p:=AllocMem(sizeof(TBPNodeRec));
    freeANode(p);
  end;
  for i:=0 to capacity do
  begin
    p:=AllocMem(sizeof(TBPNodeRec));
    setlength(p^.data,bpTree.keys_per_node);
    p^.isleaf:=1;
    freeANode(p);
  end;
end;
function TCodaMinaBPlusTree.allocatenode(isleaf:boolean):pBPNodeRec;
var
  i:integer;
begin
  result:=getFreeNode(isleaf);
  if result=nil then
    result:= AllocMem(sizeof(TBPNodeRec));
  if result=nil then
    exit(nil);
  setlength(result^.keys,bpTree.keys_per_node);
  if isleaf then
  begin
    setlength(result^.data,bpTree.keys_per_node);
    result^.isleaf:=1;
  end
  else
  begin
    result^.isleaf:=0;
  end;
  setlength(result^.childs,bpTree.keys_per_node+1);
  
  result^.max:=0;
end;
function TCodaMinaBPlusTree.Add(key:TKEY;value:Tvalue):boolean;
var
  n,n1,n2,prior,prior2:pBPNodeRec;
  i,j,k:integer;
  cmp:integer;
  up,found:boolean;
begin
  if bptree.root=nil then
  begin
    bptree.root:=allocatenode(true);
    if bptree.root=nil then
      exit(false);
    insertIntoNode(bptree.root^.max,bptree.root,key,value);
    exit(true);
  end;
  result:=false;
  n:=bptree.root;
  up:=false;
  prior:=nil;
  
  while (n^.isleaf=0) do
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if found=true then //exact find
    begin
      i:=0;
      if n^.max>0 then
        exit(false);
    end;
    if bpTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
    end
    else
    begin
      n:=n^.childs[i];
    end;
  end;//end while
  up:=false;
  i:=binarySearch(n,0,n^.max-1,key,found);
  if found then
  begin
    exit(false);
  end;
  repeat
    if n^.max<bpTree.keys_per_node then 
    begin
      i:=binarySearch(n,0,n^.max-1,key,found);
      if bpTree.cmp_func(key, n^.keys[n^.max-1])>0 then
      begin
        insertIntoNode(n^.max,n,key,value);
        if up=true then
        begin
          n^.childs[n^.max]:=n2;
          n2^.parent:=n;
        end;
        exit(true);
      end;
      insertIntoNode(i,n,key,value);
      if up=true then
      begin
        n^.childs[i+1]:=n2;
        n2^.parent:=n;
      end;
      exit(true);
    end;
    //split and insert
    if up=true then
    begin
      n2:=allocatenode(false);
      if n2=nil then
        exit(false);
      splitInsert(n,n2,prior2,key,value);
    end
    else
    begin
      n2:=allocatenode(true);
      if n2=nil then
        exit(false);
      splitInsert(n,n2,nil,key,value);
    end;
    up:=true;
    prior:=n;
		prior2:=n2;
    n:=n^.parent;
  until ((up=false) or (n=nil));
  if up=true then
  begin
    //create root
    n1:=allocatenode(false);
    if n1=nil then
      exit(false);
    n1^.isleaf:=0;
    insertIntoNode(n1^.max,n1,key,value);
    bptree.root:=n1;
    prior^.parent:=n1;
    n2^.parent:=n1;
    n1^.childs[0]:=prior;
    n1^.childs[1]:=n2;
    result:=true;
  end;
end;

procedure TCodaMinaBPlusTree.rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBPNodeRec);
var
  i:integer;
begin
  if nfrom^.isleaf=1 then
  begin
  	for i:=frompos to topos do
  	begin

  		nto^.keys  [nto^.max]:=nfrom^.keys  [i];
  		nto^.data  [nto^.max]:=nfrom^.data  [i];
  		nto^.childs[nto^.max]:=nfrom^.childs[i];
  		if nto^.childs[nto^.max]<>nil then
  		 nto^.childs[nto^.max]^.parent:=nto;
  		nto^.max:=nto^.max+1;
  	end;
	end
	else
	begin
  	for i:=frompos to topos do
  	begin
  		nto^.keys  [nto^.max]:=nfrom^.keys  [i];
  		nto^.childs[nto^.max]:=nfrom^.childs[i];
  		if nto^.childs[nto^.max]<>nil then
  		 nto^.childs[nto^.max]^.parent:=nto;
  		nto^.max:=nto^.max+1;
  	end;
	end;
end;
procedure TCodaMinaBPlusTree.splitInsert(n,n2,child2:pBPNodeRec;var key:TKEY;var value:Tvalue);
var
  i,j,cmp:integer;
  tmpkey:Tkey;
  found:boolean;
begin
  j:=n^.max div 2;
  cmp:=bpTree.cmp_func(key, n^.keys[j]);//check with middle key of n
  if cmp < 0 then
  begin
    cmp:=bpTree.cmp_func(key, n^.keys[j-1]);
    if cmp < 0 then //mid key is j-1, so it will insert into last of n or use replace last
    begin
      rangeAppendToNode(j,n^.max-1,n,n2);
      n2^.childs[n2^.max]:=n^.childs[n^.max];
      if n2^.childs[n2^.max]<>nil then
        n2^.childs[n2^.max]^.parent:=n2;
      n^.max:=n^.max-n2^.max;
      i:=binarySearch(n,0,n^.max-1,key,found);
      insertIntoNode(i,n,key,value);
      key:=n^.keys[n^.max-1];
      if n^.isleaf=0 then
      begin
        n^.max:=n^.max-1;
        n^.childs[i+1]:=child2;
        child2^.parent:=n;
      end;
    end
    else
    if cmp > 0 then //mid key is inserting key, so if leaf node then insert tna use it as upper
    begin
      rangeAppendToNode(j,n^.max-1,n,n2);
      n2^.childs[n2^.max]:=n^.childs[n^.max];
      if n2^.childs[n2^.max]<>nil then
        n2^.childs[n2^.max]^.parent:=n2;
      n^.max:=n^.max-n2^.max;
      if n^.isleaf=1 then
      begin
        insertIntoNode(n^.max,n,key,value);
      end
      else
      begin
        n^.childs[n^.max]:=n2^.childs[0];
        if n^.childs[n^.max]<>nil then
          n^.childs[n^.max]^.parent:=n;
      
        n2^.childs[0]:=child2;
        if child2<>nil then   
          child2^.parent:=n2; 
      end; 
    end;
  end
  else
  if cmp > 0 then //mid key is j, so key is insert into n2, use n last key as upper
  begin
    rangeAppendToNode(j+1,n^.max-1,n,n2);
    n2^.childs[n2^.max]:=n^.childs[n^.max];
    if n2^.childs[n2^.max]<>nil then
      n2^.childs[n2^.max]^.parent:=n2;
    n^.max:=n^.max-n2^.max;
    i:=binarySearch(n2,0,n2^.max-1,key,found);
    if bpTree.cmp_func(key, n2^.keys[n2^.max-1])>0 then
    begin

      insertIntoNode(n2^.max,n2,key,value);
      key:=n^.keys[n^.max-1];
      if n^.isleaf=0 then
      begin
        n^.max:=n^.max-1;
      
        n2^.childs[n2^.max]:=child2;
        child2^.parent:=n2;
      end;
    end
    else
    begin
      insertIntoNode(i,n2,key,value);
      key:=n^.keys[n^.max-1];
      if n^.isleaf=0 then
      begin
        n^.max:=n^.max-1;

        n2^.childs[i+1]:=child2;
        child2^.parent:=n2;
      end;
    end;
  end;
  if n2^.isleaf=1 then
  begin
    n2^.childs[1]:=n^.childs[1];
    if n^.childs[1]<>nil then
      n^.childs[1]^.childs[0]:=n2;
    n^.childs[1]:=n2;
    n2^.childs[0]:=n;
  end;

end;
function TCodaMinaBPlusTree.binarySearch(n:pBPNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
var
  mid, cmp:integer;
  i:integer;
begin
  b:=false;
  while (floor <= ceil) do
  begin
    mid := (floor + ceil) shr 1;
    cmp := bpTree.cmp_func(key, n^.keys[mid]);
    if (cmp < 0) then
    begin
      ceil := mid - 1;
    end
    else 
    if (cmp > 0) then
    begin
      floor := mid + 1;
    end
    else 
    begin
      b:=true;
      exit(mid);
    end;
  end;
  if floor=n^.max then
    floor:=floor-1;
  result:=floor;
end;
procedure TCodaMinaBPlusTree.insertIntoNode(pos:integer;n:pBPNodeRec;key:TKEY;value:Tvalue);
var
  j:integer;
begin
  if n^.max>0 then
  begin
    n^.childs[n^.max+1]:=n^.childs[n^.max];
    if n^.isleaf=1 then
    begin
      for j:=n^.max-1 downto pos do
      begin
        n^.keys  [j+1]:=n^.keys[j];
        n^.data  [j+1]:=n^.data[j];
      end;
      n^.data[pos]:=value;
    end
    else
    begin
      for j:=n^.max-1 downto pos do
      begin
        n^.keys  [j+1]:=n^.keys[j];
        n^.childs[j+1]:=n^.childs[j];
      end;
    end;
  end
  else
  begin
    n^.childs[1]:=n^.childs[0];
    if n^.isleaf=1 then
      n^.data[pos]:=value;
  end;
  n^.keys[pos]:=key;
  n^.max:=n^.max+1;
end;
procedure TCodaMinaBPlusTree.printTreeNode(n:pBPNodeRec; offs:integer);
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
    if (n^.isleaf = 1) then
      write(stdout,'[L] ',integer(n),';parent=',integer(n^.parent),';left_link=',integer(n^.childs[0]),';right_link=',integer(n^.childs[1]))
    else 
    if (n^.parent <> nil) then
      write(stdout,offs,'[I] ',integer(n),';parent=',integer(n^.parent))
    else
      write(stdout,'[*] ',integer(n),';parent=',integer(n^.parent));

    writeln(stdout);
    for i := 0 to   offs  do
        write(stdout,' ');

    write(stdout,'<', n^.max,'>');
    
    write(stdout,'[');
    for i:=0 to n^.max-1 do
    begin
      write(stdout,n^.keys[i]);
      write(stdout,',');
    end;
    writeln(stdout,']');
    if (n^.isleaf = 0) then
    begin
      for i:=0 to n^.max do
      begin
        printTreeNode(n^.childs[i], offs + 1);
      end;
    end;
end;
procedure TCodaMinaBPlusTree.printtree();
begin
  printTreeNode(bpTree.root, 0);
end;
function TCodaMinaBPlusTree.Find(key:TKEY):TVALUE;
var
  n:pBPNodeRec;
  i:integer;
  found:boolean;
begin
  result:=default(TVALUE);
  if bptree.root=nil then
  begin
    exit(result);
  end;
  n:=bptree.root;
  while n<>nil do
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if (found=true) and (n^.isleaf=1) then //exact find
    begin
      exit(n^.data[i]);
    end;
    if bpTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
    end
    else
    begin
      n:=n^.childs[i];
    end;
  end;
end;

function TCodaMinaBPlusTree.delete(key:TKEY):boolean;
var
  n,target,leftsibling,rightsibling,mergeto,mergefrom:pBPNodeRec;
  i,siblingis,parentkeypos,parentlinkpos,targetkeypos,targetlinkpos,j:integer;
  up,found:boolean;
  tmpkey:TKEY;
begin
  if bptree.root=nil then
  begin
    exit(false);
  end;
  n:=bptree.root;
  result:=false;
  target:=nil;
  mergeto:=nil;

  while n^.isleaf=0 do
  begin
      i:=binarySearch(n,0,n^.max-1,key,found);
      if found=true then //exact find
      begin
        target:=n;
        n:=n^.childs[i];//start left subtree
        parentlinkpos:=i;
        parentkeypos:=i;
        targetlinkpos:=i;
        targetkeypos:=i;
        break;
      end;
      parentkeypos:=i;
      if bpTree.cmp_func(key, n^.keys[i])>0 then
      begin
        parentlinkpos:=i+1;
      end
      else
      begin
        parentlinkpos:=i;
      end;
      n:=n^.childs[parentlinkpos];
  end;
  //leaf=1 now!!
  if target<>nil then
  begin
    if (n=nil) and (target=BPTree.root) then
    begin
      removeInNode(i,target);
      exit(true);
    end;
    while n^.isleaf=0 do
    begin// find left subtree's "right most"
      parentlinkpos:=n^.max;
      parentkeypos:=n^.max-1;
      n:=n^.childs[n^.max];
    end;
    //left subtree's "right most" will be same key
    i:=n^.max-1;//remove key position
  end
  else
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if found=true then //exact find
    begin
      //i is the remove key position
    end
    else
    begin
      exit(false);
    end;
  end;
  removeInNode(i,n);
  //borrow from sibling or merge with sibling and then up merge
  if (n^.max>=bptree.half_keys_per_node) or (n^.parent=nil) then
  begin
    if target<>nil then
    begin
      target^.keys[targetkeypos]:=n^.keys[n^.max-1];
    end;
    exit(true);
  end
  else
  begin//try to borrow or merge
    up:=false;
    repeat
      leftsibling:=nil;
      rightsibling:=nil;
      if parentlinkpos=n^.parent^.max then
      begin
        leftsibling:=n^.parent^.childs[parentlinkpos-1];
      end
      else
      begin
        rightsibling:=n^.parent^.childs[parentlinkpos+1];

      end;
      
      if (leftsibling<>nil) and (leftsibling^.max>bptree.half_keys_per_node) then
      begin
        //move down parent key
        
        
        if n^.isleaf=0 then
        begin//parent key set to sibling's last key and relink
          insertIntoNode(0,n,n^.parent^.keys[parentkeypos],default(TValue));
          n^.parent^.keys[parentkeypos]:=leftsibling^.keys[leftsibling^.max-1];
          n^.childs[0]:=leftsibling^.childs[leftsibling^.max];
          n^.childs[0]^.parent:=n;
        end
        else
        begin//parent is same as sibling last key,because we are left subtree right most key same as parent key
          insertIntoNode(0,n,n^.parent^.keys[parentkeypos],leftsibling^.data[leftsibling^.max-1]);
          n^.parent^.keys[parentkeypos]:=leftsibling^.keys[leftsibling^.max-2];
        end;
        leftsibling^.max:=leftsibling^.max-1;

        if (target<>nil) and (n^.parent<>target) then
        begin//this means it is right most node has key to be delete, so use it last key to replace correspond internal key
          target^.keys[targetkeypos]:=n^.keys[n^.max-1];
          target:=nil;
        end;
        
        exit(true);
      end;
      if (rightsibling<>nil) and (rightsibling^.max>bptree.half_keys_per_node) then
      begin
        
        if n^.isleaf=0 then
        begin//move down parent key and move up sibling's first key to parent, relink 
          n^.keys[n^.max]:=n^.parent^.keys[parentkeypos];
          n^.parent^.keys[parentkeypos]:=rightsibling^.keys[0];
          n^.max:=n^.max+1;
          //re-link;          
          n^.childs[n^.max]:=rightsibling^.childs[0];
          n^.childs[n^.max]^.parent:=n;
        end
        else
        begin
          n^.parent^.keys[parentkeypos]:=rightsibling^.keys[0];
          n^.keys[n^.max]:=rightsibling^.keys[0];
          n^.data[n^.max]:=rightsibling^.data[0];
          n^.max:=n^.max+1;
        end;
        removeInNode(0,rightsibling);
        target:=nil;

        exit(true);
      end;
        
      //no place to borrow, so merge node
      if (leftsibling<>nil) then 
      begin //left sibling
        mergeto:=leftsibling;
        mergefrom:=n;
        siblingis:=0;
        
        if mergeto^.isleaf=1 then
        begin//preserve left right link of leat
          n^.parent^.childs[parentlinkpos]:=n^.parent^.childs[parentlinkpos-1];
          if (target<>nil) and (n^.parent<>target) then
          begin// same as above
            target^.keys[targetkeypos]:=n^.keys[n^.max-1];
            target:=nil;
          end;
        end;
      end
      else
      begin //right sibling
        mergeto:=n;
        mergefrom:=rightsibling;
        siblingis:=1;
        //preserve left right link of leat
        if mergeto^.isleaf=1 then
        begin
          n^.parent^.childs[parentlinkpos+1]:=n^.parent^.childs[parentlinkpos];
        end;
        target:=nil;
      end;
      //move parent to child's right most
      if mergeto^.isleaf=0 then
      begin
        mergeto^.Keys[mergeto^.max]:=mergeto^.parent^.keys[parentkeypos];
        mergeto^.max:=mergeto^.max+1;
        //preserve child of the key will be deleted 
        mergeto^.parent^.childs[parentkeypos+1]:=mergeto^.parent^.childs[parentkeypos];
      end;
      key:=mergeto^.parent^.keys[parentkeypos];
      removeInNode(parentkeypos,mergeto^.parent);
      //copy sibling to child
      //for performance, we can check isleaf first and than do different copy, so no need to check childs is nil
      if mergeto^.isleaf=0 then
      begin
        for j:=0 to mergefrom^.max-1 do
        begin
          mergeto^.keys[mergeto^.max]:=mergefrom^.keys[j];
          mergeto^.childs[mergeto^.max]:=mergefrom^.childs[j];
          mergeto^.childs[mergeto^.max]^.parent:=mergeto;
          mergeto^.max:=mergeto^.max+1;
        end;
        mergeto^.childs[mergeto^.max]:=mergefrom^.childs[mergefrom^.max];
        mergeto^.childs[mergeto^.max]^.parent:=mergeto;
      end
      else
      begin
        for j:=0 to mergefrom^.max-1 do
        begin
          mergeto^.keys[mergeto^.max]:=mergefrom^.keys[j];
          mergeto^.data[mergeto^.max]:=mergefrom^.data[j];
          mergeto^.max:=mergeto^.max+1;
        end;
        mergeto^.childs[siblingis]:=mergefrom^.childs[siblingis];//re-link left/right
      end;
      freeANode(mergefrom);
      if (mergeto^.parent^.max>=bptree.half_keys_per_node) or (mergeto^.parent=bptree.root) then
      begin
        result:=true;
        up:=false;
        if (mergeto^.parent=bptree.root) and (bptree.root^.max=0) then
        begin//reset root and free root node too
          freeANode(bptree.root);
          mergeto^.parent:=nil;
          bptree.root:=mergeto;
        end;
      end
      else
      begin
        up:=true;
        n:=mergeto^.parent;
        i:=parentkeypos;
        
        //find parent's parent child position
        parentkeypos:=binarySearch(n^.parent,0,n^.parent^.max-1,key,found);
				parentlinkpos:=parentkeypos;
				if (n^.parent^.childs[parentkeypos]<>n) then
				begin
				  if n^.parent^.childs[parentkeypos+1]=n then
					begin
				   parentlinkpos:=parentkeypos+1;
					end
					else
					begin
					  break;
					end;
					 
				end;
      end;
    until (up=false) and (n<>nil);
  end;
end;
procedure TCodaMinaBPlusTree.removeInNode(pos:integer;n:pBPNodeRec);
var
  i:integer;
begin
  if n^.isleaf=0 then
  begin
    for i:=pos+1 to n^.max-1 do
    begin
      n^.keys[i-1]:=n^.keys[i];
      //n^.data[i-1]:=n^.data[i];
      n^.childs[i-1]:=n^.childs[i];
    end;
    n^.childs[n^.max-1]:=n^.childs[n^.max];
  end
  else
  begin
    for i:=pos+1 to n^.max-1 do
    begin
      n^.keys[i-1]:=n^.keys[i];
      n^.data[i-1]:=n^.data[i];
    end;
  end;
  n^.max:=n^.max-1;
end;
procedure TCodaMinaBPlusTree.freeANode(n:pBPNodeRec);
var
  i:integer;
begin
  n^.max:=0;
  n^.parent:=nil;
	if bptree.Scavenger<>nil then
	begin
    for i:=0 to length(n^.childs)-1 do
    begin
      n^.childs[i]:=nil;
			bptree.Scavenger(n^.data[i]);
    end;
	end
	else
	begin
    for i:=0 to length(n^.childs)-1 do
    begin
      n^.childs[i]:=nil;
    end;
	end;
  if n^.isleaf=0 then
  begin
    if bptree.freeNode=nil then
    begin
      bptree.freeNode:=n;
      n^.parent:=nil;
    end
    else
    begin
      n^.parent:=bptree.freeNode;
      bptree.freeNode:=n;
    end;
  end
  else
  begin
    if bptree.freeLeafNode=nil then
    begin
      bptree.freeLeafNode:=n;
      n^.parent:=nil;
    end
    else
    begin
      n^.parent:=bptree.freeLeafNode;
      bptree.freeLeafNode:=n;
    end;
  end;
end;
function TCodaMinaBPlusTree.getFreeNode(isleaf:boolean):pBPNodeRec;
begin
  result:=nil;
  if isleaf=false then
  begin
    if bptree.freeNode<>nil then
    begin
      result:=bptree.freeNode;
      result^.parent:=nil;
      bptree.freeNode:=bptree.freeNode^.parent;
    end;
  end
  else
  begin
    if bptree.freeLeafNode<>nil then
    begin
      result:=bptree.freeLeafNode;
      result^.parent:=nil;
      bptree.freeLeafNode:=bptree.freeLeafNode^.parent;
    end;
  end;
end;
end.
