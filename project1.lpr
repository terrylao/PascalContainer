program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils,
  CodaMinaHashMap,CodaMinaPriorityQueue,
  CodaMinaTTree,CodaMinaBTree,CodaMinaBPlusTree,CodaMinaBStarTree,CodaMinaSkipList2
  ,CodaMinaAVLTree,CodaMinaRBTree,CodaMinaQuadtree,CodaMinalockfreeQueue,genericCodaMinaSortableLink,genericCodaMinaSort;
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
  TCMHM = specialize TCodaMinaHashMap<string, integer>;
  icavl=specialize TCodaMinaAVLTree<Integer>;
  irbtree= specialize TCodaMinaRBTree<Integer>;
  sqdtree= specialize TCodaMinaQuadTree<string>;
  ilfqueue= specialize TCodaMinalockfreeQueue<Integer>;
  ilinksort  = specialize TCodaMinaSortableLink<Integer>;
  iarraysort = specialize TCodaMinaArraySortFunction<Integer>;
  TThreadQueue = class(TThread)
private
  aqueue:ilfqueue;
  r:int32;
protected
  procedure Execute; override;
public
  constructor Create(qq:ilfqueue);
  destructor Destroy; override;
end;
constructor TThreadQueue.Create(qq:ilfqueue);
begin
  inherited Create(true);
  aqueue:=qq;
  freeonterminate:=true;
  r:=Random(10000);
end;
destructor TThreadQueue.Destroy;
begin
  inherited;
end;
procedure TThreadQueue.Execute;
var
  i:integer;
begin

  //while not Terminated do
  //begin
       writeln(stdout,self.ThreadID,'=thread start:',r);
       for i:=r to r+10 do
       begin
            aqueue.add(i);
            sleep(30);
       end;
       writeln(stdout,self.ThreadID,'=thread add done:',aqueue.getsize());
       for i:=r to r+10 do
       begin
            writeln(stdout,self.ThreadID,'=get:',aqueue.get());
       end;
       writeln(stdout,'thread done.');
  //end;
end;

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
    sihashmap.destroy();
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
     mybstree.add(datas[i],datas[i]+1);
   end;
   //mybstree.printtree();
   for i:=0 to iindex do
   begin
     if mybstree.find(datas[i])<>datas[i]+1 then
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
     mybptree.add(datas[i],datas[i]+1);
   end;
   //mybptree.printtree();
   for i:=0 to iindex do
   begin
     if mybptree.find(datas[i])<>datas[i]+1 then
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
     mybtree.add(datas[i],datas[i]+1);
   end;
   //mybtree.printtree();
   for i:=0 to iindex do
   begin
     if mybtree.find(datas[i])<>datas[i]+1 then
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
//
procedure testsortInteger;
var
   arr:iarraysort;
   basedata:array of Integer;
   data,temp:array of Integer;
   i,max:integer;
   NTickInitial,NTickShowEnd,NTickShowEnd2: QWord;
   p:ppointer;
   pb:pbyte;
