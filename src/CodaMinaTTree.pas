{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}
unit CodaMinaTTree;

 {$mode ObjFPC}{$H+}{$BITPACKING ON}{$GOTO ON}
 {$define debug}  
interface


  const 
       side2BFC:array [0..1] of integer= ( -1, 1 );

type

  {$ifdef CPU64}
    sizeint=uint64;
  {$else}
    sizeint=cardinal;
  {$endif}

  TNODETYPE=(
    TNODE_UNDEF := -1, {< T*-tree node side is undefined }
    TNODE_LEFT,       {< Left side }
    TNODE_RIGHT,      {< Right side }
    TNODE_BOUND,
    TNODE_ROOT
  );
  
  generic TCodaMinaTTree<TKEY,TVALUE>=class
    type
      TClearFunc=procedure (value:TVALUE);
      ttree_cmp_func=function(key1, key2:TKEY):integer;
      
      ptreeNode=^TtreeNode;
      tnode_print_func=procedure(key:TKEY);
      pptreeNode=^ptreeNode;
      {*
       * @brief T*-tree structure
       }
      ptree=^TtreeRec;
      TtreeRec=record
        root:ptreeNode;            //*< A pointer to T*-tree root node 
        keys_per_tnode:integer;         //*< Number of keys per each T-tree node 
        keys_are_unique:boolean;//* The field is true if keys in a tree supposed to be unique
        cmp_func:ttree_cmp_func;
        printfn:tnode_print_func;
	Scavenger:TClearFunc;
      end;
      TtreeNode=record
        parent:ptreeNode;     //*< Pointer to node's parent }
        successor:ptreeNode;  //*< Pointer to node's soccussor for T-tree}
        max_idx     :Integer;  //*< Index of maximum item in node's array }
        bfc         :Integer;   //*< Node's balance factor }
        side :TNODETYPE;  //*< Node's side of parent(TNODE_LEFT, TNODE_RIGHT or TNODE_ROOT) }
        keys:array of TKEY;
        data:array of TVALUE;
        case integer of
          0: (sides:array [0..1] of ptreeNode);
          1: (left,right:ptreeNode);   //*< Pointer to node's left child,right child  }
        end;
    private
      procedure fixup_after_deletion(n:ptreeNode);
      function deleteKeyNode(tnode:ptreenode;idx:integer):TVALUE;
      function searchInNode(key:TKEY;idx:pinteger):ptreenode;
      function createNewNode(pnode:pptreeNode;parent:ptreeNode;key:Tkey;value:Tvalue;side:TNODETYPE):boolean;
      function allocatenode():ptreenode;
      procedure fixup_after_insertion(n:ptreeNode);
      function isHalfLeaf(tnode:ptreeNode):boolean;
      function isInternalNode(node:ptreeNode):boolean;
      function isLeafNode(node:ptreeNode):boolean;
      function binarySearch(tnode:ptreenode; floor, ceil:integer;key:Tkey):integer;
      procedure SingleRotate(target:pptreeNode; side:TNODETYPE);
      procedure doSingleRotate(target:pptreeNode; side:TNODETYPE);
      procedure doubleRotate(target:pptreeNode; side:TNODETYPE);
      procedure rebalance(node:pptreeNode);
      function getBFCDelta(n:ptreenode):integer;
      function tnode_is_full(tnode:ptreeNode):boolean; 
      function getOpside(side:TNODETYPE):TNODETYPE;
      procedure freeNode(n:ptreenode);
      function getEmptyNode():ptreenode;
      procedure printTreeNode(tnode:ptreenode;offs:integer);
    protected
      attree:TtreeRec;
      emptyHead:ttreenode;
    public
      constructor create(cmpf:ttree_cmp_func;np:tnode_print_func;recordcount:integer;lScavenger:TClearFunc=nil);
      procedure printtree();
      function Find(key:TKEY):TVALUE;
      function delete(key:TKEY):boolean;
      function Add(key:TKEY;value:Tvalue):boolean;
  end;
  
implementation
{
 * For more information about T- and T*-trees see:
 * 1) Tobin J. Lehman , Michael J. Carey,
 *    A Study of Index Structures for Main Memory Database Management Systems
 * 2) Kong-Rim Choi , Kyung-Chang Kim,
 *    T*-tree: a main memory database index structure for real time applications
 }


function TCodaMinaTTree.tnode_is_full(tnode:ptreeNode):boolean;
begin
  result:=false;
  if (tnode^.max_idx = aTTree.keys_per_tnode-1) then
    result:=true;
end;

{
 * T-tree has three types of node:
 * 1. Node that hasn't left and right child is called 'leaf node'.
 * 2. Node that has only one child is called 'half-leaf node'
 * 3. Finally, node that has both left and right childs is called 'internal node'
 }
