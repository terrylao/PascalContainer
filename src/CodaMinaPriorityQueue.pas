{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaPriorityQueue;

 {$mode ObjFPC}{$H+}
interface

type

     generic TCodaMinaPriorityQueue<T>=class
      type
         TQueueNode=record
          priority:Integer;//higher number get higher priority
          data:T;
         end;
      private
          nodes:array of TQueueNode;
          len,size:Integer;
      protected
      public
        constructor Create;
        procedure push(priority:integer; data:T);
        function pop():T;
     end;

implementation
constructor TCodaMinaPriorityQueue.Create;
begin
  size:=0;
  len:=0;
end;
procedure TCodaMinaPriorityQueue.push(priority:integer; data:T);
var
  i,j:integer;
begin
    if (len + 1 >= size) then
    begin
      if size>0 then
        size  :=size * 2
      else
        size  :=4;
      setlength(nodes,size);
    end;
    i := len + 1;
    j := i div 2;
    while (i > 1) and (nodes[j].priority < priority) do
    begin
        nodes[i] := nodes[j];
        i := j;
        j := j div 2;
    end;
    nodes[i].priority := priority;
    nodes[i].data     := data;
    inc(len);
end;
 
function TCodaMinaPriorityQueue.pop():T;
var
  i, j, k:integer;
  data:T;
begin
    if len=0 then
    begin
        exit (default(T));
    end;
    data := nodes[1].data;
 
    nodes[1] := nodes[len];
 
    dec(len);
 
    i := 1;
    while (i<>len+1) do
    begin
        k := len+1;
        j := 2 * i;
        if (j <= len) and (nodes[j].priority > nodes[k].priority) then
        begin
            k := j;
        end;
        if (j + 1 <= len) and (nodes[j + 1].priority > nodes[k].priority) then
        begin
            k := j + 1;
        end;
        nodes[i] := nodes[k];
        i := k;
    end;
    result:= data;
end;
 
  
end.
