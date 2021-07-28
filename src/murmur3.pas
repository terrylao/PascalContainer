{
  publish with BSD Licence.
	Copyright (c) Terry Lao
}

unit murmur3;
interface 

function MurmurHash3_x86_32 ( const  key:pbyte; len:integer ;  seed:uint32 ):uint32;
procedure MurmurHash3_x86_128 ( const  key:pbyte; len:integer ;  seed:uint32;  pout:pbyte );
procedure MurmurHash3_x64_128 ( const  key:pbyte; len:integer ;  seed:uint32;  pout:pbyte );
implementation

function   rotl32 (  x: uint32;  r:integer ): uint32;
begin
  result:= (x shl r) or (x shr (32 - r));
end;

function   rotl64 (  x: uint64;  r:integer ): uint64;
begin
  result:= (x shl r) or (x shr (64 - r));
end;


//-----------------------------------------------------------------------------
// Block read - if your platform needs to do endian-swapping or can only
// handle aligned reads, do the conversion here

//#define getblock(p, i) (p[i])

//-----------------------------------------------------------------------------
// Finalization mix - force all bits of a hash block to avalanche

function   fmix32 (  h: uint32 ): uint32;
begin
  h := h xor (h shr 16);
  h := h *  $85ebca6b;
  h := h xor (h shr 13);
  h := h *  $c2b2ae35;
  h := h xor (h shr 16);

  result:= h;
end;

//----------

function   fmix64 (  k: uint64 ): uint64;
begin
  k := k xor (k shr 33);
  k *= UINT64($ff51afd7ed558ccd);
  k := k xor (k shr 33);
  k *= UINT64($c4ceb9fe1a85ec53);
  k := k xor (k shr 33);

  result:= k;
end;

//-----------------------------------------------------------------------------

//procedure MurmurHash3_x86_32 ( const  key:pbyte; len:integer ;  seed:uint32;  pout:pbyte );
function MurmurHash3_x86_32 ( const  key:pbyte; len:integer ;  seed:uint32 ):uint32;
var
  tail,data:puint8;
  i,nblocks:integer;
  tmp,c1,c2,h1,k1:uint32;
  blocks:puint32;
begin
  data := puint8(key);
  nblocks := len div 4;

  h1 := seed;

  c1 := $cc9e2d51;
  c2 := $1b873593;

  //----------
  // body
  //writeln(stdout,'nblocks:',nblocks);
  blocks := puint32(data);
  //writeln(stdout,'data:',Integer(data),' blocks:',integer(blocks));
  for i := 0 to nblocks-1 do
  begin
    k1 := blocks[i];
    //writeln(stdout,'k1:',k1);
    k1 := k1 * c1;
    k1 := ROTL32(k1,15);
    k1 := k1 * c2;
    
    h1 := h1 xor k1;
    h1 := ROTL32(h1,13); 
    h1 := h1*5+$e6546b64;
    //writeln(stdout,'h1:',h1);
  end;

  //----------
  // tail

  tail := puint8(data + nblocks*4);

  k1 := 0;
  tmp := len and 3;
  while tmp>0 do
  begin
    case (tmp) of 
      3:
      begin 
        k1 := k1 xor (tail[2] shl 16);
      end;
      2: 
      begin
        k1 := k1 xor (tail[1] shl 8);
      end;
      1: 
      begin
        k1 := k1 xor tail[0];
        k1 := k1 * c1; 
        k1 := ROTL32(k1,15); 
        k1 := k1 * c2; 
        h1 := h1 xor k1;    
      end;
    end;
    tmp:=tmp-1;
  end;
  //----------
  // finalization

  h1 := h1 xor len;

  h1 := fmix32(h1);

  //puint32(pout)^ := h1; //*(uint32_t*)out = h1;
  result:=h1;
end; 

//-----------------------------------------------------------------------------

procedure MurmurHash3_x86_128 ( const  key:pbyte; len:integer ;  seed:uint32;  pout:pbyte );
var
  tail,data:puint8;
  i,nblocks:integer;
  tmp,c1,c2,c3,c4,h1,h2,h3,h4,k1,k2,k3,k4:uint32;
  blocks:puint32;