function TCodaMinaTTree.isLeafNode(node:ptreeNode):boolean;
begin
  result:=(node^.left=nil) and (node^.right=nil);
end;
function TCodaMinaTTree.isInternalNode(node:ptreeNode):boolean;
begin
  result:=(node^.left<>nil) and (node^.right<>nil);
end;
function TCodaMinaTTree.isHalfLeaf(tnode:ptreeNode):boolean;
begin
  result:=((tnode^.left=nil) or (tnode^.right=nil)) and not((tnode^.left<>nil) and (tnode^.right<>nil));
end;

function TCodaMinaTTree.getBFCDelta(n:ptreenode):integer;
begin
  result:= 0;
  if n^.side=TNODE_LEFT then
    result:= -1
  else
  if n^.side=TNODE_RIGHT then
    result:= 1;
end;

function TCodaMinaTTree.allocatenode():ptreenode;
begin
  result:= AllocMem(sizeof(ttreenode));
  if result=nil then
    exit(nil);
  
  setlength(result^.keys,aTTree.keys_per_tnode);
  setlength(result^.data,aTTree.keys_per_tnode);
end;

{
 * T-tree node contains keys in a sorted order. Thus binary search
 * is used for internal lookup.
 }
function TCodaMinaTTree.binarySearch(tnode:ptreenode; floor, ceil:integer;key:Tkey):integer;
var
  mid, cmp_res:integer;
begin
    while (floor <= ceil) do
    begin
        mid := (floor + ceil) shr 1;
        cmp_res := aTTree.cmp_func(key, tnode^.keys[mid]);
        if (cmp_res < 0) then
        begin
            ceil := mid - 1;
        end
        else 
        if (cmp_res > 0) then
        begin
            floor := mid + 1;
        end
        else 
        begin
            exit(mid);
        end;
    end;

    {
     * If a key position is not found, save an index of the position
     * where key may be placed to.
     }
    result:=floor-1;
end;

function TCodaMinaTTree.getOpside(side:TNODETYPE):TNODETYPE;
begin
     if side=TNODE_LEFT then
        result:=TNODE_RIGHT
     else
     if side=TNODE_RIGHT then
        result:=TNODE_LEFT;
end;

{
 * generic single rotation procedrue.
 * side := TNODE_LEFT  - Right rotation
 * side := TNODE_RIGHT - Left rotation.
 * 'target' will be set to the new root of rotated subtree.
 }
procedure TCodaMinaTTree.doSingleRotate(target:pptreeNode; side:TNODETYPE);

var
  p, s:ptreeNode;
  opside:TNODETYPE;
begin
    opside := getOpside(side);
    p := target^;
    s := p^.sides[ord(side)];
    s^.side:=p^.side; //tnode_set_side(s, tnode_get_side(p));
    p^.sides[ord(side)] := s^.sides[ord(opside)];
    s^.sides[ord(opside)] := p;
    p^.side:=opside;//tnode_set_side(p, opside);
    s^.parent := p^.parent;
    p^.parent := s;
    if (p^.sides[ord(side)]<>nil) then
    begin
      p^.sides[ord(side)]^.parent := p;
      p^.sides[ord(side)]^.side:=side;//tnode_set_side(p^.sides[side], side);
    end;
    if (s^.parent<>nil) then
    begin
      if (s^.parent^.sides[ord(side)] = p) then
        s^.parent^.sides[ord(side)] := s
      else
        s^.parent^.sides[ord(opside)] := s;
    end;

    target^ := s;
end;

{
 * There are two cases of single rotation possible:
 * 1) Right rotation (side := TNODE_LEFT)
 *         [P]             [L]
 *        /  \            /  \
 *      [L]  x1    :=>   x2   [P]
 *     /  \                 /  \
 *    x2  x3               x3  x1
 *
 * 2) Left rotation (side := TNODE_RIHGT)
 *      [P]                [R]
 *     /  \               /  \
 *    x1  [R]      :=>   [P]   x2
 *       /  \          /  \
 *     x3   x2        x1  x3
 }
procedure TCodaMinaTTree.SingleRotate(target:pptreeNode; side:TNODETYPE);
var
  n:ptreeNode;
begin
    doSingleRotate(target, side);
    n := target^^.sides[ord(getOpside(side))];

    {
     * Recalculate balance factors of nodes after rotation.
     * Let X was a root node of rotated subtree and Y was its
     * child. After single rotation Y is new root of subtree and X is its child.
     * Y node may become either balanced or overweighted to the
     * same side it was but 1 level less.
     * X node scales at 1 level down and possibly it has new child, so
     * its balance should be recalculated too. If it still internal node and
     * its new parent was not overwaighted to the opposite to X side,
     * X is overweighted to the opposite to its new parent side, otherwise it's balanced.
     * If X is either half-leaf or leaf, balance racalculation is obvious.
     }
    n^.bfc := 0;
    if (isInternalNode(n)) then
    begin
      if (n^.parent^.bfc <> side2BFC[ord(side)])  then
        n^.bfc := side2BFC[ord(side)];
    end
    else 
    begin
      if n^.right<>nil then 
        n^.bfc := 1
      else
      if n^.left<>nil then
        n^.bfc := -1;
    end;

    target^^.bfc :=target^^.bfc + side2BFC[ord(getOpside(side))];
