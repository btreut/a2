(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Plugins; (** AUTHOR "pjm"; PURPOSE "Plugin object management"; *)

CONST
	(** Result code constants *)
	Ok* = 0;
	DuplicateName* = 4101;
	AlreadyRegistered* = 4102;
	NeverRegistered* = 4103;

	(** Event constants *)
	EventAdd* = 0; (** Occurs when a plugin is added to the registry *)
	EventRemove* = 1; (** Occurs when a plugin is removed from the registry *)

TYPE
	Name* = ARRAY 32 OF CHAR;
	Description* = ARRAY 128 OF CHAR;

(** The plugin object provides the basis of extendibility. *)

	Plugin* = OBJECT
		VAR
			name-: Name;	(** unique identifying name *)
			desc*: Description;	(** human-readable description of plugin *)
			link: Plugin;	(* next plugin in registry *)
			registry: Registry;

		(** Set the name field.  Must be called before adding the plugin to a registry. *)

		PROCEDURE SetName*(CONST name: ARRAY OF CHAR);
		BEGIN
			ASSERT(registry = NIL);	(* can not be set after registering *)
			COPY(name, SELF.name)
		END SetName;

	END Plugin;

	(** Plugin handler type for Registry.Enumerate() *)
	PluginHandler* = PROCEDURE {DELEGATE} (p: Plugin);

	(** Event handler (upcall) *)
	EventHandler* = PROCEDURE {DELEGATE} (event: LONGINT; plugin: Plugin);

	(* List item of event handler list *)
	EventHandlerList = POINTER TO RECORD
		next: EventHandlerList;
		handler: EventHandler;
	END;

	(** A table of plugins. *)
	Table* = POINTER TO ARRAY OF Plugin;

(** Plugin registries are collections of plugins. *)
	Registry* = OBJECT (Plugin)
		VAR
			root: Plugin;	(* list of registered plugins, in order of registration *)
			added: LONGINT;	(* number of plugins successfully added (for synchronization) *)
			handlers: EventHandlerList;	(* list of installed event handlers *)

		(** Get a specific plugin.  If name = "", get the first existing plugin.  Return NIL if it was not found. *)

		PROCEDURE Get*(CONST name: ARRAY OF CHAR): Plugin;
		VAR p: Plugin;
		BEGIN {EXCLUSIVE}
			p := root;
			IF name # "" THEN
				WHILE (p # NIL) & (p.name # name) DO p := p.link END
			END;
			RETURN p
		END Get;

		(** Like Get, but wait until the plugin is available. *)

		PROCEDURE Await*(CONST name: ARRAY OF CHAR): Plugin;
		VAR p: Plugin; num: LONGINT;
		BEGIN {EXCLUSIVE}
			LOOP
				p := root;
				IF name # "" THEN
					WHILE (p # NIL) & (p.name # name) DO p := p.link END
				END;
				IF p # NIL THEN RETURN p END;
				num := added; AWAIT(added # num)	(* wait until a name is added *)
			END
		END Await;

		(** Call h for each plugin in this registry *)

		PROCEDURE Enumerate*(h: PluginHandler);
		VAR p: Plugin;
		BEGIN (* can run concurrently with Add and Remove *)
			p := root;
			WHILE p # NIL DO
				h(p);
				p := p.link;
			END;
		END Enumerate;

		(** Get a table of available plugin instances in the registry, in order of registration.  If none are available, table = NIL, otherwise LEN(table^) is the number of available plugins. *)

		PROCEDURE GetAll*(VAR table: Table);
		VAR p: Plugin; num, i: LONGINT;
		BEGIN {EXCLUSIVE}
			num := 0; p := root;	(* get number of entries *)
			WHILE p # NIL DO INC(num); p := p.link END;
			IF num # 0 THEN
				NEW(table, num); p := root;
				FOR i := 0 TO num-1 DO table[i] := p; p := p.link END
			ELSE
				table := NIL
			END
		END GetAll;

		(** Register a new plugin instance.  Called by plugins to advertise their availability.  If the plugin has an empty name, a unique name is assigned, otherwise the name must be unique already.  The res parameter returns Ok if successful, or a non-zero error code otherwise. *)

		PROCEDURE Add*(p: Plugin; VAR res: LONGINT);
		VAR c: Plugin; tail: Plugin; item: EventHandlerList;
		BEGIN {EXCLUSIVE}
			ASSERT(p # NIL);
			IF p.registry = NIL THEN	(* assume this is initialized to NIL by environment *)
				IF p.name = "" THEN GenName(added, SELF.name, p.name) END;
				IF p.desc = "" THEN p.desc := "Unknown plugin" END;
				tail := NIL; c := root;
				WHILE (c # NIL) & (c.name # p.name) DO tail := c; c := c.link END;
				IF c = NIL THEN	(* name is unique *)
					p.link := NIL; p.registry := SELF;
					IF root = NIL THEN root := p ELSE tail.link := p END;	(* add at end *)
					INC(added); res := Ok;
					(* Call event handlers *)
					item := handlers;
					WHILE item # NIL DO
						item^.handler(EventAdd, p);
						item := item^.next;
					END;
				ELSE
					res := DuplicateName
				END
			ELSE
				res := AlreadyRegistered
			END
		END Add;

		(** Unregister a plugin instance.  Called by plugins to withdraw their availability. *)

		PROCEDURE Remove*(p: Plugin);
		VAR c: Plugin; item: EventHandlerList;
		BEGIN {EXCLUSIVE}
			ASSERT(p # NIL);
			IF p.registry # NIL THEN	(* was registered *)
				IF p = root THEN
					root := root.link
				ELSE
					c := root; WHILE c.link # p DO c := c.link END;
					c.link := p.link
				END;
				p.registry := NIL;
				(* Call event handlers *)
				item := handlers;
				WHILE item # NIL DO
					item^.handler(EventRemove, p);
					item := item^.next;
				END;
			END;
		END Remove;

		(** Add an event handler *)

		PROCEDURE AddEventHandler*(h: EventHandler; VAR res: LONGINT);
		VAR item: EventHandlerList;
		BEGIN {EXCLUSIVE}
			ASSERT(h # NIL);
			item := handlers;
			WHILE (item # NIL) & (item^.handler # h) DO
				item := item^.next;
			END;
			IF (item = NIL) THEN
				NEW(item);
				item^.handler := h;
				item^.next := handlers;
				handlers := item;
				res := Ok;
			ELSE
				res := AlreadyRegistered;
			END;
		END AddEventHandler;

		(** Remove an event handler *)

		PROCEDURE RemoveEventHandler*(h: EventHandler; VAR res: LONGINT);
		VAR item: EventHandlerList;
		BEGIN {EXCLUSIVE}
			ASSERT(h # NIL);
			IF handlers = NIL THEN
				res := NeverRegistered;
			ELSIF handlers^.handler = h THEN
				handlers := handlers^.next;
				res := Ok;
			ELSE
				item := handlers;
				WHILE (item^.next # NIL) & (item^.next^.handler # h) DO
					item := item^.next;
				END;
				IF item^.next = NIL THEN
					res := NeverRegistered;
				ELSE
					item^.next := item^.next^.next;
					res := Ok;
				END;
			END;
		END RemoveEventHandler;

		(** Initialize the registry *)

		PROCEDURE &Init*(CONST name, desc: ARRAY OF CHAR);
		VAR res: LONGINT;
		BEGIN
			root := NIL;
			added := 0;
			handlers := NIL;
			COPY(name, SELF.name); COPY(desc, SELF.desc);
			IF (main # SELF) & (main # NIL) THEN	(* add to global registry *)
				main.Add(SELF, res);
				ASSERT(res = Ok);
			END;
		END Init;

	END Registry;

VAR
	main*: Registry;	(** registry of all registries (excluding itself) *)

PROCEDURE AppendInt(x: LONGINT; VAR to: ARRAY OF CHAR);
VAR i, m: LONGINT;
BEGIN
	ASSERT(x >= 0);
	i := 0; WHILE to[i] # 0X DO INC(i) END;
	IF x # 0 THEN
		m := 1000000000;
		WHILE x < m DO m := m DIV 10 END;
		REPEAT
			to[i] := CHR(48 + (x DIV m) MOD 10); INC(i);
			m := m DIV 10
		UNTIL m = 0
	ELSE
		to[i] := "0"; INC(i)
	END;
	to[i] := 0X
END AppendInt;

PROCEDURE GenName(n: LONGINT; VAR registry, plugin: Name);
BEGIN
	COPY(registry, plugin);
	AppendInt(n, plugin)
END GenName;

BEGIN
	main := NIL; NEW(main, "Registry", "Registry of registries")
END Plugins.

(*
To do (pjm):
o Open, Close?
o flags?
o Messaging?
o Unloading?
o deinitialize a registry.  stop awaiting clients.  invalidate plugins?
*)

(*
History:
06.10.2003	mvt	Added event handling for adding/removing plugins
07.10.2003	mvt	Added Registry.Enumerate()
*)
