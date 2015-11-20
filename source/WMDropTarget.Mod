MODULE WMDropTarget; (** AUTHOR "TF"; PURPOSE "Drag'n'Drop interface"; *)

IMPORT
	Streams, Texts;

CONST
	TypeText* = 0;
	TypeFiles* = 1;
	TypeURL* = 2;
	TypeImage* = 3;
	TypeUser* = 4;
	TypeInt32* = 5;
	TypeString* = 6;
	TypeObject* = 7;

	Ok* = 0;
	Failed* = -1;

TYPE
	(** a drop interface that can be obtained from a drop target, according to a defined type *)
	DropInterface* = OBJECT
	END DropInterface;

	DropTarget* = OBJECT

		(** return NIL if the type can not be dropped, a suitable DropInterface otherwise *)
		PROCEDURE GetInterface*(type : LONGINT) : DropInterface;
		BEGIN
			RETURN NIL
		END GetInterface;

	END DropTarget;

	DropText* = OBJECT(DropInterface)
	VAR
		text* : Texts.Text;
		pos* : Texts.TextPosition;
	END DropText;

	DropInt32* = OBJECT(DropInterface)

		PROCEDURE Set*(i : LONGINT);
		END Set;

	END DropInt32;

	DropString* = OBJECT(DropInterface)

		PROCEDURE Set*(CONST string : ARRAY OF CHAR; VAR res : LONGINT);
		END Set;

	END DropString;

	DropURLs* = OBJECT(DropInterface)

		PROCEDURE URL*(CONST url : ARRAY OF CHAR; VAR res : LONGINT);
		END URL;

	END DropURLs;

	DropFiles* = OBJECT(DropInterface)

		PROCEDURE IsHierarchical*() : BOOLEAN;
		BEGIN
			RETURN FALSE
		END IsHierarchical;

		PROCEDURE OpenPut*(CONST remoteName : ARRAY OF CHAR; VAR outw : Streams.Writer; VAR res : LONGINT);
		END OpenPut;

		PROCEDURE ClosePut*(VAR res : LONGINT);
		END ClosePut;

		(** only path relative to the current dir are accepted. The string '..' stands for the parent directory *)
		PROCEDURE ChangeDir*(CONST dir : ARRAY OF CHAR; VAR res : LONGINT);
		END ChangeDir;

		(** only path relative to the current dir are accepted. The string '..' stands for the parent directory *)
		PROCEDURE MakeDir*(CONST dir : ARRAY OF CHAR; VAR res : LONGINT);
		END MakeDir;

	END DropFiles;

	DropObject* = OBJECT(DropInterface)

		PROCEDURE Set*(object : ANY; VAR res : LONGINT);
		END Set;

	END DropObject;

END WMDropTarget.