end;

{
 * There are two possible cases of double rotation:
 * 1) Left-right rotation: (side = TNODE_LEFT)
 *      [P]                     [r]
 *     /  \                    /  \
 *   [L]  x1                [L]   [P]
 *  /  \          :=>       / \    / \
 * x2  [r]                x2 x4  x3 x1
 *    /  \
 *  x4   x3
 *
 * 2) Right-left rotation: (side = TNODE_RIGHT)
 *      [P]                     [l]
 *     /  \                    /  \
 *    x1  [R]               [P]   [R]
 *       /  \     :=>        / \   / \
 *      [l] x2             x1 x3 x4 x2
 *     /  \
 *    x3  x4
 }
procedure TCodaMinaTTree.doubleRotate(target:pptreeNode; side:TNODETYPE);
var
  opside:TNODETYPE;
  n:ptreeNode;
begin
    opside := getOpside(side);
    n := target^^.sides[ord(side)];

    doSingleRotate(@n, opside);

    {
     * Balance recalculation is very similar to recalculation after
     * simple single rotation.
     }
    n^.sides[ord(side)]^.bfc := 0;
    if (isInternalNode(n^.sides[ord(side)])) then
    begin
      if (n^.bfc = side2BFC[ord(opside)]) then
        n^.sides[ord(side)]^.bfc := side2BFC[ord(side)];
        
    end
    else 
    begin
      if n^.sides[ord(side)]^.right<>nil then
        n^.sides[ord(side)]^.bfc := 1
      else
      if n^.sides[ord(side)]^.left<>nil then
       n^.sides[ord(side)]^.bfc := -1;
    end;

    n := n^.parent;
    doSingleRotate(target, side);
    n^.bfc := 0;
    if (isInternalNode(n)) then
    begin
      if (target^^.bfc = side2BFC[ord(side)]) then
        n^.bfc := side2bfc[ord(opside)] ;
    end
    else 
    begin
      if n^.right<>nil then
        n^.bfc := 1
      else
      if n^.left<>nil then
        n^.bfc := -1;
    end;

    {
     * new root node of subtree is always ideally balanced
     * after double rotation.
     }

    target^^.bfc := 0;
end;

procedure TCodaMinaTTree.rebalance(node:pptreeNode);
label goout;
var
  offs, nkeys,  sum, i:integer;
  imbalancechild:TNODETYPE;
  n:ptreeNode;
begin
    //check if left child or right child make it imbalance
    if node^^.bfc < 0 then
      imbalancechild := TNODE_RIGHT
    else
      imbalancechild := TNODE_LEFT;

    sum := abs(node^^.bfc + node^^.sides[ord(getOpside(imbalancechild))]^.bfc);
    {$ifdef debug}writeln(stdout,'sum:',sum,' imbalancechild:',ord(imbalancechild),' opside:',ord(getOpside(imbalancechild)));{$endif}
    if (sum >= 2) then
    begin
        SingleRotate(node, getOpside(imbalancechild));
        goto goout;
    end;

    doubleRotate(node, getOpside(imbalancechild));

    {
    
    
     * T-tree rotation rules difference from AVL rules in only one aspect.
     * After double rotation is done and a leaf became a new root node of
     * subtree and both its left and right childs are half-leafs.
     * If the new root node contains only one item,so N - 1 items should
     * be moved into it from one of its childs.
     * (N is a number of items in selected child node).
     }
    {$ifdef debug}writeln(stdout,'node^^.max_idx:',node^^.max_idx);{$endif}
    if ( node^^.max_idx = 0) and
        (isHalfLeaf(node^^.left) and isHalfLeaf(node^^.right)) then 
    begin
        {
         * If right child contains more items than left, they will be moved
         * from the right child. Otherwise from the left one.
         }
        //if (node^^.right^.max_idx >= node^^.left^.max_idx) then
        if (sum >= 2) then
        begin
            {
             * Right child was selected. So first N - 1 items will be copied
             * and inserted after parent's first item.
             }
            n := node^^.right;
            nkeys := n^.max_idx+1;
            node^^.max_idx := aTTree.keys_per_tnode - 1;
            {$ifdef debug}writeln(stdout,'Right Special nkeys:',nkeys);{$endif}
            for i:=1 to nkeys do
            begin
              node^^.keys[i]:=n^.keys[i-1];
              node^^.data[i]:=n^.data[i-1];
            end;
            n^.keys[0]:=n^.keys[n^.max_idx];
            n^.data[0]:=n^.data[n^.max_idx];
            n^.max_idx:=0;
        end
        else 
        begin
            {
             * Left child was selected. So its N - 1 items
             * (starting after the min one)
             * will be copied and inserted before parent's single item.
             }
            n := node^^.left;
            nkeys := n^.max_idx;
            node^^.max_idx := aTTree.keys_per_tnode - 1;
            node^^.keys[node^^.max_idx]:=node^^.keys[0];
            node^^.data[node^^.max_idx]:=node^^.data[0];
            {$ifdef debug}writeln(stdout,'Left Special nkeys:',nkeys);{$endif}
            for i:=0 to nkeys-1 do
            begin
              node^^.keys[i]:=n^.keys[i+1];
              node^^.data[i]:=n^.data[i+1];
            end;
            n^.max_idx:=0;
        end;
    end;

