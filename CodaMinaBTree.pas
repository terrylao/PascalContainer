{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaBTree;

 {$mode ObjFPC}{$H+}{$BITPACKING ON}{$GOTO ON}  
 //{$define debug}
interface

const 
     abc=1;
type

  generic TCodaMinaBTree<TKEY,TVALUE>=class
    type
	    ttree_cmp_func=function(key1, key2:TKEY):integer;
	    pBNodeRec=^TBNodeRec;
	    TBNodeRec=record
	      parent:pBNodeRec;
	      max:integer;
	      isleaf:integer;
	      keys:array of TKEY;
	      data:array of TValue;
	      childs:array of pBNodeRec;
	    end;
	    TBTreeRec=record
        root,freeNode:pBNodeRec;
        keys_per_node,half_keys_per_node:integer;
        cmp_func:ttree_cmp_func;
	    end;
    private
      btree:TBTreeRec;
      function allocatenode():pBNodeRec;
      procedure insertIntoNode(pos:integer;n:pBNodeRec;key:TKEY;value:Tvalue);
      function binarySearch(n:pBNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
      procedure removeInNode(pos:integer;n:pBNodeRec);
      procedure freeANode(n:pBNodeRec);
      function getFreeNode():pBNodeRec;
      procedure splitInsert(n,n2,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
      procedure rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBNodeRec);
    public
      constructor create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10);
      function search(key:TKEY):TVALUE;
      function delete(key:TKEY):boolean;
      function searchNodeInsert(key:TKEY;value:Tvalue):boolean;
      procedure printTreeNode(n:pBNodeRec;offs:integer);
      procedure printtree();
	end;
implementation
constructor TCodaMinaBTree.create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10);
var
  i:integer;
  p:pBNodeRec;
begin
  bTree.root := nil;
  bTree.freeNode := nil;
  bTree.keys_per_node := recordcount;
  bTree.half_keys_per_node := recordcount div 2;
  bTree.cmp_func := cmpf;
  for i:=0 to capacity do
  begin
    p:=AllocMem(sizeof(TBNodeRec));
    freeANode(p);
  end;
end;
function TCodaMinaBTree.allocatenode():pBNodeRec;
var
  i:integer;
begin
  result:=getFreeNode();
  if result=nil then
    result:= AllocMem(sizeof(TBNodeRec));
  
  if result=nil then
    exit(nil);
  setlength(result^.keys,bTree.keys_per_node);
  setlength(result^.data,bTree.keys_per_node);
  setlength(result^.childs,bTree.keys_per_node+1);
  result^.isleaf:=1;
  result^.max:=0;
end;

function TCodaMinaBTree.searchNodeInsert(key:TKEY;value:Tvalue):boolean;
var
  n,n1,n2,prior,prior2:pBNodeRec;
  i,j,k,childpos:integer;
  cmp:integer;
  up,found:boolean;
begin
  if btree.root=nil then
  begin
    btree.root:=allocatenode();
    if btree.root=nil then
      exit(false);
    insertIntoNode(btree.root^.max,btree.root,key,value);
    exit(true);
  end;
  result:=false;
  n:=btree.root;
  up:=false;
  prior:=nil;
  while n<>nil do
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if found=true then //exact find
    begin
      i:=0;
      if n^.max>0 then
        exit(false);
    end;
    if (n^.isleaf=1) or (up=true) then
    begin
      if n^.max<bTree.keys_per_node then 
      begin
        if bTree.cmp_func(key, n^.keys[n^.max-1])>0 then
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
      end
      else
      begin
        //split and insert
        n2:=allocatenode();
        if n2=nil then
          exit(false);
        if up=true then
        begin
          n2^.isleaf:=0;
          splitInsert(n,n2,prior2,key,value);
        end
        else
        begin
          splitInsert(n,n2,nil,key,value);
        end;
        up:=true;
        prior:=n;
				prior2:=n2;
        n:=n^.parent;
        continue;
      end;
    end;
    prior:=n;
    if bTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
      childpos:=i+1;
    end
    else
    begin
      n:=n^.childs[i];
      childpos:=i;
    end;
  end;
  if up=true then
  begin
    //create root
    n1:=allocatenode();
    if n1=nil then
      exit(false);
    insertIntoNode(n1^.max,n1,key,value);
    btree.root:=n1;
    n1^.isleaf:=0;
    prior^.parent:=n1;
    n2^.parent:=n1;
    n1^.childs[0]:=prior;
    n1^.childs[1]:=n2;
    result:=true;
  end;