begin
  data := puint8(key);
  nblocks := len div 16;

   h1 := seed;
   h2 := seed;
   h3 := seed;
   h4 := seed;

   c1 := $239b961b; 
   c2 := $ab0e9789;
   c3 := $38b34ae5; 
   c4 := $a1e38b93;

  //----------
  // body

  blocks := puint32(data);

  
  for i := 0 to nblocks-1 do
  begin
    k1 := blocks[i*4+0];
    k2 := blocks[i*4+1];
    k3 := blocks[i*4+2];
    k4 := blocks[i*4+3];

    k1 := k1 * c1; 
    k1 := ROTL32(k1,15); 
    k1 := k1 * c2; 
    h1 := h1 xor k1;

    h1 := ROTL32(h1,19); 
    h1 := h1 + h2; 
    h1 := h1*5+$561ccd1b;

    k2 := k2 * c2; 
    k2 := ROTL32(k2,16); 
    k2 := k2 * c3; 
    h2 := h2 xor k2;

    h2 := ROTL32(h2,17); 
    h2 := h2 + h3; 
    h2 := h2*5+$0bcaa747;

    k3 := k3 * c3; 
    k3 := ROTL32(k3,17); 
    k3 := k3 * c4; 
    h3 := h3 xor k3;

    h3 := ROTL32(h3,15); 
    h3 := h3 + h4; 
    h3 := h3*5+$96cd1c35;

    k4 := k4 * c4; 
    k4 := ROTL32(k4,18); 
    k4 := k4 * c1; 
    h4 := h4 xor k4;

    h4 := ROTL32(h4,13); 
    h4 := h4 + h1; 
    h4 := h4*5+$32ac3b17;

  end;

  //----------
  // tail

  tail := puint8(data + nblocks*16);

  k1 := 0;
  k2 := 0;
  k3 := 0;
  k4 := 0;
  //need fall through
  tmp:=len and 15;
  while tmp>0 do
  begin
    case (tmp) of
      15: 
      begin
        k4 := k4 xor (tail[14] shl 16);
      end;
      14: 
      begin
        k4 := k4 xor (tail[13] shl 8);
      end;
      13: 
      begin
        k4 := k4 xor (tail[12] shl 0);
        k4 := k4 *  c4; 
        k4 := ROTL32(k4,18); 
        k4 := k4 *  c1; 
        h4 := h4 xor k4;
      end;
      12: 
      begin
        k3 := k3 xor (tail[11] shl 24);
      end;
      11: 
      begin
        k3 := k3 xor (tail[10] shl 16);
      end;
      10: 
      begin
        k3 := k3 xor (tail[ 9] shl 8);
      end;
       9: 
       begin
         k3 := k3 xor (tail[ 8] shl 0);
         k3 := k3 * c3; 
         k3 := ROTL32(k3,17); 
         k3 := k3 * c4; 
         h3 := h3 xor k3;
       end;
       8: 
       begin
         k2 := k2 xor (tail[ 7] shl 24);
       end;
       7: 
       begin
         k2 := k2 xor (tail[ 6] shl 16);
       end;
       6: 
       begin
         k2 := k2 xor (tail[ 5] shl 8);
       end;
       5: 
       begin
         k2 := k2 xor (tail[ 4] shl 0);
         k2 := k2 * c2; 
         k2 := ROTL32(k2,16); 
         k2 := k2 * c3; 
         h2 := h2 xor k2;
       end;
       4: 
       begin
         k1 := k1 xor (tail[ 3] shl 24);
       end;
       3: 
       begin
         k1 := k1 xor (tail[ 2] shl 16);
       end;
       2: 
       begin
         k1 := k1 xor (tail[ 1] shl 8);
       end;
       1: 
       begin
         k1 := k1 xor (tail[ 0] shl 0);
         k1 := k1 * c1; 
         k1 := ROTL32(k1,15); 
         k1 := k1 * c2; 
         h1 := h1 xor k1;
       end;
    end;
    tmp:=tmp - 1;
  end;
  //----------
  // finalization

  h1 := h1 xor len; 
  h2 := h2 xor len; 
  h3 := h3 xor len; 
  h4 := h4 xor len;

  h1 :=h1 + h2; 
  h1 :=h1 + h3; 
  h1 :=h1 + h4;
  h2 :=h2 + h1; 
  h3 :=h3 + h1; 
  h4 :=h4 + h1;

  h1 := fmix32(h1);
  h2 := fmix32(h2);
  h3 := fmix32(h3);
  h4 := fmix32(h4);

  h1 :=h1 + h2; 
  h1 :=h1 + h3; 
  h1 :=h1 + h4;
  h2 :=h2 + h1; 
  h3 :=h3 + h1; 
  h4 :=h4 + h1;

  puint32(pout)[0] := h1;
  puint32(pout)[1] := h2;
  puint32(pout)[2] := h3;
  puint32(pout)[3] := h4;