goout:
    if (aTTree.root^.parent<>nil) then // rebalance at root node
    begin
        aTTree.root := node^;
    end;
end;

constructor TGenericTTree.create(cmpf:ttree_cmp_func;np:tnode_print_func;recordcount:integer;lScavenger:TClearFunc=nil);
begin
  aTTree.root := nil;
  aTTree.keys_per_tnode := recordcount;
  aTTree.cmp_func := cmpf;
	aTTree.Scavenger:=lScavenger;
  aTTree.printfn:=np;
  aTTree.keys_are_unique := true;
  emptyHead.successor:=nil;
end;
function TCodaMinaTTree.Find(key:TKEY):TVALUE;
var
  n:ptreeNode;
  cmp_res, idx, c,i:integer;
  side:TNODETYPE;
  item:TVALUE;
begin
  side:= TNODE_BOUND;
  item := default(TVALUE);
  n := aTTree.root;
  idx := 0;
  if (n=nil) then
  begin
    exit(item);
  end;
  {$ifdef debug}writeln(stdout,'search:',key);{$endif}
  while (n<>nil) do
  begin
      cmp_res := aTTree.cmp_func(key, n^.keys[0]);
      if (cmp_res < 0) then
      begin
          side := TNODE_LEFT;
      end
      else 
      if (cmp_res > 0) then
      begin
        side := TNODE_RIGHT;
        cmp_res := aTTree.cmp_func(key, n^.keys[n^.max_idx]);
        //smaller than, found/insert here, remove the smallest for next search
        if cmp_res<0 then
        begin
            {$ifdef debug}writeln(stdout,'search in node high_bound:',n^.max_idx - 1);{$endif}
            idx := binarySearch(n, 1, n^.max_idx - 1,key);
            {$ifdef debug}writeln(stdout,'search in node at:',idx);{$endif}
            if attree.cmp_func(key,n^.keys[idx])=0 then
            begin
              //replace item
              {$ifdef debug}writeln(stdout,'found:',idx);{$endif}
              item:=n^.data[idx];
            end;
            exit(item);
        end
        else//equals to max key, key is found, it is here
        begin
          item := n^.data[n^.max_idx];
          exit(item);
        end;
      end
      else 
      begin // equal to smallest key, key is found, search is completed.
        item := n^.data[0];
        exit(item);
      end;

      n := n^.sides[ord(side)];
  end;
end;
function TCodaMinaTTree.searchInNode(key:TKEY;idx:pinteger):ptreenode;
var
  n:ptreeNode;
  cmp_res:integer;
  side:TNODETYPE;
begin
  side:= TNODE_BOUND;
  n := aTTree.root;
  if (n=nil) then
  begin
    exit(nil);
  end;
  {$ifdef debug}writeln(stdout,'searchInNode:',key);{$endif}
  while (n<>nil) do
  begin
      cmp_res := aTTree.cmp_func(key, n^.keys[0]);
      if (cmp_res < 0) then
      begin
          side := TNODE_LEFT;
      end
      else 
      if (cmp_res > 0) then
      begin
        side := TNODE_RIGHT;
        cmp_res := aTTree.cmp_func(key, n^.keys[n^.max_idx]);
        //smaller than, found/insert here, remove the smallest for next search
        if cmp_res<0 then
        begin
            {$ifdef debug}writeln(stdout,'search in node high_bound:',n^.max_idx - 1);{$endif}
            idx^ := binarySearch(n, 1,n^.max_idx - 1,key);
            {$ifdef debug}writeln(stdout,'search in node at:',idx^);{$endif}
            if attree.cmp_func(key,n^.keys[idx^])=0 then
            begin
              //replace item
              {$ifdef debug}writeln(stdout,'found:',idx^);{$endif}
              exit(n);
            end;
            exit(nil);
        end
        else//equals to max key, key is found, it is here
        begin
          idx^:=n^.max_idx;
          exit(n);
        end;
      end
      else 
      begin // equal to smallest key, key is found, search is completed.
        idx^:= 0;
        exit(n);
      end;
      n := n^.sides[ord(side)];
  end;
