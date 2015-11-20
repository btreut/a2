MODULE OdCond;
(* $VCS$
Pre and post conditions for DeltaV. A condition has a numeric code and also a short and (perhaps in the future) a
long description.
$Log$
*)
IMPORT Strings;
CONST
	Ok*                                                    =   0;
	ErrorMsg*                                          =   1;
	MustBeCheckedIn*                            =   2; (* 4.3 CHECKOUT *)
	MustNotUpdateBaselineCollection* =   3; (* 12.11 CHECKOUT *)
	MustBeVcr*                                       =   4; (* Own *)
	MustBeCheckedOutVcr*                    =   5; (* 4.5 UNCHECKOUT *)
	CannotAddToExistingHistory*           =   6; (* 6.7 VERSION-CONTROL *)
	MustBeVersion*								=   7;
	BcmsMustBeCheckedIn*  				 =   8; (* 12.13 UPDATE                  *)
	CannotModifyVcc*							=   9; (*										  *)
	MustHaveRequestBody*                   = 10; (* es *)
	VccMustNotExist*							 = 11; (* 12.6 BASELINE-CONTROL *)
	MustBeBaseline*							  = 12;
	MustHaveNoVcms*						   = 13;
	OneBccPerHistoryPerWorkspace*   = 14;
	NotImplemented*							= 15; (* es *)
	CheckedOutVersionUnchanged*      = 16;
	VersionHistoryIsTree*                        = 17; (* 4.4 CHECKIN *)
	VccMustBeCheckedOut*                   = 18; (*es*)
	MaxCond*                                         = 18;

TYPE
	ShortMsg = ARRAY 128 OF CHAR;

TYPE
	OdCond* = OBJECT
	VAR
		status * : LONGINT;
		short * : ARRAY MaxCond+1 OF ShortMsg;

		PROCEDURE &Init*;
		BEGIN
			status := Ok;
			short[Ok] 												   := "ok";
			short[ErrorMsg]								         := ""; (* See SetError *)
			short[MustBeCheckedIn]						    := "must-be-checked-in";
			short[MustNotUpdateBaselineCollection] := "must-not-update-baseline-collection";
			short[MustBeVcr]									   := "must-be-version-controlled-resource";
			short[MustBeCheckedOutVcr]				   := "must-be-checked-out-version-controlled-resource";
			short[CannotAddToExistingHistory]		   := "cannot-add-to-existing-history";
			short[MustBeVersion]								:= "must-be-version";
			short[BcmsMustBeCheckedIn]                   := "baseline-controlled-members-must-be-checked-in";
			short[CannotModifyVcc]							:= "cannot-modify-version-controlled-configuration";
			short[MustHaveRequestBody]				   := "must-have-request-body";
			short[VccMustNotExist]							 := "version-controlled-configuration-must-not-exist";
			short[MustBeBaseline]							  := "must-be-baseline";
			short[MustHaveNoVcms]						   := "must-have-no-version-controlled-members";
			short[OneBccPerHistoryPerWorkspace]   := "one-baseline-controlled-collection-per-history-per-workspace";
			short[NotImplemented]							:= "not-implemented";
			short[CheckedOutVersionUnchanged]      := "checked-out-version-unchanged";
			short[VersionHistoryIsTree]					   := "version-history-is-tree";
			short[VccMustBeCheckedOut]                  := "version-controlled-configuration-must-be-checked-out";
		END Init;

		PROCEDURE SetError * (statusCode: LONGINT; CONST source: ARRAY OF CHAR; rc: LONGINT);
		VAR intStr: ARRAY 8 OF CHAR;
		BEGIN
			status := statusCode;
			COPY(source, short[ErrorMsg]);
			Strings.Append(short[ErrorMsg], ' ');
			Strings.IntToStr(rc, intStr); Strings.Append(short[ErrorMsg],intStr);
		END SetError;

	END OdCond;

END OdCond.