end;

procedure TCodaMinaBTree.rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBNodeRec);
var
  i:integer;
begin
  if nfrom^.isleaf=1 then
  begin
  	for i:=frompos to topos do
  	begin
  		nto^.keys  [nto^.max]:=nfrom^.keys  [i];
  		nto^.data  [nto^.max]:=nfrom^.data  [i];
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
  		nto^.data  [nto^.max]:=nfrom^.data  [i];
  		nto^.childs[nto^.max]:=nfrom^.childs[i];
  		if nto^.childs[nto^.max]<>nil then
  		 nto^.childs[nto^.max]^.parent:=nto;
  		nto^.max:=nto^.max+1;
  	end;
	end;
end;
procedure TCodaMinaBTree.splitInsert(n,n2,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
var
  i,j,cmp:integer;
  tmpkey:Tkey;
  found:boolean;
begin
  j:=n^.max div 2;
  cmp:=bTree.cmp_func(key, n^.keys[j]);//check with middle key of n
  if cmp < 0 then
  begin
    cmp:=bTree.cmp_func(key, n^.keys[j-1]);
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
      value:=n^.data[n^.max-1];
      n^.max:=n^.max-1;

      n^.childs[i+1]:=child2;
      if child2<>nil then
        child2^.parent:=n;
    end
    else
    if cmp > 0 then //mid key is inserting key, so if leaf node then insert tna use it as upper
    begin
      rangeAppendToNode(j,n^.max-1,n,n2);
      n2^.childs[n2^.max]:=n^.childs[n^.max];
      if n2^.childs[n2^.max]<>nil then
        n2^.childs[n2^.max]^.parent:=n2;
      n^.max:=n^.max-n2^.max;

      n^.childs[n^.max]:=n2^.childs[0];
      if n^.childs[n^.max]<>nil then
        n^.childs[n^.max]^.parent:=n;
      
      n2^.childs[0]:=child2;
      if child2<>nil then   
        child2^.parent:=n2; 

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
    if bTree.cmp_func(key, n2^.keys[n2^.max-1])>0 then
    begin
      //insertIntoNode(n2^.max,n2,key,value);
      n2^.keys[n2^.max]:=key;
      n2^.data[n2^.max]:=value;
      n2^.max:=n2^.max+1;
      key:=n^.keys[n^.max-1];
      value:=n^.data[n^.max-1];
      n^.max:=n^.max-1;
      
      n2^.childs[n2^.max]:=child2;
      if child2<>nil then
        child2^.parent:=n2;
    end
    else
    begin
      insertIntoNode(i,n2,key,value);
      key:=n^.keys[n^.max-1];
      value:=n^.data[n^.max-1];
      n^.max:=n^.max-1;
      
      n2^.childs[i+1]:=child2;
      if child2<>nil then
        child2^.parent:=n2;
    end;
  end;
end;

function TCodaMinaBTree.binarySearch(n:pBNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
var
  mid, cmp:integer;
  i:integer;
begin
  b:=false;
  while (floor <= ceil) do
  begin
    mid := (floor + ceil) shr 1;
    cmp := bTree.cmp_func(key, n^.keys[mid]);
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
procedure TCodaMinaBTree.insertIntoNode(pos:integer;n:pBNodeRec;key:TKEY;value:Tvalue);
var
  j:integer;
begin
  if n^.max>0 then
  begin
    n^.childs[n^.max+1]:=n^.childs[n^.max];
    for j:=n^.max-1 downto pos do
    begin
      n^.keys  [j+1]:=n^.keys[j];
      n^.data  [j+1]:=n^.data[j];
      n^.childs[j+1]:=n^.childs[j];
    end;
  end
  else
  begin
    n^.childs[1]:=n^.childs[0];
  end;
  n^.keys[pos]:=key;
  n^.data[pos]:=value;
  n^.max:=n^.max+1;
end;
procedure TCodaMinaBTree.printTreeNode(n:pBNodeRec; offs:integer);
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
      write(stdout,'[L] ',integer(n),';parent=',integer(n^.parent))
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
    for i:=0 to n^.max do
    begin
      printTreeNode(n^.childs[i], offs + 1);
    end;
end;
procedure TCodaMinaBTree.printtree();
begin
  printTreeNode(bTree.root, 0);
end;
function TCodaMinaBTree.search(key:TKEY):TVALUE;
var
  n:pBNodeRec;
  i:integer;
  found:boolean;
begin
  result:=default(TVALUE);
  if btree.root=nil then
  begin
    exit(result);
  end;
  n:=btree.root;
  while n<>nil do
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if found=true then //exact find
    begin
      exit(n^.data[i]);
    end;
    if bTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
    end
    else
    begin
      n:=n^.childs[i];
    end;
  end;
end;
function TCodaMinaBTree.delete(key:TKEY):boolean;
var
  n,target,leftsibling,rightsibling,mergeto,mergefrom:pBNodeRec;
  i,parentkeypos,parentlinkpos,targetkeypos,targetlinkpos,j:integer;
  up,found:boolean;
begin
  if btree.root=nil then
  begin
    exit(false);
  end;
  n:=btree.root;
  result:=false;
  target:=nil;
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
      if bTree.cmp_func(key, n^.keys[i])>0 then
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
    if (n=nil) and (target=btree.root) then
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
    //replace by left subtree's "right most"
    target^.keys[targetkeypos]:=n^.keys[n^.max-1];
    target^.data[targetkeypos]:=n^.data[n^.max-1];
    i:=n^.max-1;//remove key position
    key:=n^.keys[n^.max-1];
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
  if (n^.max>=btree.half_keys_per_node) or (n^.parent=nil{btree.root}) then
  begin
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
        //leftsibling:=n^.parent^.childs[parentlinkpos-1];
        rightsibling:=n^.parent^.childs[parentlinkpos+1];
      end;
      //move parent downto right most and move right sibling's left most / left sibling's right most to parent
      
      if (leftsibling<>nil) and (leftsibling^.max>btree.half_keys_per_node) then
      begin
        insertIntoNode(0,n,n^.parent^.keys[parentkeypos],n^.parent^.data[parentkeypos]);
        n^.parent^.keys[parentkeypos]:=leftsibling^.keys[leftsibling^.max-1];
        n^.parent^.data[parentkeypos]:=leftsibling^.data[leftsibling^.max-1];
        //re-link;
        n^.childs[0]:=leftsibling^.childs[leftsibling^.max];
        if n^.childs[0]<>nil then
          n^.childs[0]^.parent:=n;
        leftsibling^.max:=leftsibling^.max-1;
        //removeInNode(leftsibling^.max-1,leftsibling);
        exit(true);
      end;
      if (rightsibling<>nil) and (rightsibling^.max>btree.half_keys_per_node) then
      begin
        insertIntoNode(n^.max,n,n^.parent^.keys[parentkeypos],n^.parent^.data[parentkeypos]);
        n^.parent^.keys[parentkeypos]:=rightsibling^.keys[0];
        n^.parent^.data[parentkeypos]:=rightsibling^.data[0];
        //re-link;
        n^.childs[n^.max]:=rightsibling^.childs[0];
        if n^.childs[n^.max]<>nil then
          n^.childs[n^.max]^.parent:=n;
        removeInNode(0,rightsibling);
        exit(true);
      end;
      //no place to borrow, so merge node
      if (leftsibling<>nil) then 
      begin //left sibling
        mergeto:=leftsibling;
        mergefrom:=n;
        //clone right to left for removing then remove child 
        n^.parent^.childs[parentlinkpos]:=n^.parent^.childs[parentlinkpos-1];
      end
      else
      begin //right sibling
        mergeto:=n;
        mergefrom:=rightsibling;
        //clone right to left for removing then remove child
        n^.parent^.childs[parentlinkpos+1]:=n^.parent^.childs[parentlinkpos];
      end;
      //move parent to child's right most
      mergeto^.keys[mergeto^.max]:=mergeto^.parent^.keys[parentkeypos];
      mergeto^.data[mergeto^.max]:=mergeto^.parent^.data[parentkeypos];
      mergeto^.max:=mergeto^.max+1;
      removeInNode(parentkeypos,mergeto^.parent);
      //copy sibling to child
      //for performance, we can check isleaf first and than do different copy, so no need to check childs is nil
      if mergeto^.isleaf=0 then
      begin
        for j:=0 to mergefrom^.max-1 do
        begin
          mergeto^.keys[mergeto^.max]:=mergefrom^.keys[j];
          mergeto^.data[mergeto^.max]:=mergefrom^.data[j];
          mergeto^.childs[mergeto^.max]:=mergefrom^.childs[j];
          //if mergeto^.childs[mergeto^.max]<>nil then
            mergeto^.childs[mergeto^.max]^.parent:=mergeto;//looks unnecessary????
          mergeto^.max:=mergeto^.max+1;
        end;
        mergeto^.childs[mergeto^.max]:=mergefrom^.childs[mergefrom^.max];//looks unnecessary????
        //if mergeto^.childs[mergeto^.max]<>nil then
          mergeto^.childs[mergeto^.max]^.parent:=mergeto;//looks unnecessary????
      end
      else
      begin
        for j:=0 to mergefrom^.max-1 do
        begin
          mergeto^.keys[mergeto^.max]:=mergefrom^.keys[j];
          mergeto^.data[mergeto^.max]:=mergefrom^.data[j];
          mergeto^.max:=mergeto^.max+1;
        end;
      end;

      freeANode(mergefrom);
      if (mergeto^.parent^.max>=btree.half_keys_per_node) or (mergeto^.parent=btree.root) then
      begin
        result:=true;
        up:=false;
        if (mergeto^.parent=btree.root) and (btree.root^.max=0) then
        begin//reset root and free root node too
          freeANode(btree.root);
          mergeto^.parent:=nil;
          mergeto^.isleaf:=0;
          btree.root:=mergeto;
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
procedure TCodaMinaBTree.removeInNode(pos:integer;n:pBNodeRec);
var
  i:integer;
begin
  if n^.isleaf=0 then
  begin
    for i:=pos+1 to n^.max-1 do
    begin
      n^.keys[i-1]:=n^.keys[i];
      n^.data[i-1]:=n^.data[i];
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
procedure TCodaMinaBTree.freeANode(n:pBNodeRec);
var
  i:integer;
begin
  n^.max:=0;
  n^.parent:=nil;
  for i:=0 to length(n^.childs)-1 do
  begin
    n^.childs[i]:=nil;
  end;
  if btree.freeNode=nil then
  begin
    btree.freeNode:=n;
    n^.parent:=nil;
  end
  else
  begin
    n^.parent:=btree.freeNode;
    btree.freeNode:=n;
  end;
end;
function TCodaMinaBTree.getFreeNode():pBNodeRec;
begin
  result:=nil;
  if btree.freeNode<>nil then
  begin
    result:=btree.freeNode;
    result^.parent:=nil;
    btree.freeNode:=btree.freeNode^.parent;
  end;
end;
end.