end;
//
//procedure ttree_destroy(ttree:ptree);
//var
//  tnode,next:ptreenode;
//begin
//
//  if (aTTree.root=nil) then
//    exit;
//  tnode := ttree_node_leftmost(aTTree.root);
//  next := tnode;
//  while (tnode<>nil) do
//  begin
//    next  := tnode^.successor;
//    free(tnode);
//    tnode := next;
//  end;
//
//  aTTree.root := nil;
//end;
{
  root[], max 3 keys
insert: 150,  root[150](0)
insert: 153,  root[150,153](0)
insert: 157,  root[150,153,157](0)
insert: 168,  root[150,153,157](1)
                             \
                             LEAF[168](0)
                             
insert: 143,  root[150,153,157](0)
              /              \
      LEAF[143](0)          LEAF[168](0)
      
insert: 175,  root[150,153,157](0)
              /              \
      LEAF[143](0)          LEAF[168,175](0)
      
insert: 190,  root[150,153,157](0)
              /              \
      LEAF[143](0)          LEAF[168,175,190](0)      
      
insert: 191,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[168,175,190](1)
                                           \
                                         LEAF[191](0)      

insert: 291,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[168,175,190](1)
                                           \
                                         LEAF[191,291](0)


insert: 181,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](0) <<---1. move out 168
                               /            \
                        LEAF[168](0)       LEAF[191,291](0)

======= Story =======
insert: 297,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](0)
                               /            \
                        LEAF[168](0)       LEAF[191,291,297](0)


insert: 407,  root[150,153,157](2)   <<-- rebalance N1 
              /                \
      LEAF[143](0)          NODE[175,181,190](1)  <-- rebalance N2
                               /               \
                        LEAF[168](0)   NODE[191,291,297](1)
                                                            \
                                                          LEAF[407](0) <-- N3 

Single Rebalance: RR TYPE: BFC=2的 NODE 的右子樹的右LEAF 引起不平衡  
N1 replace by N2 then N3 become N1's right child's right child
   
               root[175,181,190](0)
              /                \
     Node[150,153,157](0)      NODE[191,291,297](0)
      /              \                       \
 LEAF[143](0)     LEAF[168](0)                LEAF[407](0)



   
Insert 160:  root[175,181,190](0)
              /                \
     Node[150,153,157](0)      NODE[191,291,297](0)
      /              \                            \
 LEAF[143](0)     LEAF[160,168](0)                LEAF[407](0)


Insert 165:    root[175,181,190](0)
              /                \
     Node[150,153,157](0)      NODE[191,291,297](0)
      /              \                            \
 LEAF[143](0)     LEAF[160,165,168](0)           LEAF[407](0)
 

Insert 169:    root[175,181,190](0)
              /                \
     Node[150,153,157](0)      NODE[191,291,297](0)
      /              \                            \
 LEAF[143](0)     LEAF[160,165,168](0)           LEAF[407](0)
 
Insert 169:    root[175,181,190](-1)
              /                \
     Node[150,153,157](1)      NODE[191,291,297](0)
      /              \                            \
 LEAF[143](0)     LEAF[160,165,168](1)           LEAF[407](0)
                                   \
                               LEAF[169](0)


** from Story **
insert: 169,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](0)
                               /            \
                        LEAF[168,169](0)       LEAF[191,291](0)

insert: 171,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](0)
                               /            \
                LEAF[168,169,171](0)       LEAF[191,291](0)

insert: 165,  root[150,153,157](2) <<--- Rebalance N1
              /              \
      LEAF[143](0)          NODE[175,181,190](-1) <- rebalance N2
                               /            \
                Node[168,169,171](-1)<-N3   LEAF[191,291](0)
                /
      LEAF[165](0) <-N4


Double Rebalance: RL TYPE: BFC=2的 NODE 的右子樹中的左 LEAF 引起不平衡
 step 1: N2 replace by N3, N2 become N3 right child

            root[150,153,157](2) <<--- Rebalance N1
              /              \
      LEAF[143](0)          NODE[168,169,171](1) <- rebalance N2
                               /                \
                       LEAF[165](0) <-N3       Node[175,181,190](1)
                                                    \
                                                   LEAF[191,291](0)

 step 2: N1 replace by N2, N1 become N1 left child, and N3 move to N1's right child's righ child
 
               root[168,169,171](0)
              /                   \
    NODE[150,153,157](0)         Node[175,181,190](1)
       /            \                          \
 LEAF[143](0)     LEAF[165](0)               LEAF[191,291](0)

                                                    
