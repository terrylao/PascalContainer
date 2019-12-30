program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CodaMinaHashMap,CodaMinaPriorityQueue,
  CodaMinaTTree,CodaMinaBTree,CodaMinaBPlusTree,CodaMinaBStarTree;
type
  ahashmap=specialize TCodaMinaHashMap<string,integer>;
  bhashmap=specialize TCodaMinaHashMap<string,string>;
  ihashmap=specialize TCodaMinaHashMap<integer,integer>;
  icodaminahashmap=specialize TCodaMinaHashMap<integer,integer>;
  iqueue  =specialize TCodaMinaPriorityQueue<integer>;
  itree   =specialize TCodaMinaTTree<Integer,Integer>;
  ibtree   =specialize TCodaMinaBTree<Integer,Integer>;
  ibptree   =specialize TCodaMinaBPlusTree<Integer,Integer>;
  ibstree   =specialize TCodaMinaBStarTree<Integer,Integer>;
procedure hashmaptest;
var
hashmap:ahashmap;
shashmap:bhashmap;
sihashmap:ihashmap;
begin
    //my hashmap test
    hashmap:=ahashmap.Create;
    shashmap:=bhashmap.Create;
    sihashmap:=ihashmap.Create;
    sihashmap.Add(1,1);
    sihashmap.Add(100,100);
    sihashmap.Add(1030570,1000);
    shashmap.Add('One','Oh');
    shashmap.Add('Two','Yeah');
    hashmap.add('One',1);
    hashmap.add('Two',2);
    hashmap.add('Three',3);
    writeln(stdout,'Three=',hashmap.GetValue('Three'));
    writeln(stdout,'Two=',shashmap.GetValue('Two'));
    writeln(stdout,'Four=',hashmap.GetValue('Four'));
    writeln(stdout,'1030570=',sihashmap.GetValue(1030570));
end;
function cmp(a,b:integer):integer;
begin
  result:=a-b;
end;
procedure BSTreePerformanceTest;
var
   mybstree:ibstree;
   mybptree:ibptree;
   mybtree:ibtree;
   datas,velidater:array of integer;
   deletedata:array of integer;
   i,j,iindex,dindex,keys:integer;
   NTickInitial,NTickShowEnd: QWord;
begin
   keys:=10;
   mybstree:=ibstree.create(@cmp,keys);
   mybptree:=ibptree.create(@cmp,keys);
   mybtree:=ibtree.create(@cmp,keys);
   setlength(datas,20000);
   setlength(deletedata,20000);
   setlength(velidater,60000);
   //fillchar(velidater,40000*sizeof(integer),0);
   Randomize;
   iindex:=0;
   dindex:=0;
   for i:=0 to 40000 do
   begin
     j:=Random(30000)+1;
     if (velidater[j]=1) then
     begin
       deletedata[dindex]:=j;
       //writeln(StdOut,'delete:',j);
       dindex:=dindex+1;
       velidater[j]:=2;
     end
     else
     if (velidater[j]=0) then
     begin
          velidater[j]:=1;
          datas[iindex]:=j;
          iindex:=iindex+1;
          //writeln(StdOut,'inserted:',j);
     end;
     if iindex>19999 then
        break;
   end;
   writeln(StdOut,Format('key count: %d keys', [iindex]));
   writeln(StdOut,Format('delete count: %d keys', [dindex]));
   NTickInitial:= GetTickCount64;
   for i:=0 to iindex do
   begin
     mybstree.searchNodeInsert(datas[i],datas[i]+1);
   end;
   //mybstree.printtree();
   for i:=0 to iindex do
   begin
     if mybstree.search(datas[i])<>datas[i]+1 then
     begin
          writeln(StdOut,'search fail:',datas[i]);
          break;
     end;
   end;
   //mybstree.printtree();
   j:=0;
   for i:=0 to dindex-1 do
   begin
     //writeln(StdOut,'delete:',deletedata[i]);
     if mybstree.delete(deletedata[i])=true then
     begin
       j:=j+1;
     end
     else
     begin
       writeln(stdout,'delete fail:',deletedata[i]);
     end;
   end;
   //mybstree.printtree();
   writeln(stdout,'B*Tree deleted:',j);
   NTickShowEnd:= GetTickCount64;
   writeln(StdOut,Format('B*Tree finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
   NTickInitial:= GetTickCount64;
   for i:=0 to iindex do
   begin
     mybptree.searchNodeInsert(datas[i],datas[i]+1);
   end;
   //mybptree.printtree();
   for i:=0 to iindex do
   begin
     if mybptree.search(datas[i])<>datas[i]+1 then
     begin
          writeln(StdOut,'search fail:',datas[i]);
          break;
     end;
   end;
   j:=0;
   for i:=0 to dindex-1 do
   begin
     if mybptree.delete(deletedata[i])=true then
     begin
       j:=j+1;
     end
     else
     begin
       writeln(stdout,'delete fail:',deletedata[i]);
     end;
   end;
   //mybptree.printtree();
   writeln(stdout,'B+Tree deleted:',j);
   NTickShowEnd:= GetTickCount64;
   writeln(StdOut,Format('B+Tree finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
   NTickInitial:= GetTickCount64;
   for i:=0 to iindex do
   begin
     mybtree.searchNodeInsert(datas[i],datas[i]+1);
   end;
   //mybtree.printtree();
   for i:=0 to iindex do
   begin
     if mybtree.search(datas[i])<>datas[i]+1 then
     begin
          writeln(StdOut,'search fail:',datas[i]);
          break;
     end;
   end;
   j:=0;
   for i:=0 to dindex-1 do
   begin
     if mybtree.delete(deletedata[i])=true then
     begin
       j:=j+1;
       //writeln(StdOut,'delete:',deletedata[i]);
     end
     else
     begin
       writeln(stdout,'delete fail:',deletedata[i]);
     end;
   end;
   //mybtree.printtree();
   writeln(stdout,'B-Tree deleted:',j);
   NTickShowEnd:= GetTickCount64;
   writeln(StdOut,Format('B-Tree finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
end;
var
   i:integer;
   NTickInitial,NTickShowEnd: QWord;
begin
  NTickInitial:= GetTickCount64;
  BSTreePerformanceTest;
  NTickShowEnd:= GetTickCount64;
  writeln(StdOut,Format('TimerIdleTick: finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
  WriteLn(StdOut,'Waiting until a key is pressed');
end.

