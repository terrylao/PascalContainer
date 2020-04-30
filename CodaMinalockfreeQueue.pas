Unit CodaMinalockfreeQueue;
interface

uses
  Classes, SysUtils, math ;

type
  generic TCodaMinalockfreeQueue<T>=class
  type

  pnode = ^noderec;
  noderec =record
	 data:T;
	 next:pnode;
  end;
  proot=^rootrec;
  rootrec = record
	 head,tail:pnode;
	 size:cardinal;
  end;
  private
    root:proot;
  public
    constructor create();
    function add(val:T):integer;
    function get:T;
    function getsize():cardinal;
  end;
implementation
constructor TCodaMinalockfreeQueue.create();
begin
	root := allocmem(sizeof(rootrec));
  if (root = nil) then
  begin
    exit;
  end;
	root^.head := allocmem(sizeof(noderec)); { Sentinel node }
	root^.tail := root^.head;
	root^.head^.data := default(T);
	root^.head^.next := nil;
end;
function TCodaMinalockfreeQueue.getsize():cardinal;
begin
  result:=root^.size;
end;
function TCodaMinalockfreeQueue.add(val:T):integer;
var
  n,node:pnode;
begin
	node := allocmem(sizeof(noderec));
	node^.data := val; 
	node^.next := nil;
	n := root^.tail;
	while true do
	begin
		if (InterlockedCompareExchange(n^.next, node, nil)<>nil) then
		begin
		  inc(root^.size);
			break;
		end 
		else 
		begin
			InterlockedCompareExchange(root^.tail, n^.next, n);
		end;
	end;
	InterlockedCompareExchange(root^.tail, node, n);
  
	result := 1;
end;

function TCodaMinalockfreeQueue.get:T;
var
  n:pnode;
  val:T;
begin
  n := root^.head;
	while true do
	begin
		if (n^.next = nil) then
    begin
      exit(default(T));
		end;

		if (InterlockedCompareExchange(root^.head, n^.next, n)<>nil) then
		begin
			break;
		end;
	end;
	val := n^.next^.data;
	freemem(n);
	dec(root^.size);
	result := val;
end;
end.