======SPECIAL REBLANCE====
insert: 150,  root[150](0)
insert: 153,  root[150,153](0)
insert: 157,  root[150,153,157](0)

***** another story ****
insert: 168,  root[150,153,157](1)
                             \
                             LEAF[168](0)

insert: 181,  root[150,153,157](1)
                             \
                             LEAF[168,181](0)

insert: 201,  root[150,153,157](1)
                             \
                             LEAF[168,181,201](0)

insert: 167,  root[150,153,157](2) <<-- Rebalance N1
                             \
                             Node[168,181,201](1) <-- N2
                                /
                        LEAF[167](0) <-- N3
                        
Single Rebalance: RL: 
step 1.N1 replace by N3, and N1 become N3 left child and N2 become N3 right child
                   root[167](2) 
              /                    \
     LEAF[150,153,157]         Node[168,181,201](1) <-- N2

step 2. copy N2's KEY(except last one) into N3(after first one),
                root[167,168,181,](2) 
              /                    \
     LEAF[150,153,157]             Node[201](1) <-- N2
                        
***** from anther story ****
insert: 130,  root[150,153,157](1)
                /
       LEAF[130](0)

insert: 145,  root[150,153,157](1)
                /
       LEAF[130,145](0)

insert: 133,  root[150,153,157](1)
                /
       LEAF[130,133,145](0)
       
insert: 146,  root[150,153,157](2) <<-- Rebalance N1
                /
       Node[130,133,145](1) <-- N2
               \
             LEAF[146](0) <-- N3

same as previous, 
step 1.
                  root[146]
             /             \
    LEAF[130,133,145]    LEAF[150,153,157]
    
step 2. copy N2's key (except first ) into N3(after first)
             root[133,145,146](0)
             /             \
    LEAF[130](0)    LEAF[150,153,157](0)
}

function TCodaMinaTTree.Add(key:TKEY;value:Tvalue):boolean;
var
  n,parent:ptreeNode;
  cmp_res, idx, i:integer;
  side:TNODETYPE;
  tmpkey:tkey;
  item:TVALUE;
begin
  {$ifdef debug}writeln(stdout,'Add:',key);{$endif}
  side:= TNODE_BOUND;
  item := default(TVALUE);
  n := aTTree.root;
  parent:=nil;
  idx := 0;
  result:=false;
  if (n=nil) then
  begin
    createNewNode(@aTTree.root,parent,key,value,TNODE_ROOT);
    if aTTree.root<>nil then
    begin
      {$ifdef debug}writeln(stdout,'root ok');{$endif}
    end;
    exit(true);
  end;
  while (n<>nil) do
  begin
    parent:=n;
    cmp_res := aTTree.cmp_func(key, n^.keys[0]);
    if (cmp_res < 0) then
    begin
        side := TNODE_LEFT;
    end
    else 
    if (cmp_res > 0) then
    begin
      side := TNODE_RIGHT;
      cmp_res := aTTree.cmp_func(key, n^.keys[n^.max_idx]);
      if cmp_res>0 then//greater than max
      begin
        if (not tnode_is_full(n)) then// found/insert here
        begin
          {$ifdef debug}writeln(stdout,'gg:');{$endif}
          idx := n^.max_idx + 1;
          side := TNODE_BOUND;
          break;
        end;
      end
      else //smaller than, found/insert here, remove the smallest for next search
      if cmp_res<0 then
      begin
        side := TNODE_BOUND;
        {$ifdef debug}writeln(stdout,'search in node high_bound:',n^.max_idx - 1);{$endif}
        idx := binarySearch(n, 1,n^.max_idx - 1,key);
        {$ifdef debug}writeln(stdout,'search in node at:',idx);{$endif}
        if attree.cmp_func(key,n^.keys[idx])=0 then
        begin
            //replace item
            {$ifdef debug}writeln(stdout,'find same key in node at:',idx);{$endif}
            exit(false);
        end
        else
        if (tnode_is_full(n)) then
        begin
          {$ifdef debug}writeln(stdout,'not find in node replace and move out:',idx);{$endif}
          tmpkey:=n^.keys[0];
          item:=n^.data[0];
          for i:=1 to idx do
          begin
            n^.keys[i-1]:=n^.keys[i];
            n^.data[i-1]:=n^.data[i];
          end;
          n^.keys[idx]:=key;
          n^.data[idx]:=value;
          key:=tmpkey;
          value:=item;
          side := TNODE_LEFT;
        end
        else
        begin
          for i:=n^.max_idx downto idx+1 do
          begin
            n^.keys[i+1]:=n^.keys[i];
            n^.data[i+1]:=n^.data[i];
          end;
          idx:=idx+1;
          n^.keys[idx] := key;
          n^.data[idx] := value;
          n^.max_idx := n^.max_idx+1;
          exit(true);
        end;
      end
      else//equals to max key, key is found, it is here
      begin
        item := n^.data[n^.max_idx];
        idx := n^.max_idx;
        side := TNODE_BOUND;
        exit(true);
      end;
    end
    else 
    begin // equal to smallest key, key is found, search is completed.
      side := TNODE_BOUND;
      idx := 0;
      item := n^.data[0];
      exit(true);
    end;
    n := n^.sides[ord(side)];
  end;
  if (n=nil) then
  begin
    if createNewNode(@n,parent,key,value,side)=false then
      exit(false);
    fixup_after_insertion(n);
  end
  else
  begin
    {$ifdef debug}writeln(stdout,'insert into:',idx);{$endif}
    n^.keys[idx] := key;
    n^.data[idx] := value;
    n^.max_idx := idx;
  end;
