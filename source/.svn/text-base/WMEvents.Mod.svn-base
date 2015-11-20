MODULE WMEvents; (** AUTHOR "TF"; PURPOSE "Events"; *)

IMPORT
	Strings, KernelLog;

TYPE
	String = Strings.String;

	(** Generic Event Listener*)
	EventListener* = PROCEDURE  { DELEGATE } (sender, par : ANY);
	(** EventListenerFinder searches an EventListener by string in its context and returns the EventListener or NIL *)
	CompCommandFinder* = PROCEDURE { DELEGATE } (str : String) : EventListener;

	(* element of list of EventListeners *)
	EventListenerLink = POINTER TO RECORD
		event : EventListener;
		string : String;
		next : EventListenerLink;
	END;

	(** Event info class. CompCommand can be registered and unregistered to/from this class. *)
	EventSource* = OBJECT
	VAR
		listeners : RECORD
			event : EventListener;
			string : String;
			next : EventListenerLink;
		END;
		name, info : String;
		owner : ANY;
		finder : CompCommandFinder;
		next : EventSource;

		(** create an EventInfo for a component owner. Report name as the name of this event *)
		PROCEDURE &New*(owner : ANY; name, info : String; finder : CompCommandFinder);
		BEGIN
			SELF.owner := owner; SELF.name := name; SELF.info := info; SELF.finder := finder;
			listeners.event := NIL; listeners.string := NIL; listeners.next := NIL;
			next := NIL;
		END New;

		PROCEDURE GetName*() : String;
		BEGIN
			RETURN name
		END GetName;

		PROCEDURE GetInfo*() : String;
		BEGIN
			RETURN info
		END GetInfo;

		(** Add a command to this event. Observers can be added more then once. *)
		PROCEDURE Add*(observer : EventListener);
		VAR new : EventListenerLink;
		BEGIN {EXCLUSIVE}
			IF (listeners.event = NIL) & (listeners.string = NIL) THEN
				listeners.event := observer;
			ELSE
				NEW(new); new.event := observer; new.next := listeners.next; listeners.next := new
			END;
		END Add;

		(** Add an listener to this event. The listener is found by findig the component referenced in the string and then
			querying the component for the listener. Listeners can be added more then once.
			The dereferencing is done on demant at the first call. If the EventListener can not be found, the call to the
			respective listener is ignored. On each call, the EventListener is searched again *)
		PROCEDURE AddByString*(link : String);
		VAR new : EventListenerLink;
		BEGIN {EXCLUSIVE}
			IF (listeners.event = NIL) & (listeners.string = NIL) THEN
				listeners.string := link;
			ELSE
				NEW(new); new.string := link; new.next := listeners.next; listeners.next := new
			END;
		END AddByString;

		(** Remove the first found entry of event *)
		PROCEDURE Remove*(observer : EventListener);
		VAR cur : EventListenerLink;
		BEGIN {EXCLUSIVE}
			IF (listeners.event = observer) THEN
				IF (listeners.next = NIL) THEN
					listeners.event := NIL;
				ELSE
					listeners.event := listeners.next.event;
					listeners.string := listeners.next.string;
					listeners.next := listeners.next.next;
				END;
			ELSIF (listeners.next # NIL) THEN
				IF (listeners.next.event = observer) THEN listeners.next := listeners.next.next;
				ELSE
					cur := listeners.next;
					WHILE cur.next # NIL DO
						IF cur.next.event = observer THEN cur.next := cur.next.next; RETURN END;
						cur := cur.next
					END
				END;
			END;
		END Remove;

		(** Remove the first found entry of event, specified as a string *)
		PROCEDURE RemoveByString*(string : String);
		VAR cur : EventListenerLink;
		BEGIN {EXCLUSIVE}
			IF (listeners.string # NIL) & (listeners.string^ = string^) THEN
				IF (listeners.next = NIL) THEN
					listeners.string := NIL;
				ELSE
					listeners.event := listeners.next.event;
					listeners.string := listeners.next.string;
					listeners.next := listeners.next.next;
				END;
			ELSIF (listeners.next # NIL) THEN
				IF (listeners.next.string # NIL) & (listeners.next.string^ = string^) THEN listeners.next := listeners.next.next;
				ELSE
					cur := listeners.next;
					WHILE cur.next # NIL DO
						IF (cur.next.string # NIL) & (cur.next.string^ = string^) THEN cur.next := cur.next.next; RETURN END;
						cur := cur.next
					END
				END;
			END;
		END RemoveByString;

		PROCEDURE CallWithSender*(sender, par: ANY);
		VAR cur : EventListenerLink;
		BEGIN
			IF (listeners.event # NIL) OR (listeners.string # NIL) THEN
				IF listeners.event # NIL THEN listeners.event(sender, par);
				ELSIF (listeners.string # NIL) & (finder # NIL) THEN
					listeners.event := finder(listeners.string);
					IF listeners.event = NIL THEN KernelLog.String("Fixup failed"); KernelLog.String(listeners.string^) END;
					IF listeners.event # NIL THEN listeners.event(sender, par) END
				END;
				cur := listeners.next;
				WHILE cur # NIL DO
					IF cur.event # NIL THEN cur.event(sender, par)
					ELSE
						IF (cur.string # NIL) & (finder # NIL) THEN
							cur.event := finder(cur.string);
							IF cur.event = NIL THEN KernelLog.String("Fixup failed"); KernelLog.String(cur.string^) END;
							IF cur.event # NIL THEN cur.event(sender, par) END
						END
					END;
					cur := cur.next
				END;
			END;
		END CallWithSender;

		(** Call the event with parameter par. The owner of the EventInfo class will be added in the event's sender parameter *)
		PROCEDURE Call*(par : ANY);
		BEGIN CallWithSender(owner, par)
		END Call;

		(** return true if listeners are installed; Can be used to avoid calculating parameters, if there
		are no listeners *)
		PROCEDURE HasListeners*() : BOOLEAN;
		BEGIN {EXCLUSIVE}
			RETURN (listeners.event # NIL) OR (listeners.string # NIL);
		END HasListeners;
	END EventSource;

TYPE

	EventSourceArray* = POINTER TO ARRAY OF EventSource;

	EventSourceList* = OBJECT
	VAR
		head : EventSource;
		nofEventSources : LONGINT;

		PROCEDURE &New *;
		BEGIN
			head := NIL; nofEventSources := 0;
		END New;

		PROCEDURE Add*(x : EventSource);
		VAR e : EventSource;
		BEGIN {EXCLUSIVE}
			ASSERT((x # NIL) & (x.next = NIL));
			IF (head = NIL) THEN
				head := x;
			ELSE
				e := head;
				WHILE (e.next # NIL) DO e := e.next; END;
				e.next := x;
			END;
			INC(nofEventSources)
		END Add;

		PROCEDURE Remove*(x : EventSource);
		VAR e : EventSource;
		BEGIN {EXCLUSIVE}
			ASSERT(x # NIL);
			IF (head = x) THEN
				head := head.next; x.next := NIL;
				DEC(nofEventSources);
			ELSIF (head # NIL) THEN
				e := head;
				WHILE (e.next # x) DO e := e.next; END;
				IF (e.next # NIL) THEN
					e.next := e.next.next; x.next := NIL;
					DEC(nofEventSources);
				END;
			END;
		END Remove;

		PROCEDURE Enumerate*() : EventSourceArray;
		VAR current : EventSourceArray; e : EventSource; i : LONGINT;
		BEGIN {EXCLUSIVE}
			NEW(current, nofEventSources);
			e := head; i := 0;
			WHILE (e # NIL) DO
				current[i] := e; INC(i);
				e := e.next;
			END;
			RETURN current
		END Enumerate;

		PROCEDURE GetEventSourceByName*(name : String) : EventSource;
		VAR e : EventSource; n : String;
		BEGIN {EXCLUSIVE}
			e := head;
			WHILE (e # NIL) DO
				n := e.GetName();
				IF (n # NIL) & (n^ = name^) THEN RETURN e; END;
				e := e.next;
			END;
			RETURN NIL;
		END GetEventSourceByName;

	END EventSourceList;

TYPE

	EventListenerInfo* = OBJECT
	VAR
		name, info : String;
		eventListener : EventListener;
		next : EventListenerInfo;

		PROCEDURE &Init*(name, info : String; handler : EventListener);
		BEGIN
			SELF.name := name; SELF.info := info; SELF.eventListener := handler; next := NIL;
		END Init;

		PROCEDURE GetName*() : String;
		BEGIN
			RETURN name
		END GetName;

		PROCEDURE GetInfo*() : String;
		BEGIN
			RETURN info
		END GetInfo;

		PROCEDURE GetHandler*() : EventListener;
		BEGIN
			RETURN eventListener
		END GetHandler;

	END EventListenerInfo;

TYPE

	EventListenerArray* = POINTER TO ARRAY OF EventListenerInfo;

	EventListenerList* = OBJECT
	VAR
		head : EventListenerInfo;
		nofEventListeners : LONGINT;

		PROCEDURE &New *;
		BEGIN
			head := NIL; nofEventListeners := 0;
		END New;

		PROCEDURE Add*(x : EventListenerInfo);
		VAR e : EventListenerInfo;
		BEGIN {EXCLUSIVE}
			ASSERT((x # NIL) & (x.next = NIL));
			IF (head = NIL) THEN
				head := x;
			ELSE
				e := head;
				WHILE (e.next # NIL) DO e := e.next; END;
				e.next := x;
			END;
			INC(nofEventListeners);
		END Add;

		PROCEDURE Remove*(x : EventListenerInfo);
		VAR e : EventListenerInfo;
		BEGIN {EXCLUSIVE}
			ASSERT(x # NIL);
			IF (head = x) THEN
				head := head.next; x.next := NIL;
				DEC(nofEventListeners);
			ELSIF (head # NIL) THEN
				e := head;
				WHILE (e.next # x) DO e := e.next; END;
				IF (e.next # NIL) THEN
					e.next := e.next.next; x.next := NIL;
					DEC(nofEventListeners);
				END;
			END;
		END Remove;

		PROCEDURE Enumerate*() : EventListenerArray;
		VAR current : EventListenerArray; e : EventListenerInfo; i : LONGINT;
		BEGIN {EXCLUSIVE}
			NEW(current, nofEventListeners);
			e := head; i := 0;
			WHILE (e # NIL) DO
				current[i] := e; INC(i);
				e := e.next;
			END;
			RETURN current
		END Enumerate;

		PROCEDURE GetHandlerByName*(name : String) : EventListener;
		VAR e : EventListenerInfo; n : String;
		BEGIN {EXCLUSIVE}
			e := head;
			WHILE (e # NIL) DO
				n := e.GetName();
				IF (n # NIL) & (n^ = name^) THEN
					RETURN e.GetHandler()
				END;
				e := e.next;
			END;
			RETURN NIL;
		END GetHandlerByName;

	END EventListenerList;

END WMEvents.

