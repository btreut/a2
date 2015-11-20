MODULE Dates; (** AUTHOR "be, tf, staubesv"; PURPOSE "Date and time functions"; *)

(** Oberon date & time format:
		time: bits 16-12: hours
					11-6: minutes
					5-0: seconds

		date: 30-9: count of years from 1900
					8-5: month of year
					4-0: day of month
*)

(*	Problem of leap seconds is handled as in POSIX: 
		http://www.eecis.udel.edu/~mills/leap.html
		http://en.wikipedia.org/wiki/Leap_second
*)

IMPORT
	Clock;

TYPE

	DateTime* = RECORD
		year*, month*, day*,
		hour*, minute*, second*: LONGINT
	END;

VAR
	Months-: ARRAY 12 OF ARRAY 10 OF CHAR;	(** month's names (January = 0....December=11) *)
	Days-: ARRAY 7 OF ARRAY 10 OF CHAR;	(** day's names (Moday = 0, .... Sunday = 6) *)
	NoDays: ARRAY 12 OF INTEGER;
	ZeroDateUnix-, ZeroDateRFC868-, ZeroDateNTP-: DateTime;

(** Date and Time functions *)

(** returns TRUE if 'year' is a leap year *)
PROCEDURE LeapYear*(year: LONGINT): BOOLEAN;
BEGIN
	RETURN (year > 0) & (year MOD 4 = 0) & (~(year MOD 100 = 0) OR (year MOD 400 = 0))
END LeapYear;

(** returns the number of days in that month *)
PROCEDURE NofDays*(year, month: LONGINT): LONGINT;
BEGIN
	DEC(month);
	ASSERT((month >= 0) & (month < 12));
	IF (month = 1) & LeapYear(year) THEN RETURN NoDays[1]+1
	ELSE RETURN NoDays[month]
	END
END NofDays;

(** checks if the values of a DateTime structure are valid *)
PROCEDURE ValidDateTime*(dt: DateTime): BOOLEAN;
BEGIN
	RETURN (dt.year > 0) & (dt.month > 0) & (dt.month <= 12) & (dt.day > 0) & (dt.day <= NofDays(dt.year, dt.month)) &
		(dt.hour >= 0) & (dt.hour < 24) & (dt.minute >= 0) & (dt.minute < 60) & (dt.second >= 0) & (dt.second < 60)
END ValidDateTime;

(** convert an Oberon date/time to a DateTime structure *)
PROCEDURE OberonToDateTime*(Date, Time: LONGINT): DateTime;
VAR dt: DateTime;
BEGIN
	dt.second := Time MOD 64; Time := Time DIV 64;
	dt.minute := Time MOD 64; Time := Time DIV 64;
	dt.hour := Time MOD 24;
	dt.day := Date MOD 32; Date := Date DIV 32;
	dt.month := Date MOD 16; Date := Date DIV 16;
	dt.year := 1900 + Date;
	RETURN dt
END OberonToDateTime;

(** convert a DateTime structure to an Oberon date/time *)
PROCEDURE DateTimeToOberon*(dt: DateTime; VAR date, time: LONGINT);
BEGIN
	ASSERT(ValidDateTime(dt));
	date := (dt.year-1900)*512 + dt.month*32 + dt.day;
	time := dt.hour*4096 + dt.minute*64 + dt.second
END DateTimeToOberon;

(** returns the current date and time *)
PROCEDURE Now*(): DateTime;
VAR d, t: LONGINT;
BEGIN
	Clock.Get(t, d);
	RETURN OberonToDateTime(d, t)
END Now;

(** returns the ISO 8601 year number, week number & week day (Monday=1, ....Sunday=7) *)
(* algorithm by Rick McCarty, http://personal.ecu.edu/mccartyr/ISOwdALG.txt *)
PROCEDURE WeekDate*(Date: DateTime; VAR year, week, weekday: LONGINT);
VAR doy, i, yy, c, g, jan1: LONGINT; leap: BOOLEAN;
BEGIN
	IF ValidDateTime(Date) THEN
		leap := LeapYear(Date.year);
		doy := Date.day; i := 0;
		WHILE (i < Date.month-1) DO doy := doy + NoDays[i]; INC(i) END;
		IF leap & (Date.month > 2) THEN INC(doy) END;
		yy := (Date.year-1) MOD 100; c := (Date.year-1) - yy; g := yy + yy DIV 4;
		jan1 := 1 + (((((c DIV 100) MOD 4) * 5) + g) MOD 7);

		weekday := 1 + (((doy + (jan1-1))-1) MOD 7);

		IF (doy <= (8-jan1)) & (jan1 > 4) THEN			(* falls in year-1 ? *)
			year := Date.year-1;
			IF (jan1 = 5) OR ((jan1 = 6) & LeapYear(year)) THEN week := 53
			ELSE week := 52
			END
		ELSE
			IF leap THEN i := 366 ELSE i := 365 END;
			IF ((i - doy) < (4 - weekday)) THEN
				year := Date.year + 1;
				week := 1
			ELSE
				year := Date.year;
				i := doy + (7-weekday) + (jan1-1);
				week := i DIV 7;
				IF (jan1 > 4) THEN DEC(week) END
			END
		END
	ELSE
		year := -1; week := -1; weekday := -1
	END
END WeekDate;

PROCEDURE Equal*(t1, t2 : DateTime) : BOOLEAN;
BEGIN
	RETURN
		(t1.second = t2.second) & (t1.minute = t2.minute) & (t1.hour = t2.hour) &
		(t1.day = t2.day) & (t1.month = t2.month) & (t1.year = t2.year);
END Equal;

(** Returns -1 if (t1 < t2), 0 if (t1 = t2) or 1 if (t1 >  t2) *)
PROCEDURE CompareDateTime*(t1, t2 : DateTime) : LONGINT;
VAR result : LONGINT;

	PROCEDURE Compare(t1, t2 : LONGINT) : LONGINT;
	VAR result : LONGINT;
	BEGIN
		IF (t1 < t2) THEN result := -1;
		ELSIF (t1 > t2) THEN result := 1;
		ELSE result := 0;
		END;
		RETURN result;
	END Compare;

BEGIN
	ASSERT(ValidDateTime(t1) & (ValidDateTime(t2)));
	result := Compare(t1.year, t2.year);
	IF (result = 0) THEN
		result := Compare(t1.month, t2.month);
		IF (result = 0) THEN
			result := Compare(t1.day, t2.day);
			IF (result = 0) THEN
				result := Compare(t1.hour, t2.hour);
				IF (result = 0) THEN
					result := Compare(t1.minute, t2.minute);
					IF (result = 0) THEN
						result := Compare(t1.second, t2.second);
					END;
				END;
			END;
		END;
	END;
	RETURN result;
END CompareDateTime;

(** Absolute time difference between t1 and t2. 
Note that leap seconds are not counted, see http://www.eecis.udel.edu/~mills/leap.html *)
PROCEDURE TimeDifference*(t1, t2 : DateTime; VAR days, hours, minutes, seconds : LONGINT);
CONST SecondsPerMinute = 60; SecondsPerHour = 3600; SecondsPerDay = 86400;
VAR start, end : DateTime; year, month, second : LONGINT;
BEGIN
	IF (CompareDateTime(t1, t2) = -1) THEN start := t1; end := t2; ELSE start := t2; end := t1; END;
	IF (start.year = end.year) & (start.month = end.month) & (start.day = end.day) THEN
		second := end.second - start.second + (end.minute - start.minute) * SecondsPerMinute + (end.hour - start.hour) * SecondsPerHour;
		days := 0;
	ELSE
		(* use start date/time as reference point *)
		(* seconds until end of the start.day *)
		second := SecondsPerDay - start.second - start.minute * SecondsPerMinute - start.hour * SecondsPerHour;
		IF (start.year = end.year) & (start.month = end.month) THEN
			(* days between start.day and end.day *)
			days := (end.day - start.day) - 1;
		ELSE
			(* days until start.month ends excluding start.day *)
			days := NofDays(start.year, start.month) - start.day;
			IF (start.year = end.year) THEN
				(* months between start.month and end.month *)
				FOR month := start.month + 1 TO end.month - 1 DO
					days := days + NofDays(start.year, month);
				END;
			ELSE
				(* days until start.year ends (excluding start.month) *)
				FOR month := start.month + 1 TO 12 DO
					days := days + NofDays(start.year, month);
				END;
				FOR year := start.year + 1 TO end.year - 1 DO (* days between start.years and end.year *)
					IF LeapYear(year) THEN days := days + 366; ELSE days := days + 365; END;
				END;
				FOR month := 1 TO end.month - 1 DO (* days until we reach end.month in end.year *)
					days := days + NofDays(end.year, month);
				END;
			END;
			(* days in end.month until reaching end.day excluding end.day *)
			days := days + end.day - 1;
		END;
		(* seconds in end.day *)
		second := second + end.second + end.minute * SecondsPerMinute + end.hour * SecondsPerHour;
	END;
	days := days + (second DIV SecondsPerDay); second := second MOD SecondsPerDay;
	hours := second DIV SecondsPerHour; second := second MOD SecondsPerHour;
	minutes := second DIV SecondsPerMinute; second := second MOD SecondsPerMinute;
	seconds := second;
END TimeDifference;

(** Add/Subtract a number of years to/from dt *)
PROCEDURE AddYears*(VAR dt : DateTime; years : LONGINT);
BEGIN
	ASSERT(ValidDateTime(dt));
	dt.year := dt.year + years;
	ASSERT(ValidDateTime(dt));
END AddYears;

(** Add/Subtract a number of months to/from dt. This will adjust dt.year if necessary *)
PROCEDURE AddMonths*(VAR dt : DateTime; months : LONGINT);
VAR years : LONGINT;
BEGIN
	ASSERT(ValidDateTime(dt));
	years := months DIV 12;
	dt.month := dt.month + (months MOD 12);
	IF (dt.month > 12) THEN
		dt.month := dt.month - 12;
		INC(years);
	ELSIF (dt.month < 1) THEN
		dt.month := dt.month + 12;
		DEC(years);
	END;
	IF (years # 0) THEN AddYears(dt, years); END;
	ASSERT(ValidDateTime(dt));
END AddMonths;

(** Add/Subtract a number of days to/from dt. This will adjust dt.month and dt.year if necessary *)
PROCEDURE AddDays*(VAR dt : DateTime; days : LONGINT);
VAR nofDaysLeft : LONGINT;
BEGIN
	ASSERT(ValidDateTime(dt));
	IF (days > 0) THEN
		WHILE (days > 0) DO
			nofDaysLeft := NofDays(dt.year, dt.month) - dt.day;
			IF (days > nofDaysLeft) THEN
				dt.day := 1;
				AddMonths(dt, 1);
				days := days - nofDaysLeft - 1; (* -1 because we consume the first day of the next month *)
			ELSE
				dt.day := dt.day + days;
				days := 0;
			END;
		END;
	ELSIF (days < 0) THEN
		days := -days;
		WHILE (days > 0) DO
			nofDaysLeft := dt.day - 1;
			IF (days > nofDaysLeft) THEN
				dt.day := 1; (* otherwise, dt could become an invalid date if the previous month has less days than dt.day *)
				AddMonths(dt, -1);
				dt.day := NofDays(dt.year, dt.month);
				days := days - nofDaysLeft - 1; (* -1 because we consume the last day of the previous month *)
			ELSE
				dt.day := dt.day - days;
				days := 0;
			END;
		END;
	END;
	ASSERT(ValidDateTime(dt));
END AddDays;

(** Add/Subtract a number of hours to/from dt. This will adjust dt.day, dt.month and dt.year if necessary *)
PROCEDURE AddHours*(VAR dt : DateTime; hours : LONGINT);
VAR days : LONGINT;
BEGIN
	ASSERT(ValidDateTime(dt));
	dt.hour := dt.hour + hours;
	days := dt.hour DIV 24;
	dt.hour := dt.hour MOD 24;
	IF (dt.hour < 0) THEN
		dt.hour := dt.hour + 24;
		DEC(days);
	END;
	IF (days # 0) THEN AddDays(dt, days); END;
	ASSERT(ValidDateTime(dt));
END AddHours;

(** Add/Subtract a number of minutes to/from dt. This will adjust dt.hour, dt.day, dt.month and dt.year if necessary *)
PROCEDURE AddMinutes*(VAR dt : DateTime; minutes : LONGINT);
VAR hours : LONGINT;
BEGIN
	ASSERT(ValidDateTime(dt));
	dt.minute := dt.minute + minutes;
	hours := dt.minute DIV 60;
	dt.minute := dt.minute MOD 60;
	IF (dt.minute < 0) THEN
		dt.minute := dt.minute + 60;
		DEC(hours);
	END;
	IF (hours # 0) THEN AddHours(dt, hours); END;
	ASSERT(ValidDateTime(dt));
END AddMinutes;

(** Add/Subtract a number of seconds to/from dt. This will adjust dt.minute, dt.hour, dt.day, dt.month and dt.year if necessary *)
PROCEDURE AddSeconds*(VAR dt : DateTime; seconds : LONGINT);
VAR minutes : LONGINT;
BEGIN
	ASSERT(ValidDateTime(dt));
	dt.second := dt.second + seconds;
	minutes := dt.second DIV 60;
	dt.second := dt.second MOD 60;
	IF (dt.second < 0) THEN
		dt.second := dt.second + 60;
		DEC(minutes);
	END;
	IF (minutes # 0) THEN AddMinutes(dt, minutes); END;
	ASSERT(ValidDateTime(dt));
END AddSeconds;

BEGIN
	Months[0] := "January"; Months[1] := "February"; Months[2] := "March"; Months[3] := "April"; Months[4] := "May";
	Months[5] := "June"; Months[6] := "July"; Months[7] := "August"; Months[8] := "September";
	Months[9] := "October"; Months[10] := "November"; Months[11] := "December";
	Days[0] := "Monday"; Days[1] := "Tuesday"; Days[2] := "Wednesday"; Days[3] := "Thursday";
	Days[4] := "Friday"; Days[5] := "Saturday"; Days[6] := "Sunday";
	NoDays[0] := 31; NoDays[1] := 28; NoDays[2] := 31; NoDays[3] := 30; NoDays[4] := 31; NoDays[5] := 30;
	NoDays[6] := 31; NoDays[7] := 31; NoDays[8] := 30; NoDays[9] := 31; NoDays[10] := 30; NoDays[11] := 31;
	ZeroDateUnix.year:=1970; ZeroDateUnix.month:=1; ZeroDateUnix.day:=1;
	ZeroDateRFC868.year:=1900; ZeroDateRFC868.month:=1; ZeroDateRFC868.day:=1;
	ZeroDateNTP:=ZeroDateRFC868;
END Dates.