end;
procedure TCodaMinaTTree.fixup_after_insertion(n:ptreeNode);
var
  node:ptreeNode;
  bfc_delta:integer;
begin
  bfc_delta := getBFCDelta(n);

  { check tree for balance after new node was added. }
  node := n^.parent;
  while (node<>nil) do
  begin
    node^.bfc := node^.bfc + bfc_delta;
    {
     * if node becomes balanced, tree balance is ok,
     * so process may be stopped here
     }
    if (node^.bfc=0) then
    begin
      exit;
    end;
        
    if ((node^.bfc < -1) or (node^.bfc > 1)) then
    begin
      {
       * Because of nature of T-tree rebalancing, just inserted item
       * may change its position in its node and even the node itself.
       * Thus if T-tree cursor was specified we have to take care of it.
       }
      {$ifdef debug}writeln(stdout,'rebalance!!');{$endif}
      //printTreeNode(node,0);
      //{$ifdef debug}writeln(stdout,'rebalance??');{$endif}
      rebalance(@node);

      {
       * single or double rotation tree becomes balanced
       * and we can stop here.
       }
      exit;
    end;
    bfc_delta := getBFCDelta(node);
    node := node^.parent;
  end;
end;
function TCodaMinaTTree.createNewNode(pnode:pptreeNode;parent:ptreeNode;key:Tkey;value:Tvalue;side:TNODETYPE):boolean;
var
  node:ptreeNode;
begin
    node := allocatenode();
    result:=true;
    if node=nil then
      exit(false);
    node^.keys[0] := key;
    node^.data[0] := value;
    node^.max_idx := 0;
    node^.parent := parent;
    node^.side:=side;
    node^.bfc := 0;
    if (pnode<>nil) then
    begin
      pnode^:=node;
    end;
    if (parent<>nil) and ((side=TNODE_LEFT) or (side=TNODE_RIGHT)) then
    begin
      parent^.sides[ord(side)]:=node;
    end;
end;

function TCodaMinaTTree.delete(key:TKEY):boolean;
var
  n:ptreenode;
  idx:integer;
begin

    n := searchInNode(key, @idx);
    {$ifdef debug}writeln(stdout,'delete KEY:',key,' at idx:',idx);{$endif}
    if (n=nil) then
    begin
        exit(false);
    end;

    deleteKeyNode(n,idx);
    result:=true;
end;

{
insert: 297,  root[150,153,157](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](0)
                               /            \
                        LEAF[168](0)       LEAF[191,291,297](0)
                        
delete: 150,  root[153,157,168](1)
              /              \
      LEAF[143](0)          NODE[175,181,190](1)
                               /            \
                        LEAF[X](0)       LEAF[191,291,297](0)
                        

delete: 143,    root[153,157,168](2) <<-- N1
              /              \
      LEAF[X](0)          NODE[175,181,190](1) <-- N2
                                            \
                                     LEAF[191,291,297](0) <-- N3 

REBALANCE:    root[175,181,190](0)
               /              \
LEAF[153,157,168](0)     LEAF[191,291,297](0) 
}
function TCodaMinaTTree.deleteKeyNode(tnode:ptreenode;idx:integer):TVALUE;
var
  i:integer;
  n,parent:ptreenode;
  side:TNODETYPE;
  key:Tkey;