begin
  max:=100000000;
   arr:=iarraysort.Create();
   setlength(data, max);
   setlength(basedata, max);
   setlength(temp, max);
   Randomize;
   writeln(stdout,'The data before sorting:');
   for i := low(data) to high(data) do
   begin
     basedata[i] := random(100000000);
     data[i]:=basedata[i];
     //write(stdout,data[i]:8);
   end;
   p:=@basedata[0];
   pb:=@basedata[0];
   //** -O3 10M integer, DualPivotQuickSort 1680 > quicksort3PivotBasic 1700 > quicksort 1770 > IterativequickSort 1800 > mergesort 2260 >  Iterativemergesort 3120
   //** -O3 100M intger, generic quicksort 20540ms, generic mergesort 26520ms
   NTickInitial:= GetTickCount64;
   arr.quicksort(@data[0],low(data) , high(data),@cmp);
   NTickShowEnd:= GetTickCount64;
   arr.mergesort(@basedata[0],low(basedata) , high(basedata),@cmp);
   //arr.DualPivotQuickSort(@basedata[0],low(basedata) , high(basedata),@cmp);//when -O3 10M =1680ms optimize will faster than Quicksort,quicksort3PivotBasic
   //arr.quicksort3PivotBasic(@basedata[0],low(basedata) , high(basedata),@cmp);//when -O3 10M =1700ms  optimize will faster than Quicksort
   //arr.radix_sort(@basedata[0],@temp[0],high(basedata)+1,@radixshr);
   NTickShowEnd2:= GetTickCount64;
   writeln(StdOut,Format('first Sort: finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
   writeln(StdOut,Format('second Sort: finished: %dms', [(NTickShowEnd2-NTickShowEnd) div 10 * 10]));
   for i := low(data)+1 to high(data) do
   begin
     if data[i]<data[i-1] then
     begin
       writeln(stdout,'**data check broken!',i);
        break;
     end;
   end;
   for i := low(basedata)+1 to high(basedata) do
   begin
     if basedata[i]<basedata[i-1] then
     begin
       writeln(stdout,'**basedata check broken!',i);
        break;
     end;
   end;
   //writeln(stdout,'');
   //writeln(stdout,'The data after sorting:');
   //for i := low(data) to high(data) do
   //begin
   //  write(stdout,data[i]:8);
   //end;
   //writeln(stdout,'');
end;
procedure testsortlink;
var
   arr,arr1,arr2:ilinksort;
   i,j:integer;
   NTickInitial,NTickShowEnd,NTickShowEnd2,NTickShowEnd3: QWord;
begin
   arr:=ilinksort.Create(@cmp);
   arr1:=ilinksort.Create(@cmp);
   arr2:=ilinksort.Create(@cmp);
   Randomize;
   writeln(stdout,'The data before link sorting:');
   for i := 0 to 100000 do
   begin
     j:=Random(99999999);
     arr.add(j);
     arr1.add(j);
     arr2.add(j);
   end;
   NTickInitial:= GetTickCount64;
   arr.IterativeMergeSort();
   NTickShowEnd:= GetTickCount64;
   arr1.MergeSort();
   NTickShowEnd2:= GetTickCount64;
   //arr2.IterativeMergeSort();
   //NTickShowEnd3:= GetTickCount64;
   writeln(StdOut,Format('first Sort: finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
   writeln(StdOut,Format('second Sort: finished: %dms', [(NTickShowEnd2-NTickShowEnd) div 10 * 10]));
   //writeln(StdOut,Format('third Sort: finished: %dms', [(NTickShowEnd3-NTickShowEnd2) div 10 * 10]));
   i:=arr.starIterative();
   while i>0 do
   begin
     j:=arr.next();
     if i>j then
     begin
        writeln(stdout,'arr broken:',i,',',j);
        break;
     end;
     i:=j;
   end;
   i:=arr1.starIterative();
   while i>0 do
   begin
     j:=arr1.next();
     if i>j then
     begin
        writeln(stdout,'arr1 broken:',i,',',j);
        break;
     end;
     i:=j;
   end;
   //i:=arr2.starIterative();
   //while i>0 do
   //begin
   //  j:=arr2.next();
   //  if i>j then
   //  begin
   //     writeln(stdout,'arr2 broken:',i,',',j);
   //     break;
   //  end;
   //  i:=j;
   //end;
end;
procedure quadtreetest();
var
   t:sqdtree;
begin
  t:=sqdtree.create(1, 1, 10, 10);
  writeln(stdout,t.insert(0,0,'at 0,0'));
  writeln(stdout,t.insert(110.0,110.0,'at 110,110'));
  writeln(stdout,t.insert(8.0,2.0,'at 8,2'));
  writeln(stdout,'failed insertion:     ',t.insert(0.0, 1.0, '1')    ); { failed insertion=0      }
  writeln(stdout,'normal insertion:     ',t.insert(2.0, 3.0, '12')   ); { normal insertion=1      }
  writeln(stdout,'replacement insertion:',t.insert(2.0, 3.0, '123')  ); { replacement insertion=2 }
  writeln(stdout,'tree length:', t.getLength());//result=2
  writeln(stdout,'normal insertion:     ',t.insert(3.0, 1.1, '31.1')   );
  writeln(stdout,'tree length:', t.getLength());//result=3
  writeln(stdout,'tree search:',t.search( 3.0, 1.1));//result=3.0
  t.printtree();
end;

var
   i:integer;
   NTickInitial,NTickShowEnd: QWord;
   cm: TCMHM;
   biavl:icavl;
   airbtree:irbtree;
   queuethread:TThreadQueue;
   lfqueue:ilfqueue;
begin
  randomize;
  NTickInitial:= GetTickCount64;
  //BSTreePerformanceTest;
  //hashmaptest;
  //cm := TCMHM.create;
  //cm.add('abcdefgh', 123);
  //cm.add('abcdefghijklmnopq', 123456);
  //writeln(stdout,cm['abcdefgh'], ' ', cm['abcdefghijklmnopq']);
  //cm.free;
  //sList :=  iskiplist.Create(@cmp);
  //for i:=0 to 100 do
  //begin
  //  sList.Insert(i,i);
  //end;
  //if sList.Search(9,i) then
  //begin
  //  writeln(stdout,'9=',i);
  //end
  //else
  //begin
  //     writeln(stdout,'9=not found');
  //end;
  //if sList.Search(109,i) then
  //begin
  //  writeln(stdout,'109=',i);
  //end
  //else
  //begin
  //  writeln(stdout,'109=not found');
  //end;

  //--concurrent hash
  //accihash:=cciHash.Create(10);
  //for i:=1 to 2 do
  //begin
  //  hashthread:=TThreadHash.Create(accihash);
  //  hashthread.Start;
  //end;

  //--AVL Tree
  //biavl:=icavl.create(@cmp);
  //for i:=10 downto 1 do
  //    biavl.Add(i);
  //biavl.printtree();
  //--RedBlack Tree
  //airbtree:=irbtree.create(@cmp);
  //for i:=10 downto 1 do
  //    airbtree.Add(i);
  //airbtree.printtree();
  //quadtreetest();
  //--concurrent queue
  lfqueue:=ilfqueue.Create();
  for i:=1 to 2 do
  begin
    queuethread:=TThreadQueue.Create(lfqueue);
    queuethread.Start;
  end;
  NTickShowEnd:= GetTickCount64;
  writeln(StdOut,Format('TimerIdleTick: finished: %dms', [(NTickShowEnd-NTickInitial) div 10 * 10]));
  WriteLn(StdOut,'Waiting until a key is pressed');
  readln;
  //writeln(stdout,' hash size:',accihash.getsize());
end.

