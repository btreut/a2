MODULE PHUserRegistry; (** AUTHOR "Patrick Hunziker"; PURPOSE "access control with userid, realm, password, whereby password is not plaintext stored"; *)
(**

*)

IMPORT PHRegistries, KernelLog, CryptoHashes, CryptoUtils, Strings, Streams;

CONST MD5Size=33;
		NotFound*=-2;
		WrongPassword*=-1;
		OK*=0;

TYPE 
	User*=POINTER TO RECORD (PHRegistries.Item);
		realm*: ARRAY 16 OF CHAR; (* delimits access of this user on server; user can have another login/access to another real *)
		hash-: ARRAY MD5Size OF CHAR;
	END;

TYPE UserRegistry*= OBJECT(PHRegistries.Registry)
	
	PROCEDURE NewUser*(CONST name, realm, password: ARRAY OF CHAR):User;
	VAR new: User; 
	BEGIN
		NEW(new); COPY(name,new.name); COPY(realm,new.realm);  new.uid:=GetUID();
		MakeHash(name,realm,password, new.hash); (*! to do: hash might be protected by an additional hash:=MD5(hash,nonce) value*)
		IF addUnique(new) THEN RETURN new 
		ELSE RETURN NIL  
		END;
	END NewUser;
	
	PROCEDURE ReadItem():PHRegistries.Item;
	VAR item:User; 
	BEGIN
		NEW(item); 
		r.Int(item.uid, FALSE); r.SkipSpaces;
		r.String(item.name); r.SkipSpaces;
		r.String(item.realm); r.SkipSpaces;
		r.String(item.hash); 
		IF r.res= Streams.Ok THEN RETURN item ELSE r.res:=Streams.Ok; RETURN NIL END;
	END ReadItem;
	
	PROCEDURE WriteItem(item:PHRegistries.Item);
	BEGIN
		w.Int(item.uid, 0); w.Char(09X); 
		w.String(item.name); w.Char(09X); 
		w.String(item(User).realm); w.Char(09X); 
		w.String(item(User).hash)
	END WriteItem;
	
	PROCEDURE CheckUser*(CONST name, realm, password: ARRAY OF CHAR): LONGINT;
	VAR user:User; same: ANY;
	BEGIN
		NEW(user);  COPY(name,user.name); COPY(realm,user.realm);
		MakeHash(name,realm,password, user.hash); 
		same:=list.SearchByKey(user); 
		IF same=NIL THEN RETURN NotFound
		ELSIF (same#NIL) & (same(User).hash#user.hash) THEN RETURN WrongPassword
		ELSE RETURN OK
		END;
	END CheckUser;
	
	PROCEDURE CheckUserByHash*(CONST name, realm, hash: ARRAY OF CHAR): LONGINT; (* allows to avoid plaintext password storage and handling on server side*)
	VAR user:User; same: ANY;
	BEGIN
		NEW(user);  COPY(name,user.name); COPY(realm,user.realm); COPY(hash,user.hash);
		 same:=list.SearchByKey(user); 
		 IF same=NIL THEN RETURN NotFound
		 ELSIF (same#NIL) & (same(User).hash#hash) THEN RETURN WrongPassword
		 ELSE RETURN OK
		 END;
	END CheckUserByHash;
END UserRegistry;

PROCEDURE MakeHash*(CONST username, realm, password: ARRAY OF CHAR; VAR hash: ARRAY MD5Size OF CHAR);
	VAR h: CryptoHashes.Hash;
		hash1: ARRAY MD5Size DIV 2 OF CHAR;
	BEGIN
		h := CryptoHashes.NewHash( "CryptoMD5" );
		(*h := CryptoHashes.NewHash( "CryptoSHA256" );*)
		h.Initialize;
		h.Update( username, 0, Strings.Length(username) );
		h.Update( ":", 0, 1 );
		h.Update( realm, 0, Strings.Length(realm) );
		h.Update( ":", 0, 1 );
		h.Update( password, 0, Strings.Length(password) );
		h.GetHash( hash1, 0 );  
		
		CryptoUtils.Bin2Hex(hash1, 0, hash, 0, MD5Size DIV 2); 
		hash[MD5Size -1]:=0X;
		Strings.LowerCase(hash);
	END MakeHash;
	
	PROCEDURE CompareHash(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(User).hash < right(User).hash THEN RETURN -1
		ELSIF left(User).hash > right(User).hash THEN RETURN 1
		ELSE RETURN 0
		END
	END CompareHash;
	
	PROCEDURE CompareName(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(User).name < right(User).name THEN RETURN -1
		ELSIF left(User).name > right(User).name THEN RETURN 1
		ELSE RETURN 0
		END
	END CompareName;
	
	PROCEDURE CompareRealmName(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(User).realm < right(User).realm THEN RETURN -1
		ELSIF left(User).realm > right(User).realm THEN RETURN 1
		ELSE RETURN CompareName(left,right)
		END
	END CompareRealmName;
	
PROCEDURE CompareNameHash(left, right: ANY): LONGINT;
	BEGIN
		IF left=NIL THEN RETURN -2
		ELSIF right =NIL THEN RETURN 2
		ELSIF left(User).name < right(User).name THEN RETURN -1
		ELSIF left(User).name > right(User).name THEN RETURN 1
		ELSE RETURN CompareHash(left,right)
		END
	END CompareNameHash;

PROCEDURE Test*;
	VAR r: UserRegistry; i:User;
	BEGIN
		NEW(r,"UserRegTest.txt", CompareRealmName, "MD5");
		i:=r.NewUser("hunzikeran","realm" ,"anpwd");
		i:=r.NewUser("hunzikeran","realm" ,"anpwd2");(* duplicate with another password not allowed *)
		i:=r.NewUser("hunzikerra","realm" ,"rawd");
		i:=r.NewUser("hunzikerp","realm" ,"ppwd");
		i:=r.NewUser("hunzikerp","realm" ,"ppwd"); (* same name in same realm will be rejected *)
		i:=r.NewUser("hunzikerp","realm1" ,"ppwd"); (*in another realm, a user with same name and same pwd may coexist*)
		KernelLog.Int(r.CheckUser("hunzikerx","realm" ,"anpwd"),0); KernelLog.Ln; (* user not OK *)
		KernelLog.Int(r.CheckUser("hunzikeran","realm" ,"wongpwd"),0); KernelLog.Ln; (* password not OK *)
		KernelLog.Int(r.CheckUser("hunzikeran","realm" ,"anpwd"),0); KernelLog.Ln; (* OK *)
		KernelLog.Int(r.CheckUserByHash("hunzikeran","realm","a71dfee052a970a6d591020236da7918"),0); KernelLog.Ln; (* OK *)
		KernelLog.Int(r.CheckUserByHash("hunzikeran","realm","a71dfee052a970a6d591020236da7919"),0); KernelLog.Ln; (* wrong hash *)
		r.Write;
	END Test;

END PHUserRegistry.

PHUserRegistry.Test 

SystemTools.FreeDownTo PHUserRegistry ~