begin
    result := tnode^.data[idx];
    // first, move righ child's smallest key to here into max value 
    // so first, compact
    for i:=idx+1 to tnode^.max_idx do
    begin
      tnode^.keys[i-1]:=tnode^.keys[i];
      tnode^.data[i-1]:=tnode^.data[i];
    end;
    tnode^.max_idx:=tnode^.max_idx-1;
    // second, find into righ childs smallest key
    while (not isLeafNode(tnode)) do
    begin
      n:=tnode^.right;
      if n=nil then
        break;
      while (n<>nil) do
      begin
        parent:=n;
        n := n^.sides[0];
      end;
      
      n:=parent;
      tnode^.keys[tnode^.max_idx]:=n^.keys[0];
      tnode^.data[tnode^.max_idx]:=n^.data[0];
      tnode^.max_idx:=tnode^.max_idx+1;
      for i:=1 to n^.max_idx do
      begin
        n^.keys[i-1]:=n^.keys[i];
        n^.data[i-1]:=n^.data[i];
      end;
      n^.max_idx:=n^.max_idx-1;
      tnode:=n;
    end;
    
    if tnode^.max_idx=-1 then
    begin
      tnode^.parent^.sides[ord(tnode^.side)]:=nil;
      fixup_after_deletion(tnode);
      freeNode(tnode);
    end;
end;
procedure TCodaMinaTTree.freeNode(n:ptreenode);
begin
  //make a link for store all empty treenode;
  n^.left :=nil;
  n^.right:=nil;
	if aTTree.Scavenger<>nil then
	begin
    for i:=0 to length(n^.data)-1 do
    begin
			aTTree.Scavenger(n^.data[i]);
    end;
	end;
  if (emptyHead.successor<>nil) then
    n^.parent:=emptyHead.successor
  else
    n^.parent:=@emptyHead;
  emptyHead.successor:=n;
end;
function TCodaMinaTTree.getEmptyNode():ptreenode;
begin
  result:=nil;
  if emptyHead.successor<>nil then
  begin
    result:=emptyHead.successor;
    emptyHead.successor:=result^.parent;
  end;
end;
procedure TCodaMinaTTree.fixup_after_deletion(n:ptreeNode);
var
  node,tmp:ptreeNode;
  bfc_delta:integer;
begin
  node := n^.parent;
  bfc_delta := getBFCDelta(n);

  {
   * Unlike balance fixing after insertion,
   * deletion may require several rotations.
   }
  while (node<>nil) do
  begin
    node^.bfc -= bfc_delta;
    {
     * If node's balance factor was 0 and becomes 1 or -1, we can stop.
     }
    if ((node^.bfc + bfc_delta)=0) then
        break;
    bfc_delta := getBFCDelta(node);
    if ((node^.bfc < -1) or (node^.bfc > 1)) then
    begin
      tmp := node;
      rebalance(@tmp);
      {
       * If after rotation subtree height is not changed,
       * proccess should be continued.
       }
      if (tmp^.bfc<>0) then
          break;

      node := tmp;
    end;
    node := node^.parent;
  end;
end;

procedure TCodaMinaTTree.printTreeNode(tnode:ptreenode; offs:integer);
var
  i:integer;
begin
    for i := 0 to offs-1  do
      write(stdout,' ');
    
    if tnode=nil then
    begin
      writeln(stdout,'(nil)');
      exit;
    end;
    
    if (tnode^.side = TNODE_LEFT) then
      write(stdout,'[L] ',integer(tnode),',parent=',integer(tnode^.parent))
    else 
    if (tnode^.side = TNODE_RIGHT) then
      write(stdout,'[R] ',integer(tnode),',parent=',integer(tnode^.parent))
    else
      write(stdout,'[*] ',integer(tnode),',parent=',integer(tnode^.parent));

    writeln(stdout);
    for i := 0 to   offs  do
        write(stdout,' ');

    write(stdout,'(', tnode^.bfc,')','<', tnode^.max_idx+1,'>');
    
    if (aTTree.printfn<>nil) then
    begin
     write(stdout,'[');
     for i:=0 to tnode^.max_idx do
     begin
       aTTree.printfn(tnode^.keys[i]);
       write(stdout,',');
     end;
     writeln(stdout,']');  
    end;

    printTreeNode(tnode^.left, offs + 1);
    printTreeNode(tnode^.right, offs + 1);
end;

//function __ttree_get_depth(tnode:ptreenode):integer;
//var
//  l, r:integer;
//begin
//   
//   if (tnode=nil) then
//   begin
//    exit(0);
//   end;
//
//   l := __ttree_get_depth(tnode^.left);
//   r := __ttree_get_depth(tnode^.right);
//   if (tnode^.left<>nil) then
//   begin
//       l++;
//   end;
//   
//   if (tnode^.right<>nil) then
//   begin
//       r++;
//   end;
//   
//  if (r > l) then
//    result:=r 
//  else
//    result:=l;
//end;
//
//function ttree_get_depth(ttree:ptree):integer;
//begin
//    result:=__ttree_get_depth(aTTree.root);
//end;

procedure TCodaMinaTTree.printtree();
begin
  printTreeNode(aTTree.root, 0);
end;

end.
