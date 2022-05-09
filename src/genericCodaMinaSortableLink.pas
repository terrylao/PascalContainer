{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit genericCodaMinaSortableLink;
{$mode ObjFPC}{$H+}
interface
uses Classes, SysUtils,math;
  const INSERTIONTHRESHOLD=33;// 33 is an magic number
TYPE
  generic TCodaMinaSortableLink<T>=class
  type
    TClearFunc = procedure (AValue: T);
    tCompFunc = function(A,B:T):integer;
    ppnode = ^pnode;
    pnode = ^noderec;
    noderec =record
  	 data:T;
  	 next:pnode;
    end;
  private
    head,tail,cur:pnode;
    cmp:tCompFunc;
    Scavenger:TClearFunc;
    printer:TClearFunc;
  protected
    function SortedMerge(a, b:pnode):pnode;
    procedure FrontBackSplit(source:pnode; frontRef, backRef:ppnode);
    procedure printList(node:pnode);
    procedure push(head_ref:ppnode;new_data:T);
    procedure MergeSort(headRef:ppnode);
    function linklength(current:pnode):integer;
    function IterativeMergeSort(list:pnode;is_circular,is_double:integer):pnode;
    procedure swap(a,b:pnode);
  public
    constructor create(compare:tCompFunc=nil;lScavenger:TClearFunc=nil;lprint:TClearFunc=nil);
    destructor destroy();
    procedure add(val:T);
    procedure LockFreeadd(val:T);
    procedure MergeSort();
    procedure IterativeMergeSort();
    function starIterative():T;
    function next():T;
    procedure printLink();
  end;
implementation


constructor TCodaMinaSortableLink.create(compare:tCompFunc=nil;lScavenger:TClearFunc=nil;lprint:TClearFunc=nil);
begin
  head:=nil;
  tail:=nil;
  pool:=nil;
  count:=0;
  cmp:=compare;
  Scavenger:= lScavenger;
  printer:=lprint;
end;
destructor TCodaMinaSortableLink.destroy();
var
  tmp:pnode;
begin
  clear();
  while head<>nil do
  begin
    tmp:=head;
    head:=head^.next;
    freemem(tmp);
  end;
  inherited;
end;
procedure TCodaMinaSortableLink.clear();
var
  tmp:pnode;
begin
  if Scavenger<>nil then
	begin
    while head<>nil do
    begin
      tmp:=head;
      head:=head^.next;
      Scavenger(tmp^.data);
    end;
	end;
  pool:=head;
  head:=nil;
  tail:=nil;
  count:=0;
end;
function TCodaMinaSortableLink.starIterative():T;
begin
  cur:=head;
  if cur<>nil then
  begin
    result:=cur^.data;
  end
  else
  begin
    result:=default(T);
  end;
end;
function TCodaMinaSortableLink.next():T;
begin
  if cur=nil then
  begin
    cur:=head;
  end
  else
  begin
    cur:=cur^.next;
  end;
  if cur<>nil then
  begin
    result:=cur^.data;
  end
  else
  begin
    result:=default(T);
  end;
end;

procedure TCodaMinaSortableLink.printLink();
begin
  printList(head);
end;

procedure TCodaMinaSortableLink.add(val:T);
var
  node:pnode;
begin
	node := allocmem(sizeof(noderec));
	if node=nil then exit;
	node^.data := val; 
	node^.next := nil;
	if head=nil then
	begin
	  head:=node;
	  tail:=head;
	end
	else
	begin
	  tail^.next:=node;
	  tail:=node;
	end;
end;
procedure TCodaMinaSortableLink.LockFreeadd(val:T);
var
  node,old_next:pnode;
begin
	node := allocmem(sizeof(noderec));
	if node=nil then exit;
	node^.data := val; 
	node^.next := nil;
	if (InterlockedCompareExchange(tail, node, nil)=nil) then
	begin
	 head:=tail;
	end
	else
	begin
  	while (true) do
  	begin
  		node^.next := tail^.next;
  		old_next := tail^.next;
  		if (InterlockedCompareExchange(tail^.next, node, old_next)=old_next) then
  		begin
  			break;
  		end;
  	end;
	end;
end;
{ sorts the linked list by changing next pointers (not data) }
procedure TCodaMinaSortableLink.MergeSort();
begin
  MergeSort(@head);
end;

procedure TCodaMinaSortableLink.MergeSort(headRef:ppnode);
var
  mhead,a,b:pnode; 
begin
  mhead := headRef^;  
  { Base case -- length 0 or 1 }
  if ((mhead = nil) or (mhead^.next = nil)) then 
  begin
    exit; 
  end;
  
  { Split head into 'a' and 'b' sublists }
  FrontBackSplit(mhead, @a, @b); 
  
  { Recursively sort the sublists }
  MergeSort(@a); 
  MergeSort(@b); 
  
  { answer = merge the two sorted lists together }
  headRef^ := SortedMerge(a, b); 
end;
  
{ See https:// www.geeksforgeeks.org/?p=3622 for details of this  
function }
function TCodaMinaSortableLink.SortedMerge(a, b:pnode):pnode; 
begin
  result := nil; 
  
  { Base cases }
  if (a = nil)  then
    exit (b) 
  else 
  if (b = nil) then 
    exit (a); 
  
  { Pick either a or b, and recur }
  if (cmp(a^.data , b^.data)<=0) then
  begin
    result := a; 
    result^.next := SortedMerge(a^.next, b); 
  end
  else 
  begin
    result := b; 
    result^.next := SortedMerge(a, b^.next); 
  end; 
end;
procedure TCodaMinaSortableLink.IterativeMergeSort();
begin
  head:=IterativeMergeSort(head,0,0);
end;
function TCodaMinaSortableLink.IterativeMergeSort(list:pnode;is_circular,is_double:integer):pnode;
var
  p,q,e,ltail,oldhead:pnode;
  insize, nmerges, psize, qsize, i:integer;
begin
    //*
    //* Silly special case: if `list' was passed in as nil, return
    //* nil immediately.
    //*/
    if (list=nil) then
	  exit(nil);

    insize := 1;

    while (true) do
    begin
        p := list;
	      oldhead := list;		       //* only used for circular linkage */
        list := nil;
        ltail := nil;

        nmerges := 0;  //* count number of merges we do in this pass */

        while (p<>nil) do
        begin
            inc(nmerges);  //* there exists a merge to be done */
            //* step `insize' places along from p */
            q := p;
            psize := 0;
            for i := 0 to insize -1 do 
            begin
                inc(psize);
		            if (is_circular<>0) then
		            begin
		              if q^.next = oldhead then
		              begin
		                q:=nil;
		              end
		              else
		              begin
		                q:=q^.next;
		              end;
		            end
		            else
		            begin
		              q := q^.next;
		            end;
                if (q=nil) then 
                  break;
            end;

            //* if q hasn't fallen off end, we have two lists to merge */
            qsize := insize;

            //* now we have two lists; merge them */
            while (psize > 0) or ((qsize > 0) and (q<>nil)) do
            begin

                //* decide whether next element of merge comes from p or q */
                if (psize = 0) then
                begin
                //* p is empty; e must come from q. */
		              e := q; 
		              q := q^.next; 
		              dec(qsize);
		              if (is_circular<>0) and (q = oldhead) then
		                q := nil;
		            end 
		            else 
		            if (qsize = 0) or (q=nil) then
		            begin
		              //* q is empty; e must come from p. */
		              e := p; 
		              p := p^.next; 
		              dec(psize);
		              if (is_circular<>0) and (p = oldhead) then
		                p := nil;
		            end 
		            else 
		            if (cmp(p^.data,q^.data) <= 0) then
		            begin
		            //* First element of p is lower (or same);
		            //* e must come from p. */
		              e := p; 
		              p := p^.next; 
		              dec(psize);
		              if (is_circular<>0) and (p = oldhead) then
		                p := nil;
		            end 
		            else 
		            begin
		              //* First element of q is lower; e must come from q. */
		              e := q; 
		              q := q^.next; 
		              dec(qsize);
		              if (is_circular<>0) and (q = oldhead) then
		                q := nil;
		            end;

                //* add the next element to the merged list */
		            if (ltail<>nil) then
		            begin
		              ltail^.next := e;
		            end 
		            else 
		            begin
		              list := e;
		            end;
		            //if (is_double<>0) then
		            //begin
		            //  //* Maintain reverse pointers in a doubly linked list. */
		            //  e^.prev := ltail;
		            //end;
		            ltail := e;
            end;

            //* now p has stepped `insize' places along, and q has too */
            p := q;
        end;
	      if (is_circular<>0) then
	      begin
	        ltail^.next := list;
	        //if (is_double) then
		      //  list^.prev := ltail;
	      end 
	      else
	      begin
	        ltail^.next := nil;
        end;
        //* If we have done only one merge, we're finished. */
        if (nmerges <= 1)  then //* allow for nmerges==0, the empty list case */
            exit(list);

        //* Otherwise repeat, merging lists twice the size */
        insize :=insize * 2;
    end;
end;

{ UTILITY FUNCTIONS }
{ Split the nodes of the given list into front and back halves, 
    and return the two lists using the reference parameters. 
    If the length is odd, the extra node should go in the front list. 
    Uses the fast/slow pointer strategy. }
procedure TCodaMinaSortableLink.FrontBackSplit(source:pnode; frontRef, backRef:ppnode);
var
  fast,slow:pnode; 
begin 
  slow := source; 
  fast := source^.next; 
  
  { Advance 'fast' two nodes, and advance 'slow' one node }
  while (fast <> nil) do
  begin
    fast := fast^.next; 
    if (fast <> nil) then
    begin
      slow := slow^.next; 
      fast := fast^.next; 
    end;
  end;
  
  { 'slow' is before the midpoint in the list, so split it in two 
  at that point. }
  frontRef^  := source; 
  backRef^   := slow^.next; 
  slow^.next := nil; 
end;
  
{ Function to print nodes in a given linked list }
procedure TCodaMinaSortableLink.printList(node:pnode); 
begin
  while (node <> nil) do
  begin
    printer(node^.data);
    node := node^.next; 
  end;
end;
  
{ Function to insert a node at the beginging of the linked list }
procedure TCodaMinaSortableLink.push(head_ref:ppnode;new_data:T);
var
  new_node:pnode;
begin
  { allocate node }
  new_node := allocmem(sizeof(noderec));
  
  { put in the data }
  new_node^.data := new_data; 
  
  { link the old list off the new node }
  new_node^.next := head_ref^; 
  
  { move the head to point to the new node }
  head_ref^ := new_node; 
end;

//=========Iterative MergeSort============
//* Function to calculate length of linked list */
function TCodaMinaSortableLink.linklength(current:pnode):integer;
var
  count:integer;
begin
  count := 0; 
  while (current <> Nil) do
  begin 
    current := current^.next; 
    inc(count); 
  end;
  result := count; 
end;
  
{ Merge function of Merge Sort to Merge the two sorted parts 
   of the Linked List. We compare the next value of start1 and  
   current value of start2 and insert start2 after start1 if  
   it's smaller than next value of start1. We do this until 
   start1 or start2 end. If start1 ends, then we assign next  
   of start1 to start2 because start2 may have some elements 
   left out which are greater than the last value of start1.  
   If start2 ends then we assign end2 to end1. This is necessary 
   because we use end2 in another function (mergeSort function)  
   to determine the next start1 (i.e) start1 for next 
   iteration = end2->next }
procedure TCodaMinaSortableLink.swap(a,b:pnode);
var
  tmp:T; 
begin
   tmp := a^.data; 
  a^.data := b^.data; 
  b^.data := tmp; 
end;
end.
