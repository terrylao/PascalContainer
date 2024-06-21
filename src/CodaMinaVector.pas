unit CodaMinaVector;
{$mode objfpc}{$H+}
interface
uses
  Types,math;

const
  LNI_VECTOR_MAX_SZ = 1000000000;
	
type

	generic TCodaMinaVector<T> = class
    type
		  TClearFunc = procedure (AValue: T);
			PT=^T;
		public
			
			constructor create(lScavenger:TClearFunc=nil);
      constructor create(n:uint32;lScavenger:TClearFunc=nil);
			destructor destroy();override;
      procedure push_back(val:T);
      procedure pop_back();
			procedure reserve(_sz:uint32);
			procedure clear();
      function get(idx:uint32;var dout:T):boolean;
			function get(idx:uint32):T;
      procedure setValue(idx:uint32;din:T);
			procedure erase(pos:uint32);
      function front():T;
      function back():T;
      procedure resize(sz:uint32);
      procedure shrink_to_fit();
      function empty():boolean;
      function size():uint32;
      function max_size():uint32;
      function capacity():uint32;
      function data():PT;
			procedure addRange(source:specialize TCodaMinaVector<T>);
		private
			rsrv_sz:uint32;//max size
			vec_sz:uint32;//current position
			arr:PT;
      Scavenger:TClearFunc;
      procedure reallocate();
	end;
implementation
	constructor TCodaMinaVector.create(lScavenger:TClearFunc=nil);
	begin
	  Scavenger:=lScavenger;
	  rsrv_sz:=128;
		vec_sz:=0;
		arr := allocmem(sizeof(T)*rsrv_sz);
	end;

	constructor TCodaMinaVector.create(n:uint32;lScavenger:TClearFunc=nil);
	begin
	  Scavenger:=lScavenger;
		rsrv_sz := n shl 2;
		arr := allocmem(sizeof(T)*rsrv_sz);
		vec_sz := n;
	end;

  destructor TCodaMinaVector.destroy();
	begin
	  clear();
		freemem(arr);
	end;

	procedure TCodaMinaVector.reallocate();
	var
	  tarr:pt;
	begin
		tarr := allocmem(sizeof(T)*rsrv_sz);
		move(arr[0], tarr[0], vec_sz * sizeof(T));
		freemem(arr);
		arr := tarr;
	end;
	procedure TCodaMinaVector.erase(pos:uint32);
	begin
		if Scavenger<>nil then
		begin
	    Scavenger(arr[pos]);
		end;
		move(arr[pos+1], arr[pos], (vec_sz - pos - 1) * sizeof(T));
		dec(vec_sz);
	end;
	function TCodaMinaVector.empty():boolean;
	begin
		result := vec_sz = 0;
	end;
	
	function TCodaMinaVector.size():uint32;
	begin
		result := vec_sz;
	end;

	function TCodaMinaVector.max_size():uint32;
	begin
		result := LNI_VECTOR_MAX_SZ;
	end;

	function TCodaMinaVector.capacity():uint32;
	begin
		result := rsrv_sz;
	end;
	
	procedure TCodaMinaVector.resize(sz:uint32);
	var
	  i:uint32;
	begin
		if (sz > vec_sz) then
		begin
			if (sz > rsrv_sz) then
			begin
				rsrv_sz := sz;
				reallocate();
			end;
		end
		else
		begin
		  if Scavenger<>nil then
			begin
  			for i := vec_sz to sz-1 do
  				Scavenger(arr[i]);
			end;
		end;
		vec_sz := sz;
	end;

	procedure TCodaMinaVector.reserve(_sz:uint32);
	begin
		if (_sz > rsrv_sz) then
		begin
			rsrv_sz := _sz;
			reallocate();
		end;
	end;

	procedure TCodaMinaVector.shrink_to_fit();
	begin
		rsrv_sz := vec_sz;
		reallocate();
	end;
	
  procedure TCodaMinaVector.setValue(idx:uint32;din:T);
  begin
		if (idx > vec_sz) then
		begin
			if (vec_sz > rsrv_sz) then
			begin
  			rsrv_sz := rsrv_sz shl 2;
  			reallocate();
			end;
		end;
    arr[idx]:=din;
  end;

 function TCodaMinaVector.get(idx:uint32;var dout:T):boolean;
	begin
	  result:=false;
		if (idx < vec_sz) then
		begin
			dout := arr[idx];
			result := true;
		end;
	end;

	function TCodaMinaVector.get(idx:uint32):T;
	begin
		if (idx < vec_sz) then
		begin
			result := arr[idx];
		end
		else
		begin
		  result := default(T);
		end;
	end;
	
	function TCodaMinaVector.front():T;
	begin
		result := arr[0];
	end;

	function TCodaMinaVector.back():T;
	begin
		result := arr[vec_sz - 1];
	end;
	
	function TCodaMinaVector.data():PT;
	begin
		result := arr;
	end;

	procedure TCodaMinaVector.push_back(val:T);
	begin
		if (vec_sz = rsrv_sz) then
		begin
			rsrv_sz := rsrv_sz shl 2;
			reallocate();
		end;
		arr[vec_sz] := val;
		inc(vec_sz);
	end;

	procedure TCodaMinaVector.pop_back();
	begin
    if Scavenger<>nil then
    begin
      Scavenger(arr[vec_sz]);
    end;
    dec(vec_sz);
  end;


	procedure TCodaMinaVector.clear();
	var
	  i:integer;
		tk:TTypeKind;
	begin
	  //https://www.freepascal.org/docs-html/rtl/system/ttypekind.html
	  //tk := GetTypeKind(T);
    //if tk in [tkObject,tkRecord,tkClass,tkDynArray,tkPointer] then
		//begin
		  if Scavenger<>nil then
			begin
    		for i := 0 to vec_sz-1 do
    			Scavenger(arr[i]);
			end;
		//end;
		vec_sz := 0;
	end;
	procedure TCodaMinaVector.addRange(source:specialize TCodaMinaVector<T>);
	var
	  i:integer;
		src:PT;
	begin
	  src:=source.data();
		if vec_sz+source.size()>=rsrv_sz then
		begin
			rsrv_sz := (vec_sz+source.size()) shl 2;
			reallocate();
		end;
	  for i:=0 to source.size()-1 do
		begin
      arr[vec_sz+i] := src[i];
		end;
		inc(vec_sz,source.size());
	end;
end.
