MODULE TestDates; (** AUTHOR "staubesv"; PURPOSE "Test for function of Dates.Mod"; *)

IMPORT
	Modules, Streams, Commands, Dates, Strings, Random;

VAR
	stop : BOOLEAN;
	nofRunningTests : LONGINT;

PROCEDURE AddYear(VAR time : Dates.DateTime);
BEGIN
	INC(time.year);
END AddYear;

PROCEDURE AddMonth(VAR time : Dates.DateTime);
BEGIN
	IF (time.month = 12) THEN
		time.month := 1; AddYear(time);
	ELSE
		INC(time.month);
	END;
END AddMonth;

PROCEDURE AddDay(VAR time : Dates.DateTime);
BEGIN
	IF (time.day = Dates.NofDays(time.year, time.month)) THEN
		time.day := 1; AddMonth(time);
	ELSE
		INC(time.day);
	END;
END AddDay;

PROCEDURE AddHour(VAR time : Dates.DateTime);
BEGIN
	IF (time.hour = 23) THEN
		time.hour := 0; AddDay(time);
	ELSE
		INC(time.hour);
	END;
END AddHour;

PROCEDURE AddMinute(VAR time : Dates.DateTime);
BEGIN
	IF (time.minute = 59) THEN
		time.minute := 0; AddHour(time);
	ELSE
		INC(time.minute);
	END;
END AddMinute;

PROCEDURE AddSecond(VAR time : Dates.DateTime);
BEGIN
	IF (time.second = 59) THEN
		time.second := 0; AddMinute(time);
	ELSE
		INC(time.second);
	END;
END AddSecond;

PROCEDURE ToSeconds(days, hours, minutes, seconds : LONGINT) : LONGINT;
BEGIN
	RETURN days * 86400 + hours * 3600 + minutes * 60 + seconds;
END ToSeconds;

PROCEDURE Show(time : Dates.DateTime; out : Streams.Writer);
VAR string : ARRAY 256 OF CHAR;
BEGIN
	Strings.DateToStr(time, string); out.String(string); out.String("  ");
	Strings.TimeToStr(time, string); out.String(string);
END Show;

PROCEDURE TestTimeDifference*(context : Commands.Context);
VAR t1, t2 : Dates.DateTime; diff, days, hours, minutes, seconds, i : LONGINT;
BEGIN
	IncNofRunningTests;
	t1 := Dates.Now();
	t2 := t1;
	diff := 0;
	FOR i := 0 TO MAX(LONGINT)-1 DO
		IF (i MOD 10000000 = 0) THEN
			context.out.Int(ENTIER(100 *  (i / MAX(LONGINT)) ), 0); context.out.String("%, delta = ");
			Strings.ShowTimeDifference(t1, t2, context.out);
			context.out.String(" (T1="); Show(t1, context.out); context.out.String(", T2="); Show(t2, context.out); context.out.String(")");
			context.out.Ln; context.out.Update;
		END;
		Dates.TimeDifference(t1, t2, days, hours, minutes, seconds);
		diff := days * 86400 + hours * 3600 + minutes * 60 + seconds;
		IF (diff # i) THEN
			context.out.String("ERROR: Should: "); context.out.Int(i, 0);
			context.out.String(", but is: "); context.out.Int(diff, 0);
			context.out.String(" ( T1 = "); Show(t1, context.out);
			context.out.String(", T2 = "); Show(t2, context.out); context.out.String(" )");
			context.out.Ln;
			RETURN;
		END;
		IF stop THEN RETURN END;
		AddSecond(t2);
		ASSERT(Dates.ValidDateTime(t2));
	END;
	DecNofRunningTests;
END TestTimeDifference;

PROCEDURE TestAddX*(context : Commands.Context);
CONST MaxDelta = 1000;
VAR
	dtRef, dt : Dates.DateTime;
	days, hours, minutes, seconds : LONGINT;
	random : Random.Generator;
	expectedDifference : LONGINT;
	value, i : LONGINT;
BEGIN
	IncNofRunningTests;
	dtRef := Dates.Now();
	NEW(random);
	random.InitSeed(dt.second + 100 * dt.minute);
	i := 0;
	LOOP
		dt := dtRef;
		value := random.Dice(2 * MaxDelta) - MaxDelta;
		expectedDifference := ToSeconds(value, value, value, value);
		IF (expectedDifference < 0) THEN expectedDifference := -expectedDifference; END;

		Dates.AddSeconds(dt, value);
		Dates.AddMinutes(dt, value);
		Dates.AddHours(dt, value);
		Dates.AddDays(dt, value);

		Dates.TimeDifference(dt, dtRef, days, hours, minutes, seconds);

		IF (expectedDifference # ToSeconds(days, hours, minutes, seconds)) THEN
			context.out.String("ERROR: Difference between ");
			Show(dtRef, context.out); context.out.String(" and "); Show(dt, context.out);
			context.out.String(" is expected as ");
			context.out.Int(expectedDifference, 0); context.out.String(", but result is ");
			context.out.Int(ToSeconds(days, hours, minutes, seconds), 0);
			context.out.Ln;
			RETURN;
		END;

		IF (i MOD 1000000 = 0) THEN
			context.out.Int(i, 0); context.out.String(" TestAddX tests performed.");
			context.out.Ln; context.out.Update;
		END;
		INC(i);
		IF (i = MAX(LONGINT)) OR stop THEN EXIT; END;
	END;
	DecNofRunningTests;
END TestAddX;

PROCEDURE TestToday*(context:Commands.Context);
VAR dt: Dates.DateTime;
	year, week, weekday:LONGINT;
	dayTable: ARRAY 25 OF CHAR;
BEGIN
	dt:=Dates.Now();
	Dates.WeekDate(dt, year, week, weekday);
	context.out.Int(year,6); context.out.Int(week,6); context.out.Int(weekday,6); context.out.Ln; context.out.Ln;
	dayTable := "SunMonTueWedThuFriSatSun"; 
	context.out.Char(dayTable[weekday*3]); context.out.Char(dayTable[weekday*3+1]); context.out.Char(dayTable[weekday*3+2]); context.out.Ln; context.out.Update; 
END TestToday;


PROCEDURE IncNofRunningTests;
BEGIN {EXCLUSIVE}
	INC(nofRunningTests);
END IncNofRunningTests;

PROCEDURE DecNofRunningTests;
BEGIN {EXCLUSIVE}
	DEC(nofRunningTests);
END DecNofRunningTests;

PROCEDURE Cleanup;
BEGIN {EXCLUSIVE}
	stop := TRUE;
	AWAIT(nofRunningTests = 0);
END Cleanup;

BEGIN
	nofRunningTests := 0;
	stop := FALSE;
	Modules.InstallTermHandler(Cleanup);
END TestDates.

SystemTools.Free TestDates ~

TestDates.TestTimeDifference ~

TestDates.TestAddX ~
TestDates.TestToday ~
