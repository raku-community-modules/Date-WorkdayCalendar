[![Actions Status](https://github.com/raku-community-modules/Date-WorkdayCalendar/actions/workflows/test.yml/badge.svg)](https://github.com/raku-community-modules/Date-WorkdayCalendar/actions)

NAME
====

Date::WorkdayCalendar - Calendar and Date objects to handle business days, holidays and weekends

SYNOPSIS
========

```raku
use Date::WorkdayCalendar;

# construct a default workday calendar
my $calendar = WorkdayCalendar.new;

# work out the next workday away from the given date
# 2016-11-18 is a Friday
$calendar.workdays-away(Date.new('2016-11-18'), 1);  # 2016-11-21

# construct a workday calendar from a file
my $calendar-from-file = WorkdayCalendar.new('days.cal');

# create a workdate from a date string
my $workdate = Workdate.new('2016-05-02');

# create a workdate from a Date object
my $date = Date.new('2016-11-18');
my $workdate-from-date = Workdate.new($date);

# is the day a workday?
$workdate = Workdate.new('2016-11-18');
$workdate.is-workday;  # True
$workdate.is-weekend;  # False
$workdate.is-holiday;  # False
```

DESCRIPTION
===========

The `WorkdayCalendar` and `Workdate` objects allow date calculations to be made on a calendar that considers workdays (also called "business days").

Built on top of the `Date` datatype, it uses a calendar file to specify how many days a workweek has and which days are to be considered holidays.

By default, the workweek is composed of Monday, Tuesday, Wednesday, Thursday, and Friday. Saturday and Sunday form the weekend.

Although most countries have a Monday to Friday workweek, some have very different ones.

More information about workweeks can be found at [http://en.wikipedia.org/wiki/Workweek](http://en.wikipedia.org/wiki/Workweek).

INTRODUCTION
============

The module provides two classes: `WorkdayCalendar` and `Workday`. Objects of these classes allow date calculations to be made on a calendar that takes workdays (also called "business days") into account.

Built on top of the `Date` datatype, it uses a calendar file to specify how many days a workweek has and which days are to be considered holidays.

By default, the *workweek* is composed by **Mon**, **Tue**, **Wed**, **Thu**, and **Fri**. **Sat** and **Sun** form the *weekend*.

Alhough most countries have a workweek of **Mon** to **Fri**, some have very different ones.

More information about workweeks can be found at [http://en.wikipedia.org/wiki/Workweek](http://en.wikipedia.org/wiki/Workweek).

CALENDAR FILE FORMAT
====================

    # An example calendar file
    W:Mon,Tue,Wed,Thu,Fri
    H:2011/01/01
    H:2011-04-05

This calendar specifies that **Mon** to **Fri** are to be considered workdays, and that 2011/01/01 and 2011/04/05 are national holidays. You can use `/` or `-` as separators in a date. The format of the date **must be** in the order Year, Month, Day.

If the `W:` specification is incorrect, the default workweek (**Mon**, **Tue**, **Wed**, **Thu**, **Fri**) is used. If a holiday (a row starting with `H:`) is not well defined, it is ignored.

Lines starting with `#` are comments and will be ignored when parsing the file.

WorkdayCalendar class
=====================

method new
----------

```raku
my $wdc1 = WorkdayCalendar.new;
my $wdc2 = WorkdayCalendar.new('calendar.cal');
```

Creates a new calendar. Optionally, accepts the name of a file using the calendar format specified above. If a filename is not specified, the calendar will have no holidays and a default workweek of **Mon**, **Tue**, **Wed**, **Thu**, **Fri**.

method clear
------------

Empties the information for holidays and workdays, and resets the workweek to the default: **Mon**, **Tue**, **Wed**, **Thu**, **Fri**.

method read(Str $calendar_filename)
-----------------------------------

Reads the data of holidays and workdays from a calendar file.

method is-workday(Date $day)
----------------------------

Returns `True` if the day is part of the workweek and not a holiday.

method is-weekend(Date $day)
----------------------------

Returns `True` if the day is not part of the workweek.

method is-holiday(Date $day)
----------------------------

Returns `True` if the day has been defined as holiday in the calendar file.

method workdays-away(Date $start, Int $days)
--------------------------------------------

Returns a `Date` that corresponds to the workday at which `$days` working days have passed. With this method you can ask questions like: "what is the next working day for some date?" or "what is the previous working day of some date?" or "what date is 2 working days from a date?".

Examples:

Considering the workdays = **Mon Tue Wed Thu Fri**...

    $start       : July 29, 2011 (it is a Friday)
    $days        : +1
    Return Value : Aug 1, 2011 (it is a Monday)

    $start       : July 30, 2011 (it is a Saturday)
    $days        : +1
    Return Value : Aug 1, 2011 (it is a Monday)

This also works for a negative number of days.

method workdays-to(Date $start, Date $target)
---------------------------------------------

Returns the 'distance', in workdays, of `$start` and `$target` dates.

method networkdays(Date $start, Date $target)
---------------------------------------------

Works like the `workdays-to` method, but emulates the NETWORKDAYS function in Microsoft Excel.

Examples:

       Start     Target    workdays-to     networkdays
    2011-07-07  2011-07-14     5              6
    2011-07-07  2011-07-07     0              1
    2011-07-07  2011-07-08     1              2
    2011-07-07  2011-07-01    -4             -5
    2011-01-01  2011-01-01     0              0
    2011-01-01  2011-01-02     0              0
    2011-01-01  2011-01-03     1              1

method range(Date $start, Date $end)
------------------------------------

Returns a part of a calendar as a new `WorkdayCalendar` object, between the `$start` and `$end` dates, inclusive. For example, if you have a calendar that contains holiday information for 3 years, you can use `range` to obtain a new calendar that covers a period of 6 months of these 3 years. Useful with the `eq` operator for `WorkdayCalendar` objects.

method raku
-----------

Returns a string representing the contents of the `WorkdayCalendar` attributes.

`Workdate` class
================

Implemented as a subclass of `Date`. It replaces `Date`'s `.succ` and `.pred` methods to take workdays into account and provides the functionality to perform basic workdate calculations.

You can specify a previously created `WorkdayCalendar` object as a parameter, or none at all. If a `WorkdayCalendar` is not specified, it uses a default workweek of **Mon** , **Tue**, **Wed**, **Thu**, **Fri** and no holidays.

Example:

```raku
# July 1st of 2011 is a Friday
my $wdate = Workdate.new(year=>2011, month=>07, day=>01); #--- Uses a default calendar with
                                                          #--- default workweek and no holidays
my $next_day = $wdate.succ; # $next_day is Monday, July 4, 2011
```

Another example:

```raku
my $CAL = WorkdayCalendar.new('example.cal'); # Some calendar file with 2011-Feb-2 as holiday
my $date = Workdate.new(year=>2011, month=>02, day=>01, calendar=>$CAL);
# February 1 of 2011 is a Tuesday
my $next_day = $date.succ; # $next_day is Thursday, February 3, 2011
```

method new
----------

```raku
my $wd1 = Workdate.new(year=>2000, month=>12, day=>01, calendar=>$aWorkdayCalendar);
my $wd2 = Workdate.new(2000, 12, 01, $aWorkdayCalendar);
my $wd3 = Workdate.new($aDateString, $aWorkdayCalendar);
my $wd4 = Workdate.new($aDateTimeObject, $aWorkdayCalendar);
my $wd4 = Workdate.new($aDateObject, $aWorkdayCalendar);
```

We try to provide the same constructors as the base `Date` class, plus another to create `Workdate`s from regular `Date`s. Thus, we can create a `Workdate` in 4 different ways, from named and positional parameters, and by using a `Date` or a `DateTime` object for specifying the date. In all cases, the calendar is optional, and if it is not specified a default calendar will be applied to the new `Workdate`.

method succ
-----------

Returns the next workdate.

method pred
-----------

Returns the previous workdate.

method is-workday
-----------------

Returns True if the workdate is not a holiday and is not part of the weekend.

method is-weekend
-----------------

Returns True if the workdate is not part of the workweek.

method is-holiday
-----------------

Returns True if the workdate is reported as a holiday.

method workdays-away(Int $days)
-------------------------------

Returns the workdate that is `$days` workdays from the given workdate.

method workdays-to(Date $target)
--------------------------------

Return the number of workdays until `$target`.

method raku
-----------

Returns a string representing the contents of the `Workdate` attributes.

OPERATORS
=========

Comparison: eq
--------------

Compares two calendars and returns True if they are equivalent. For that, they must have the same holidays and the same workweek. For instance, this would be as if they used the same calendar file.

You can use the `range` method for `WorkdayCalendar` objects to compare smaller periods of time instead of a whole `WorkdayCalendar`.

Comparison: ne
--------------

Returns the opposite of `eq`.

Arithmetic: infix -
-------------------

Returns the difference, in workdays, between `$wd1` and `$wd2`.

AUTHOR
======

Shinobi

COPYRIGHT AND LICENSE
=====================

Copyright 2012 - 2013 Shinobi

Copyright 2014 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

