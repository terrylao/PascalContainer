{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaBStarTree;

 {$mode ObjFPC}{$H+}{$BITPACKING ON}{$GOTO ON}  
 //{$define debug}
interface

const 
     LEFT_SIBLING=1;
     RIGHT_SIBLING=0;
     RIGHT_SIBLING_LEFT_COUSIN=2;
type

  generic TCodaMinaBStarTree<TKEY,TVALUE>=class
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
	    TBStarTreeRec=record
        root,freeNode:pBNodeRec;
        keys_per_node,twothird_keys_per_node,half_keys_per_node:integer;
        cmp_func:ttree_cmp_func;
	    end;
    private
      BStarTree:TBStarTreeRec;
      function allocatenode():pBNodeRec;
      procedure insertIntoNode(pos:integer;n:pBNodeRec;key:TKEY;value:Tvalue);
      procedure rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBNodeRec);
      procedure rangeAppendToNodeNochild(frompos,topos:integer;nfrom,nto:pBNodeRec);
      function binarySearch(n:pBNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
      procedure split3NodeInsert(n,n1,n2,n3,child2:pBNodeRec;parentpos:integer;var key:TKEY;var value:Tvalue);
      procedure split2NodeInsert(n,n2,child,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
      procedure removeInNode(pos:integer;n:pBNodeRec);
      procedure Redistribute(n,sibling:pBNodeRec;parentkeypos,siblingside:integer);
      procedure rangeRemoveInNode(cutbeforepos:integer;n:pBNodeRec);
      procedure freeANode(n:pBNodeRec);
      function getFreeNode():pBNodeRec;
      procedure setupRelative(parentkeypos,parentlinkpos:integer;n:pBNodeRec;var siblingside,unclekeypos:integer;var sibling,cousin:pBNodeRec);
      procedure split2NodeInsertv2(n,n2,child,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
    public
      constructor create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10);
      function search(key:TKEY):TVALUE;
      function delete(key:TKEY):boolean;
      function searchNodeInsert(key:TKEY;value:Tvalue):boolean;
      procedure printTreeNode(n:pBNodeRec;offs:integer);
      procedure printtree();
	end;
implementation
constructor TCodaMinaBStarTree.create(cmpf:ttree_cmp_func;recordcount:integer;capacity:integer=10);
var
  i:integer;
  p:pBNodeRec;
begin
  BStarTree.root := nil;
  BStarTree.freeNode := nil;
	if recordcount<2 then
	 recordcount:=2;
  BStarTree.keys_per_node := recordcount;
  BStarTree.twothird_keys_per_node := (recordcount * 2) div 3;
  BStarTree.half_keys_per_node:=recordcount div 2;
  BStarTree.cmp_func := cmpf;
  for i:=0 to capacity do
  begin
    p:=AllocMem(sizeof(TBNodeRec));
    freeANode(p);
  end;
end;
function TCodaMinaBStarTree.allocatenode():pBNodeRec;
var
  i:integer;
begin
  result:=getFreeNode();
  if result=nil then
    result:= AllocMem(sizeof(TBNodeRec));
  
  if result=nil then
    exit(nil);
  setlength(result^.keys,BStarTree.keys_per_node);
  setlength(result^.data,BStarTree.keys_per_node);
  setlength(result^.childs,BStarTree.keys_per_node+1);
  result^.isleaf:=1;
  result^.max:=0;
end;
function TCodaMinaBStarTree.searchNodeInsert(key:TKEY;value:Tvalue):boolean;
var
  n,n1,n2,n3,prior,prior1,prior2,prior3:pBNodeRec;
  i,j,childpos,parentpos,siblingpos,checkpos:integer;
  cmp:integer;
  up,found:boolean;
begin
  if BStarTree.root=nil then
  begin
    BStarTree.root:=allocatenode();
    if BStarTree.root=nil then
      exit(false);
    insertIntoNode(BStarTree.root^.max,BStarTree.root,key,value);
    exit(true);
  end;
  result:=false;
  n:=BStarTree.root;
  up:=false;
  prior:=nil;
  prior1:=nil;
  prior2:=nil;
  prior3:=nil;
  childpos:=-1;
  parentpos:=-1;
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
      if n^.max<BStarTree.keys_per_node then 
      begin
        if BStarTree.cmp_func(key, n^.keys[n^.max-1])>0 then
        begin
          insertIntoNode(n^.max,n,key,value);
          if up=true then
          begin
            //shift childs
            n^.childs[n^.max]:=n^.childs[n^.max-1];
            n^.childs[n^.max-1]:=n2;
            n2^.parent:=n;
          end;
          exit(true);
        end;
        
        insertIntoNode(i,n,key,value);
        if up=true then
        begin
          n^.childs[i]:=n2;
          n2^.parent:=n;
        end;
        exit(true);
      end
      else
      begin//this node full, then try to redistribute or split
        if (parentpos=-1) then// has parent
        begin
          n2:=allocatenode();
          if n2=nil then
            exit(false);
          n2^.isleaf:=n^.isleaf;
          split2NodeInsert(n,n2,prior2,prior3,key,value);
          prior:=n;
  				up:=true;
          break;
        end;
        if n^.parent^.childs[siblingpos]^.max<BStarTree.keys_per_node then
        begin
          //redistribute keys
          //1. move down parent and insert into sibling.
          if childpos=parentpos then
          begin
            checkpos:=n^.max-1;
            insertIntoNode(0,n^.parent^.childs[siblingpos],n^.parent^.keys[parentpos],n^.parent^.data[parentpos]);
            if up=true then
            begin
              n^.parent^.childs[siblingpos]^.childs[0]:=n^.childs[n^.max];
              n^.parent^.childs[siblingpos]^.childs[0]^.parent:=n^.parent^.childs[siblingpos];
              n^.childs[n^.max]:=prior2;
              prior2^.parent:=n;
            end;
          end
          else
          begin
            checkpos:=0;
            i:=i-1;//because the inserting position is shift to left
            insertIntoNode(n^.parent^.childs[siblingpos]^.max,n^.parent^.childs[siblingpos],n^.parent^.keys[parentpos],n^.parent^.data[parentpos]);
            if up=true then
            begin
              n^.parent^.childs[siblingpos]^.childs[n^.parent^.childs[siblingpos]^.max]:=n^.childs[0];
              n^.parent^.childs[siblingpos]^.childs[n^.parent^.childs[siblingpos]^.max]^.parent:=n^.parent^.childs[siblingpos];
              n^.childs[0]:=prior2;
              prior2^.parent:=n;
            end;
          end;
        
          //2. check if key in checkpos is mid,  move key at checkpos to parent
          if (checkpos=0) then
          begin
            if (BStarTree.cmp_func(key, n^.keys[checkpos])>0) then
            begin
              n^.parent^.keys[parentpos]:=n^.keys[checkpos];
              n^.parent^.data[parentpos]:=n^.data[checkpos];
              removeInNode(checkpos,n);
            end
            else
            begin
              n^.parent^.keys[parentpos]:=key;
              n^.parent^.data[parentpos]:=value;
              exit(true);
            end;
          end
          else
          begin
            if (BStarTree.cmp_func(key, n^.keys[checkpos])<0) then
            begin
              //copy last of n into parent, and because last child links are re-linked, so 
              //need remove it and do insert
              
              n^.parent^.keys[parentpos]:=n^.keys[checkpos];
              n^.parent^.data[parentpos]:=n^.data[checkpos];
              //because moveInNode just overwrite at pos, 
              //but not fit here remove the last link and key and data
              //so keep it first
              n^.childs[checkpos+1]:=n^.childs[checkpos];
              removeInNode(checkpos,n);
            end
            else
            begin
              n^.parent^.keys[parentpos]:=key;
              n^.parent^.data[parentpos]:=value;
              exit(true);            
            end;
          end;
          if BStarTree.cmp_func(key, n^.keys[n^.max-1])>0 then
          begin
            insertIntoNode(n^.max,n,key,value);
            if up=true then
            begin
              n^.childs[n^.max-1]:=prior2;
              prior2^.parent:=n;
            end;
          end
          else
          begin
            insertIntoNode(i,n,key,value);
            if up=true then
            begin
              n^.childs[i]:=prior2;
              prior2^.parent:=n;
            end;
          end;
          exit(true);
        end;       

        //split and insert
        n2:=allocatenode();
        if n2=nil then
          exit(false);
        
        if n^.parent<>nil then
				if childpos=parentpos then
        begin
				  n1:=n;
					n3:=n^.parent^.childs[siblingpos];
        end
				else
				begin
				  n1:=n^.parent^.childs[siblingpos];
					n3:=n;
				end;

        if up=true then
        begin
          n2^.isleaf:=0;
          split3NodeInsert(n,n1,n2,n3,prior2,parentpos,key,value);
        end
        else
        begin
          split3NodeInsert(n,n1,n2,n3,nil,parentpos,key,value);
        end;
        
        up:=true;
        prior:=n;
        prior1:=n1;
				prior2:=n2;
				prior3:=n3;
        n:=n^.parent;
        if n=nil then
         break;
        if n^.parent<>nil then
        begin
          i:=binarySearch(n^.parent,0,n^.parent^.max-1,key,found);
          parentpos:=i;
          if BStarTree.cmp_func(key, n^.parent^.keys[i])>0 then
          begin
            childpos:=i+1;
      			siblingpos:=i;
          end
          else
          begin
            childpos:=i;
      			siblingpos:=i+1;
          end;
        end
        else
        begin
          parentpos:=-1;
        end;
        continue;
      end;
    end;//end if up and isleaf
    prior:=n;
    parentpos:=i;
    if BStarTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
      childpos:=i+1;
			siblingpos:=i;
    end
    else
    begin
      n:=n^.childs[i];
      childpos:=i;
      if i>0 then
      begin
        siblingpos:=i-1;
        parentpos:=parentpos-1;
      end
      else
      begin
			  siblingpos:=i+1;
			end;
    end;
  end;
  if up=true then
  begin
    //create root
    n1:=allocatenode();
    if n1=nil then
      exit(false);
    insertIntoNode(n1^.max,n1,key,value);
    BStarTree.root:=n1;
    n1^.isleaf:=0;
    prior^.parent:=n1;
    n2^.parent:=n1;
    n1^.childs[0]:=prior;
    n1^.childs[1]:=n2;
    result:=true;
  end;
end;

procedure TCodaMinaBStarTree.split3NodeInsert(n,n1,n2,n3,child2:pBNodeRec;parentpos:integer;var key:TKEY;var value:Tvalue);
var
  i,j,k,cmp,mid:integer;
  target:pbnoderec;
  tmpkey:Tkey;
  tmpValue:TValue;
  found:boolean;
begin
  //1. move last 1/3 of n1 into n2
  //count to position, +1 because always let n1's last key into parent
  i:=BStarTree.keys_per_node-(BStarTree.keys_per_node-BStarTree.twothird_keys_per_node)+1;
  if n=n1 then
  begin
    //strategy: always move last of n1 to parent, this make
    //          last link of n1 problem easier to solve 
    j:=binarySearch(n1,0,n1^.max-1,key,found);
    if j>=i then //if key insert into last 1/3
    begin
      if BStarTree.cmp_func(key, n1^.keys[n1^.max-1])>0 then
      begin//key is insert into the end of n1, so move 1/3-1 of keys into n2
        rangeAppendToNode(i+1,n1^.max-1,n1,n2);
  			n2^.keys  [n2^.max]:=key;
  			n2^.data  [n2^.max]:=value;
  			if n2^.max=0 then//<--remove last link handling of rangeAppendToNode can resolve this checking
  			begin//oh, cause nothing move from n1 to n2
  			  n2^.childs  [1]:=n1^.childs  [n1^.max];
  			  if n2^.childs  [1]<>nil then
  			   n2^.childs  [1]^.parent:=n2;
  			   
  			  n2^.childs  [0]:=child2;
          if child2<>nil then
            child2^.parent:=n2;
          n2^.max:=n2^.max+1;
  			end
  			else
  			begin
          n2^.childs[n2^.max]:=child2;//re-link:cause it should link to right most
          if child2<>nil then
            child2^.parent:=n2;
          n2^.max:=n2^.max+1;
  			  n2^.childs  [n2^.max]:=n1^.childs  [n1^.max];
  			  if n2^.childs  [n2^.max]<>nil then
  			   n2^.childs  [n2^.max]^.parent:=n2;
  			  n1^.max:=n1^.max-n2^.max+1;//do +1 because of key inserted into n2, it is not copy from n1
  			end;
      end
      else
      begin 
        //key is insert into last 1/3 of n1,so move keys position
        //from last 1/3-1 to the keys which insert into n2
        //insert key into n2
        //move rest keys into n2
  			rangeAppendToNode(i+1,j-1,n1,n2);

  			n2^.keys  [n2^.max]:=key;
  			n2^.data  [n2^.max]:=value;
        n2^.childs[n2^.max]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n2;
  			n2^.max:=n2^.max+1;
  			rangeAppendToNode(j,n1^.max-1,n1,n2);
				n2^.childs  [n2^.max]:=n1^.childs  [n1^.max];
				if n2^.childs  [n2^.max]<>nil then
				 n2^.childs  [n2^.max]^.parent:=n2;
        n1^.max:=n1^.max-n2^.max+1;
      end;
      
    end
    else
    begin
      //just move last 1/3 keys of n1 into n2,cause less than 1/3
      
      rangeAppendToNode(i,n1^.max-1,n1,n2);
			n2^.childs  [n2^.max]:=n1^.childs  [n1^.max];
			if n2^.childs  [n2^.max]<>nil then
			 n2^.childs  [n2^.max]^.parent:=n2;
    	n1^.max:=n1^.max-n2^.max;
      if BStarTree.cmp_func(key, n1^.keys[n1^.max-1])>0 then
      begin
        insertIntoNode(n1^.max,n1,key,value);
        n1^.childs[n1^.max]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n1;
      end
      else
      begin
        insertIntoNode(j,n1,key,value);
        n1^.childs[j]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n1;
      end;
    end;
  end
  else
  begin
    rangeAppendToNode(i,n1^.max-1,n1,n2);
		n2^.childs  [n2^.max]:=n1^.childs  [n1^.max];
		if n2^.childs  [n2^.max]<>nil then
		 n2^.childs  [n2^.max]^.parent:=n2;
		n1^.max:=n1^.max-n2^.max;
  end;
	
	//2. move down parent to n2, will in last
	insertIntoNode(n2^.max,n2,n1^.parent^.keys[parentpos],n1^.parent^.data[parentpos]);
	//3. move 1st 1/3 of n3 into n2
	i:=(BStarTree.keys_per_node-BStarTree.twothird_keys_per_node)-1;//count to position
  if n=n3 then
  begin
    //strategy: always set last of n2 to be the New KEY,
    //          this make last link of n2 same as first link of n3 problem fixed 
    j:=binarySearch(n3,0,n3^.max-1,key,found);
    if j<=i then
    begin
      if BStarTree.cmp_func(key, n3^.keys[0])<0 then
      begin
  			n2^.keys  [n2^.max]:=key;
  			n2^.data  [n2^.max]:=value;
        n2^.childs[n2^.max]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n2;
  			n2^.max:=n2^.max+1;
        rangeAppendToNode(0,i-1,n3,n2);
      end
      else
      begin
        //problem is child link re-arrange of all situation
        rangeAppendToNode(0,j-1,n3,n2);
  			n2^.keys  [n2^.max]:=key;
  			n2^.data  [n2^.max]:=value;
        n2^.childs[n2^.max]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n2;
  			n2^.max:=n2^.max+1;
  			rangeAppendToNode(j,i-1,n3,n2);
      end;
      rangeRemoveInNode(i,n3);
    end
    else
    begin
      //greater than 1/3 of n3
      rangeAppendToNode(0,i,n3,n2);
			rangeRemoveInNode(i+1,n3);
			j:=binarySearch(n3,0,n3^.max-1,key,found);
      if BStarTree.cmp_func(key, n3^.keys[n3^.max-1])>0 then
      begin
        insertIntoNode(n3^.max,n3,key,value);
        n3^.childs[n3^.max-1]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n3;
      end
      else
      begin  
    	 insertIntoNode(j,n3,key,value);
        n3^.childs[j]:=child2;//re-link:
        if child2<>nil then
          child2^.parent:=n3;
    	end;
    end;
  end
  else
  begin
    rangeAppendToNode(0,i,n3,n2);
  	rangeRemoveInNode(i+1,n3);
  end;
	n1^.parent^.keys[parentpos]:=n1^.keys[n1^.max-1];
	n1^.parent^.data[parentpos]:=n1^.data[n1^.max-1];
	n1^.max:=n1^.max-1;
	
	key:=n2^.keys[n2^.max-1];
	value:=n2^.data[n2^.max-1];
	n2^.max:=n2^.max-1;
	
end;
procedure TCodaMinaBStarTree.split2NodeInsertv2(n,n2,child,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
var
  i,j,cmp:integer;
  tmpkey:Tkey;
  found:boolean;
begin
  j:=n^.max div 2;
  cmp:=BStarTree.cmp_func(key, n^.keys[j]);//check with middle key of n
  if cmp < 0 then
  begin
    cmp:=BStarTree.cmp_func(key, n^.keys[j-1]);
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
          n^.max:=n^.max-1;

      n^.childs[i]:=child;
      if child<>nil then
        child^.parent:=n;
        
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
      
      n^.childs[n^.max]:=child;
      if child<>nil then   
        child^.parent:=n;
         
      insertIntoNode(n^.max,n,key,value);
      
      n^.childs[n^.max]:=child2;
      if child2<>nil then   
        child2^.parent:=n; 

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
    if BStarTree.cmp_func(key, n2^.keys[n2^.max-1])>0 then
    begin
      n2^.childs[n2^.max]:=child;
      if child<>nil then
        child^.parent:=n2;
      insertIntoNode(n2^.max,n2,key,value);
      key:=n^.keys[n^.max-1];
      if n^.isleaf=0 then
        n^.max:=n^.max-1;
      
      n2^.childs[n2^.max]:=child2;
      if child2<>nil then
        child2^.parent:=n2;
    end
    else
    begin
      insertIntoNode(i,n2,key,value);
      key:=n^.keys[n^.max-1];
      if n^.isleaf=0 then
        n^.max:=n^.max-1;
        
      n2^.childs[i]:=child;
      if child<>nil then
        child^.parent:=n2;
        
      n2^.childs[i+1]:=child2;
      if child2<>nil then
        child2^.parent:=n2;
    end;
  end;
end;
procedure TCodaMinaBStarTree.split2NodeInsert(n,n2,child,child2:pBNodeRec;var key:TKEY;var value:Tvalue);
var
  i,j,k,cmp,mid:integer;
  target:pbnoderec;
  tmpkey:Tkey;
  tmpValue:TValue;
  found:boolean;
begin
  j:=n^.max div 2;
  cmp:=BStarTree.cmp_func(key, n^.keys[j]);
  target:=nil;
  if cmp < 0 then
  begin
    cmp:=BStarTree.cmp_func(key, n^.keys[j-1]);
    if cmp < 0 then //mid key is j-1
    begin
      k:=j;
      mid:=j-1;
      target:=n;
    end
    else
    if cmp > 0 then //mid key is inserting key
    begin
      k:=j;
      mid:=-1;
    end;
  end
  else
  if cmp > 0 then //mid key is j
  begin
    k:=j+1;
    mid:=j;
    target:=n2;
  end;
  i:=0;
  if n2^.isleaf=1 then
  begin
    for k:=k to n^.max-1 do
    begin
      n2^.keys  [i]:=n^.keys  [k];
      n2^.data  [i]:=n^.data  [k];
      i:=i+1;
    end;
  end
  else
  begin
    for k:=k to n^.max-1 do
    begin
      n2^.keys  [i]:=n^.keys  [k];
      n2^.data  [i]:=n^.data  [k];
      n2^.childs[i]:=n^.childs[k];
      n2^.childs[i]^.parent:=n2;
      i:=i+1;
    end;
    n2^.childs[i]:=n^.childs[k+1];//re-link child for new node
    if n2^.childs[i]<>nil then 
      n2^.childs[i]^.parent:=n2;
  end;
  n2^.max:=i;
  n^.max:=n^.max-i;

  if mid>-1 then
  begin
    tmpKey:=n^.keys  [mid];
    tmpValue:=n^.data  [mid];
    n^.max:=n^.max - 1;
    i:=binarySearch(target,0,target^.max-1,key,found);
    if BStarTree.cmp_func(key, target^.keys[target^.max-1])>0 then
    begin
      target^.childs[target^.max]:=child;
      insertIntoNode(target^.max,target,key,value);
			target^.childs[target^.max]:=child2;
      if child<>nil then
        child^.parent:=target;
      if child2<>nil then
        child2^.parent:=target;
      key:=tmpKey;
      value:=tmpValue;
      exit;
    end;
    insertIntoNode(i,target,key,value);
    target^.childs[i]:=child;
		target^.childs[i+1]:=child2;
    if child<>nil then
      child^.parent:=target;
    if child2<>nil then
      child2^.parent:=target;
    key:=tmpKey;
    value:=tmpValue;
	end
	else
	begin
	  n^.childs[n^.max]:=child;
    if child<>nil then
      child^.parent:=n;
	end;
	n2^.parent:=n^.parent;
end;
function TCodaMinaBStarTree.binarySearch(n:pBNodeRec; floor,ceil:integer;key:TKEY;var b:boolean):integer;
var
  mid, cmp:integer;
  i:integer;
begin
  b:=false;
  while (floor <= ceil) do
  begin
    mid := (floor + ceil) shr 1;
    cmp := BStarTree.cmp_func(key, n^.keys[mid]);
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
procedure TCodaMinaBStarTree.insertIntoNode(pos:integer;n:pBNodeRec;key:TKEY;value:Tvalue);
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
procedure TCodaMinaBStarTree.printTreeNode(n:pBNodeRec; offs:integer);
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
procedure TCodaMinaBStarTree.printtree();
begin
  printTreeNode(BStarTree.root, 0);
end;
function TCodaMinaBStarTree.search(key:TKEY):TVALUE;
var
  n:pBNodeRec;
  i:integer;
  found:boolean;
begin
  result:=default(TVALUE);
  if BStarTree.root=nil then
  begin
    exit(result);
  end;
  n:=BStarTree.root;
  while n<>nil do
  begin
    i:=binarySearch(n,0,n^.max-1,key,found);
    if found=true then //exact find
    begin
      exit(n^.data[i]);
    end;
    if BStarTree.cmp_func(key, n^.keys[i])>0 then
    begin
      n:=n^.childs[i+1];
    end
    else
    begin
      n:=n^.childs[i];
    end;
  end;
end;
{
delete 10:
1.
                [,          30      , 55     ,]
                /                  |           \
    [,  15   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[10*,  ] [19,20]     [27 ]   [35]   [48,50,] [60,70]    [90]
2.
                [,          30      , 55     ,]
                /                  |           \
    [,  15   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[,  ] [19,20]     [27 ]   [35]   [48,50,] [60,70]    [90]
3.borrow
                [,          30      , 55     ,]
                /                  |           \
    [,  19   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15,  ] [ 20]     [27 ]   [35]   [48,50,] [60,70]    [90]  
delete 30:
1.
                [,          30*      , 55     ,]
                /                   |          \
    [,  19   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15,  ] [ 20]      [27 ]   [35]   [48,50,] [60,70]    [90]
2.
                [,          30*      , 55     ,]
                /                   |          \
    [,  19   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15,  ] [ 20]     [27 ]<-   [35]   [48,50,] [60,70]    [90]
3.
                [,          27       ,  55     ,]
                /                   |          \
    [,  19   ,     25  ,]     [,40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15,  ] [ 20]  [underflow]   [35]   [48,50,] [60,70]    [90]
4.
                [,     27       ,  55     ,]
                /              /          \
    [,  19   ,  ]          [,40   , ]     [ , 80 ,]
   /        |              /     |         |     \
[15,  ] [ 20,25]         [35]   [48,50,] [60,70]    [90]
**delete 10:
1.
                [,          30      , 55     ,]
                /                  |           \
    [,  15   ,     25  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[10*,  ]  [19]    [27,29 ] [35]   [48,50,] [60,70]  [90]
2. double borrow
                [,          30      , 55     ,]
                /                  |           \
    [,  19   ,     27  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15,  ]  [25]     [ ,29 ] [35]   [48,50,] [60,70]  [90]
delete 29:
1.
                [,          30      , 55     ,]
                /                  |           \
    [,  19   ,     27  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15  ]   [25]     [ 29* ] [35]   [48,50,] [60,70]  [90]
2.no where to borrow from
                [,          30      , 55     ,]
                /                  |           \
    [,  19   ,     27  ,]   [,  40   , ]     [ , 80 ,]
   /        |          \      /     |         |     \
[15  ]   [25]   [UNDERFLOW] [35]   [48,50,] [60,70]  [90]
3.
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  40   , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [35]   [48,50,] [60,70]  [90]
delete:40
1.
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  40*  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [35]   [48,50,] [60,70]  [90]
2.find left subtree right most to replace
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  40*  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [35]<- [48,50,] [60,70]  [90]
3.
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  35  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [  ]<- [48,50,] [60,70]  [90]
4. borrow from sibling
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  35  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [  ]<- [48*,50,] [60,70]  [90]
5.
                [,    30      , 55     ,]
                /            |          \
    [,  19   ,  ]   [,  48  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [35]  [  50,]   [60,70]  [90]
DELETE:55
1.
                [,    30      , 55*    ,]
                /            |          \
    [,  19   ,  ]   [,  48  , ]     [ , 80 ,]
   /        |       /       |         |     \
[15 ]  [25,27]   [35]  [  50,]   [60,70]  [90]
2.
                [,    30      , 55*    ,]
                /            |          \
    [,  19   ,  ]   [,  48  , ]     [ , 80 ,]
   /        |       /      |         |     \
[15 ]  [25,27]   [35]  [50<-]   [60,70]  [90]
3.
                [,    30      , 50    ,]
                /            |        \
    [,  19   ,  ]   [,  48  , ]     [ , 80 ,]
   /        |       /      |         |     \
[15 ]  [25,27]   [35]  [ <-]   [60,70]   [90]
4.
                [,    30      , 50    ,]
                /            |        \
    [,  19   ,  ]   [,     ]     [ , 80 ,]
   /        |       /               |     \
[15 ]  [25,27]   [35,48]   [60,70]   [90]
5.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  50   , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [35,48] [60,70] [90]
DELETE 35:
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  50   , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [48] [60,70]   [90]
DELETE 50:
1.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  50*  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [48] [60,70]   [90]
2.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  50*  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [48]<- [60,70]   [90]
3.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  48*  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [  ]<- [60,70]   [90]
4.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [,  *  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [ 48]<- [60,70]   [90]
5.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [, 60  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [ 48]    [70]   [90]
DELETE 70:
1.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [, 60  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [ 48]    [70*]   [90]
2.
                [,    30         ,]
                /                \
    [,  19   ,  ]   [, 60  , 80 ,]
   /        |       /       |     \
[15 ]  [25,27]   [ 48]    [   ]   [90]
3.
                [,    30   ,]
                /          \
    [,  19   ,  ]   [, 60  ,]
   /        |       /      \
[15 ]  [25,27]   [ 48]    [ 80,90  ]
strategy:
1. find the node which delete from
2. if it is internal node as [I] then from it find the last key in right most node of left subtree, it must be a leaf node as [L]
2.1 move last key of [L] into [I].
3. if it is leaf node then
3.1   delete from the node
3.2   if the node has atleast 2/3 keys, then exit
3.2.1 else if its sibling(right most node is its left node, otherwise is its right node) has greater than 2/3 keys then
4        RE-DISTRIBUTE from it with sibling , cousin 3 nodes and with parent key and uncle key into 2 nodes
          (it is last/last -1  node)left-sibling,far-left-cousin:
4.1.1	     move down parent key to its first, move last key of left into parent, last child of left to its first
4.1.2	     move down uncle key to lefts first, move last key of far-left into uncle, last child of far-left to lefts first.    
	  (it is first/second and others node)right-sibling,far-right cousin:
4.2.1      move down parent key to its last, move first key of right into parent, first child of right to its last
4.2.2      move down uncle key to right last, move last key of far-right into uncle, last child of far-right to right last
5      else MERGE it with sibling , cousin 3 nodes and with parent key and uncle key into 2 nodes
          (it is last/last -1  node)left-sibling,far-left-cousin:cause make a swap,they are same
5.1.1	  move down uncle and 1/3-1 with links from left to end of far-left, move 1/3th up of left to uncle.
5.1.2	  move down parent and  1/3-1 with links from it to end of left,free [it]
	  (it is first/second and others node)right-sibling,far-right cousin:
5.2.1     move down uncle and last 1/3-1 with links from right to first of far-right, move 1/3th up of left to uncle.
5.2.2     move down parent and last 1/3-1 with links from it to first of right,free [it]
6   go up to parent node,  act as delete the parent key from parent node
6.1 back to 3.1 **??there is a 2 node to merge case when under ROOT**
}
function TCodaMinaBStarTree.delete(key:TKEY):boolean;
var
  n,target,sibling,cousin:pBNodeRec;
  i,parentkeypos,parentlinkpos,targetkeypos,targetlinkpos,j,unclekeypos,siblingside:integer;
  up,found:boolean;
begin
  if BStarTree.root=nil then
  begin
    exit(false);
  end;
  n:=BStarTree.root;
  result:=false;
  target:=nil;
  cousin:=nil;
  targetkeypos:=-1;
  siblingside:=RIGHT_SIBLING;//right side
  while n^.isleaf=0 do
  begin
      i:=binarySearch(n,0,n^.max-1,key,found);
      if found=true then //exact find
      begin
        target:=n;
        parentlinkpos:=i;
        parentkeypos:=i;
        targetlinkpos:=i;
        targetkeypos:=i;
        n:=n^.childs[i];//start left suBStarTree
        break;
      end;
      parentkeypos:=i;
      parentlinkpos:=i;
      if BStarTree.cmp_func(key, n^.keys[i])>0 then
      begin
        parentlinkpos:=i+1;
      end
      else
      begin
        parentlinkpos:=i;
      end;
      n:=n^.childs[parentlinkpos];
  end;
  if n^.parent<>nil then
  begin
    setupRelative(parentkeypos,parentlinkpos,n^.parent,siblingside,unclekeypos,sibling,cousin);
  end;
  //leaf=1 now!!
  if target<>nil then
  begin
    if (n=nil) and (target=BStarTree.root) then
    begin
      removeInNode(i,target);
      exit(true);
    end; 
    while n^.isleaf=0 do
    begin// find left subtree's "right most" key
      parentlinkpos:=n^.max;
      parentkeypos:=n^.max-1;
      sibling:=n^.childs[parentlinkpos-1];
      if parentkeypos>1 then
      begin
        cousin:=n^.childs[parentlinkpos-2];
        unclekeypos:=parentkeypos-1;
      end;
      siblingside:=LEFT_SIBLING;
      n:=n^.childs[n^.max];
    end;
    //replace by left subtree's "right most" 
    target^.keys[targetkeypos]:=n^.keys[n^.max-1];
    target^.data[targetkeypos]:=n^.data[n^.max-1];
    key:=n^.keys[n^.max-1];
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
  //borrow from sibling or cousin
  if (n^.max>=BStarTree.twothird_keys_per_node) or (n^.parent=nil{BStarTree.root}) then
  begin
    exit(true);
  end
  else
  begin//borrow from sibling/cousin
    up:=false;
    repeat
      if sibling^.max>BStarTree.twothird_keys_per_node then
      begin
        Redistribute(n,sibling,parentkeypos,siblingside);
        exit(true);
      end;
      if (cousin<>nil) and (cousin^.max>BStarTree.twothird_keys_per_node) then
      begin
        if siblingside<>RIGHT_SIBLING_LEFT_COUSIN then
        begin
          Redistribute(n,sibling,parentkeypos,siblingside);
          Redistribute(sibling,cousin,unclekeypos,siblingside);
        end
        else
        begin
          Redistribute(n,sibling,parentkeypos,RIGHT_SIBLING);
          Redistribute(n,cousin,unclekeypos,LEFT_SIBLING);
        end;
        exit(true);
      end;
      if (cousin=nil) and (sibling^.parent=BStarTree.root) then
      begin
        if (n^.max+sibling^.max<=BStarTree.keys_per_node) then
        begin
          if siblingside=RIGHT_SIBLING then
          begin
            target:=n;
            n:=sibling;
            sibling:=target;          
          end;
          //1. move down ROOT's last key to sibling
          insertIntoNode(sibling^.max,sibling,sibling^.parent^.keys[parentkeypos],sibling^.parent^.data[parentkeypos]);
          sibling^.childs[sibling^.max-1]:=sibling^.childs[sibling^.max];
          //2. move ALL keys/data/links to sibling last
          rangeAppendToNode(0,n^.max-1,n,sibling);
          sibling^.childs[sibling^.max]:=n^.childs[n^.max];
          if sibling^.childs[sibling^.max]<>nil then
            sibling^.childs[sibling^.max]^.parent:=sibling;
          freeANode(n);
          freeANode(BStarTree.root);
          sibling^.parent:=nil;
          sibling^.isleaf:=0;
          BStarTree.root:=sibling;
        end;
        //ok, let lazy to redistrubute keys for 2 nodes and a 1 key parent
        exit(true);
      end;
      //1.move down uncle insert into cousin node
      //2.move sibling link first/last to last/first of cousin node
      //3.move first/last 1/3 keys of sibling node into last/first of cousin node
      //4.move first/last key/data into uncle 
      //5.move down parent insert into sibling node
      //6.move n's link first/last to last/first of sibling node
      //7.move all n's key/data/link into sibling node
      //8.remove parent key and let parent act as delete node, back to 1 if not yet finished
      if siblingside=RIGHT_SIBLING then
      begin
        //1.
        insertIntoNode(0,cousin,cousin^.parent^.keys[unclekeypos],cousin^.parent^.data[unclekeypos]);
        //2.last to first
        cousin^.childs[0]:=sibling^.childs[sibling^.max];
        if cousin^.childs[0]<>nil then
        begin
          cousin^.childs[0]^.parent:=cousin;
        end;
        //3.
        i:=((BStarTree.keys_per_node-BStarTree.twothird_keys_per_node)-1);
        cousin^.childs[cousin^.max+i]:=cousin^.childs[cousin^.max];
        for j:=cousin^.max-1 downto 0 do
        begin
          cousin^.keys  [j+i]:=cousin^.keys  [j];
          cousin^.data  [j+i]:=cousin^.data  [j];
          cousin^.childs[j+i]:=cousin^.childs[j];
        end;
        cousin^.max:=cousin^.max+i;
        i:=i-1;
        j:=sibling^.max-1;
				
        while i>-1 do
        begin
          cousin^.keys  [i]:=sibling^.keys  [j];
          cousin^.data  [i]:=sibling^.data  [j];
          cousin^.childs[i]:=sibling^.childs[j];
          if cousin^.childs[i]<>nil then
             cousin^.childs[i]^.parent:=cousin;
          i:=i-1;
          j:=j-1;
        end;
        //4.last key
        i:=((BStarTree.keys_per_node-BStarTree.twothird_keys_per_node)-1);        
        sibling^.max:=sibling^.max-i-1;//minus more 1 because the last key will up to uncle

        cousin^.parent^.keys[unclekeypos]:=sibling^.keys[sibling^.max];
        cousin^.parent^.data[unclekeypos]:=sibling^.data[sibling^.max];

        //5.
        insertIntoNode(0,sibling,sibling^.parent^.keys[parentkeypos],sibling^.parent^.data[parentkeypos]);
        //6.last to first
        sibling^.childs[0]:=n^.childs[n^.max];
        if sibling^.childs[0]<>nil then
          sibling^.childs[0]^.parent:=sibling;
        //7.
        i:=sibling^.max+n^.max-1;
        sibling^.childs[i+1]:=sibling^.childs[sibling^.max];
        for j:=sibling^.max-1 downto 0 do
        begin
          sibling^.keys  [i]:=sibling^.keys  [j];
          sibling^.data  [i]:=sibling^.data  [j];
          sibling^.childs[i]:=sibling^.childs[j];
          i:=i-1;
        end;
        sibling^.max:=sibling^.max+n^.max;
        j:=n^.max-1;
        while j>-1 do
        begin
          sibling^.keys  [j]:=n^.keys  [j];
          sibling^.data  [j]:=n^.data  [j];
          sibling^.childs[j]:=n^.childs[j];
          if sibling^.childs[j]<>nil then
            sibling^.childs[j]^.parent:=sibling;
          j:=j-1;
        end;
        //8.
        removeInNode(parentkeypos,n^.parent);
      end
      else
      begin//LEFT_SIBLING and RIGHT_SIBLING_LEFT_COUSIN
        if siblingside=RIGHT_SIBLING_LEFT_COUSIN then
        begin
          //swap n and sibling;
          target:=n;
          n:=sibling;
          sibling:=target;
        end;
        //1.
        insertIntoNode(cousin^.max,cousin,cousin^.parent^.keys[unclekeypos],cousin^.parent^.data[unclekeypos]);
        cousin^.childs[cousin^.max-1]:=cousin^.childs[cousin^.max];//fix moving link
        //2.first to last
        //3.
        i:=((BStarTree.keys_per_node-BStarTree.twothird_keys_per_node)-1);

        rangeAppendToNode(0,i-1,sibling,cousin);

        //4.first after moved, cause links problem
        rangeRemoveInNode(i,sibling);
        cousin^.parent^.keys[unclekeypos]:=sibling^.keys[0];
        cousin^.parent^.data[unclekeypos]:=sibling^.data[0];
        cousin^.childs[cousin^.max]:=sibling^.childs[0];
        if cousin^.childs[cousin^.max]<>nil then
           cousin^.childs[cousin^.max]^.parent:=cousin;
        removeInNode(0,sibling);
        //5.
        insertIntoNode(sibling^.max,sibling,sibling^.parent^.keys[parentkeypos],sibling^.parent^.data[parentkeypos]);
        sibling^.childs[sibling^.max-1]:=sibling^.childs[sibling^.max];//fix moving link
        //6.first to last
        sibling^.childs[sibling^.max]:=n^.childs[0];
        if sibling^.childs[0]<>nil then
          sibling^.childs[0]^.parent:=sibling;
        //7.

        rangeAppendToNode(0,n^.max-1,n,sibling);
        sibling^.childs[sibling^.max]:=n^.childs[n^.max];
        if sibling^.childs[sibling^.max]<>nil then
          sibling^.childs[sibling^.max]^.parent:=sibling;
        //8.
				n^.parent^.max:=n^.parent^.max-1;
        //removeInNode(parentkeypos,n^.parent);
      end;
      freeANode(n);
      if (sibling^.parent^.max>BStarTree.twothird_keys_per_node) or (sibling^.parent=BStarTree.root) then
      begin
        result:=true;
        up:=false;
      end
      else
      begin
        up:=true;
        n:=sibling^.parent;
        i:=parentkeypos;
        if (n^.max>=BStarTree.twothird_keys_per_node) or (n^.parent=nil) then
        begin
          result:=true;
          break;
        end;
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
        setupRelative(parentkeypos,parentlinkpos,n^.parent,siblingside,unclekeypos,sibling,cousin);
      end;
    until (up=false);
  end;
end;
procedure TCodaMinaBStarTree.setupRelative(parentkeypos,parentlinkpos:integer;n:pBNodeRec;var siblingside,unclekeypos:integer;var sibling,cousin:pBNodeRec);
begin
  if parentlinkpos=n^.max-1 then
  begin
    sibling:=n^.childs[parentlinkpos+1];
    if parentkeypos>0 then
    begin
      cousin:=n^.childs[parentlinkpos-1];
      unclekeypos:=parentkeypos-1;
    end
    else
    begin
      cousin:=nil;
    end;
    siblingside:=RIGHT_SIBLING_LEFT_COUSIN;
  end
  else
  if parentlinkpos=n^.max then
  begin
    sibling:=n^.childs[parentlinkpos-1];
    if parentkeypos>0 then
    begin
      cousin:=n^.childs[parentlinkpos-2];
      unclekeypos:=parentkeypos-1;
    end
    else
    begin
      cousin:=nil;
    end;
    siblingside:=LEFT_SIBLING;
  end
  else
  begin
    sibling:=n^.childs[parentlinkpos+1];
    if parentlinkpos<n^.max-1 then
    begin
      cousin:=n^.childs[parentlinkpos+2];
      unclekeypos:=parentlinkpos+1;
    end
    else
    begin
      cousin:=nil;
    end;
    siblingside:=RIGHT_SIBLING;
  end;
end;
procedure TCodaMinaBStarTree.removeInNode(pos:integer;n:pBNodeRec);
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
procedure TCodaMinaBStarTree.Redistribute(n,sibling:pBNodeRec;parentkeypos,siblingside:integer);
begin
  if siblingside=LEFT_SIBLING then
  begin
    insertIntoNode(0,n,n^.parent^.keys[parentkeypos],n^.parent^.data[parentkeypos]);
    n^.childs[0]:=sibling^.childs[sibling^.max];
    if n^.childs[0]<>nil then
    begin
      n^.childs[0]^.parent:=n;
    end;
    n^.parent^.keys[parentkeypos]:=sibling^.keys[sibling^.max-1];
    n^.parent^.data[parentkeypos]:=sibling^.data[sibling^.max-1];
    sibling^.childs[sibling^.max]:=sibling^.childs[sibling^.max-1];//perserve right most link
    removeInNode(sibling^.max-1,sibling);
  end
  else
  begin
    n^.keys[n^.max]:=n^.parent^.keys[parentkeypos];
    n^.data[n^.max]:=n^.parent^.data[parentkeypos];
    n^.max:=n^.max+1;
    n^.childs[n^.max]:=sibling^.childs[0];
    if n^.childs[n^.max]<>nil then
    begin
      n^.childs[n^.max]^.parent:=n;
    end;
    n^.parent^.keys[parentkeypos]:=sibling^.keys[0];
    n^.parent^.data[parentkeypos]:=sibling^.data[0];
    removeInNode(0,sibling);
  end;
end;

procedure TCodaMinaBStarTree.rangeRemoveInNode(cutbeforepos:integer;n:pBNodeRec);
var
  i,k,j:integer;
begin
  k:=0;
  j:=n^.max;
	for i:=cutbeforepos to n^.max-1 do
	begin
		n^.keys  [k]:=n^.keys  [i];
		n^.data  [k]:=n^.data  [i];
		n^.childs[k]:=n^.childs[i];
		k:=k+1;
	end;
	n^.max:=n^.max-cutbeforepos;
	n^.childs[n^.max]:=n^.childs[j];
end;
//this doesnt change anything in nfrom and if topos is the last element, will copy the last link too
procedure TCodaMinaBStarTree.rangeAppendToNode(frompos,topos:integer;nfrom,nto:pBNodeRec);
var
  i:integer;
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
procedure TCodaMinaBStarTree.rangeAppendToNodeNochild(frompos,topos:integer;nfrom,nto:pBNodeRec);
var
  i:integer;
begin
	for i:=frompos to topos do
	begin
		nto^.keys  [nto^.max]:=nfrom^.keys  [i];
		nto^.data  [nto^.max]:=nfrom^.data  [i];
		nto^.max:=nto^.max+1;
	end;
end;
procedure TCodaMinaBStarTree.freeANode(n:pBNodeRec);
var
  i:integer;
begin
  n^.max:=0;
  n^.parent:=nil;
  for i:=0 to length(n^.childs)-1 do
  begin
    n^.childs[i]:=nil;
  end;
  if BStarTree.freeNode=nil then
  begin
    BStarTree.freeNode:=n;
    n^.parent:=nil;
  end
  else
  begin
    n^.parent:=BStarTree.freeNode;
    BStarTree.freeNode:=n;
  end;
end;
function TCodaMinaBStarTree.getFreeNode():pBNodeRec;
begin
  result:=nil;
  if BStarTree.freeNode<>nil then
  begin
    result:=BStarTree.freeNode;
    result^.parent:=nil;
    BStarTree.freeNode:=BStarTree.freeNode^.parent;
  end;
end;
end.