end;

//-----------------------------------------------------------------------------

procedure MurmurHash3_x64_128 ( const  key:pbyte; len:integer ;  seed:uint32;  pout:pbyte );
var
  tail,data:puint8;
  tmp,i,nblocks:integer;
  c1,c2,h1,h2,k1,k2:uint64;
  blocks:puint64;
begin
  data := puint8(key);
  nblocks := len div 16;

  h1 := seed;
  h2 := seed;

  c1 := uint64($87c37b91114253d5);
  c2 := uint64($4cf5ad432745937f);

  //----------
  // body

  blocks := puint64(data);

  for i := 0 to nblocks-1 do
  begin
    k1 := blocks[i*2+0];
    k2 := blocks[i*2+1];

    k1 := k1 * c1; 
    k1 := ROTL64(k1,31); 
    k1 := k1 * c2; 
    h1 := h1 xor k1;

    h1 := ROTL64(h1,27); 
    h1 := h1 + h2; 
    h1 := h1*5+$52dce729;

    k2 := k2 * c2; 
    k2 := ROTL64(k2,33); 
    k2 := k2 * c1; 
    h2 := h2 xor k2;

    h2 := ROTL64(h2,31); 
    h2 := h2 + h1; 
    h2 := h2*5+$38495ab5;
  end;

  //----------
  // tail

  tail := puint8(data + nblocks*16);

  k1 := 0;
  k2 := 0;
  tmp:= len and 15;
  while tmp>0 do
  begin
    case (tmp) of
      15: 
      begin
        k2 := k2 xor uint64(tail[14]) shl 48;
      end;
      14: 
      begin
        k2 := k2 xor uint64(tail[13]) shl 40;
      end;
      13: 
      begin
        k2 := k2 xor uint64(tail[12]) shl 32;
      end;
      12: 
      begin
        k2 := k2 xor uint64(tail[11]) shl 24;
      end;
      11: 
      begin
        k2 := k2 xor uint64(tail[10]) shl 16;
      end;
      10: 
      begin
        k2 := k2 xor uint64(tail[ 9]) shl 8;
      end;
       9: 
       begin
         k2 := k2 xor uint64(tail[ 8]) shl 0;
         k2 := k2 * c2; 
         k2 := ROTL64(k2,33); 
         k2 := k2 * c1; 
         h2 := h2 xor k2;
       end;
       8: 
       begin
         k1 := k1 xor uint64(tail[ 7]) shl 56;
       end;
       7: 
       begin
         k1 := k1 xor uint64(tail[ 6]) shl 48;
       end;
       6: 
       begin
         k1 := k1 xor uint64(tail[ 5]) shl 40;
       end;
       5: 
       begin
         k1 := k1 xor uint64(tail[ 4]) shl 32;
       end;
       4: 
       begin
         k1 := k1 xor uint64(tail[ 3]) shl 24;
       end;
       3: 
       begin
         k1 := k1 xor uint64(tail[ 2]) shl 16;
       end;
       2: 
       begin
         k1 := k1 xor uint64(tail[ 1]) shl 8;
       end;
       1: 
       begin
         k1 := k1 xor uint64(tail[ 0]) shl 0;
         k1 := k1 * c1; 
         k1 := ROTL64(k1,31); 
         k1 := k1 * c2; 
         h1 := h1 xor k1;
       end;
    end;
    tmp := tmp - 1;
  end;
  //----------
  // finalization

  h1 := h1 xor len; 
  h2 := h2 xor len;

  h1 :=h1 + h2;
  h2 :=h2 + h1;

  h1 := fmix64(h1);
  h2 := fmix64(h2);

  h1 :=h1 + h2;
  h2 :=h2 + h1;

  puint64(pout)[0] := h1;
  puint64(pout)[1] := h2;
end;
end.
