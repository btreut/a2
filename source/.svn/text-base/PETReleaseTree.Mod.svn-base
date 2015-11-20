MODULE PETReleaseTree; (** AUTHOR "staubesv"; PURPOSE "Visualize build description structure as tree"; *)

IMPORT
	Streams, Strings, Diagnostics, Build := Release, PETTrees, WMTrees;

CONST
	Title = " Packages";
	TitleError = " Packages (Errors)";

TYPE
	String = ARRAY 128 OF CHAR;

	Tree* = OBJECT (PETTrees.Tree)

		PROCEDURE & Init*;
		BEGIN
			Init^;
			SetTitle(Title);
		END Init;

		PROCEDURE AddNodes(parent : PETTrees.TreeNode; diagnostics : Diagnostics.Diagnostics; log : Streams.Writer);
		VAR builds : Build.Builds; succeeded : BOOLEAN;
		BEGIN
			AddNodes^(parent, diagnostics, log);
			succeeded := Build.ParseBuildDescription(editor.text, "ReleaseTree", builds, log, diagnostics);
			IF succeeded THEN
				tree.SetNodeCaption(parent, Strings.NewString("Packages"));
				tree.SetNodeState(parent, {WMTrees.NodeAlwaysExpanded});
				NEW(parent.pos, editor.text);
				parent.pos.SetPosition(0);
				AddBuilds(parent, builds);
				AddPackages(parent, builds.packages.GetAll());
				SetTitle(Title);
			ELSE
				SetTitle(TitleError);
			END;
		END AddNodes;

		PROCEDURE AddBuilds(parent : WMTrees.TreeNode; builds : Build.Builds);
		VAR node : PETTrees.TreeNode; nofBuilds, i : LONGINT;
		BEGIN
			nofBuilds := 0;
			node := NewNode(parent, "BUILDS");
			FOR i := 0 TO LEN(builds.builds)-1 DO
				IF (builds.builds[i] # NIL) THEN
					IF (nofBuilds = 0) THEN
						SetNodeInfo(node, builds.builds[i].position);
					END;
					INC(nofBuilds);
					AddBuild(node, builds.builds[i]);
				END;
			END;
			AddNumberPostfixToCaption(node, nofBuilds);
		END AddBuilds;

		PROCEDURE AddBuild(parent : WMTrees.TreeNode; build : Build.BuildObj);
		VAR buildNode, node : PETTrees.TreeNode; nofSources, nofFiles : LONGINT;
		BEGIN
			ASSERT(build # NIL);
			buildNode := NewNode(parent, build.name);
			SetNodeInfo(buildNode, build.position);
			build.GetInfo(nofSources, nofFiles);
			node := NewNode(buildNode, GetNumberCaption("Sources: ", nofSources));
			node := NewNode(buildNode, GetNumberCaption("Files: ", nofFiles));
		END AddBuild;

		PROCEDURE AddPackages(parent : WMTrees.TreeNode; packages : Build.PackageArray);
		VAR node : PETTrees.TreeNode; nofPackages, i : LONGINT;
		BEGIN
			nofPackages := 0;
			node := NewNode(parent, "PACKAGES");
			tree.SetNodeState(node, {WMTrees.NodeExpanded});
			IF (packages # NIL) THEN
				FOR i := 0 TO LEN(packages)-1 DO
					IF (packages[i] # NIL) THEN
						IF (nofPackages = 0) THEN
							SetNodeInfo(node, packages[i].position);
						END;
						INC(nofPackages);
						AddPackage(node, packages[i]);
					END;
				END;
			END;
			AddNumberPostfixToCaption(node, nofPackages);
		END AddPackages;

		PROCEDURE AddPackage(parent : WMTrees.TreeNode; package : Build.Package);
		VAR node, packageNode : PETTrees.TreeNode;
		BEGIN
			ASSERT((parent # NIL) & (package # NIL));
			packageNode := NewNode(parent, package.name);
			SetNodeInfo(packageNode, package.position);

			node := NewNode(packageNode, GetNumberCaption("Sources: ", package.nofSources));
			node := NewNode(packageNode, GetNumberCaption("Files: ", package.nofFiles));
			node := NewNode(packageNode, GetCaption("Archive: ", package.archive));
			node := NewNode(packageNode, GetCaption("ArchiveSrc: ", package.source));
		END AddPackage;

		PROCEDURE SetNodeInfo(node : PETTrees.TreeNode; position : LONGINT);
		BEGIN
			ASSERT(node # NIL);
			IF (position >= 0) THEN
				NEW(node.pos, editor.text);
				node.pos.SetPosition(position);
			ELSE
				node.pos := NIL;
			END;
		END SetNodeInfo;

		PROCEDURE NewNode(parent: WMTrees.TreeNode; CONST caption: ARRAY OF CHAR): PETTrees.TreeNode;
		VAR node: PETTrees.TreeNode;
		BEGIN
			ASSERT(parent # NIL);
			NEW(node);
			tree.SetNodeCaption(node, Strings.NewString(caption));
			tree.AddChildNode(parent, node);
			ASSERT(node # NIL);
			RETURN node;
		END NewNode;

	END Tree;

PROCEDURE GetNumberCaption(CONST string : ARRAY OF CHAR; number : LONGINT) : String;
VAR caption : String; nbr : ARRAY 16 OF CHAR;
BEGIN
	COPY(string, caption); Strings.IntToStr(number, nbr); Strings.Append(caption, nbr);
	RETURN caption;
END GetNumberCaption;

PROCEDURE GetCaption(CONST string1, string2 : ARRAY OF CHAR) : String;
VAR caption : String;
BEGIN
	COPY(string1, caption); Strings.Append(caption, string2);
	RETURN caption;
END GetCaption;

PROCEDURE GenBuildTree*() : PETTrees.Tree;
VAR tree : Tree;
BEGIN
	NEW(tree); RETURN tree;
END GenBuildTree;

END PETReleaseTree.

SystemTools.Free ReleaseTree ~