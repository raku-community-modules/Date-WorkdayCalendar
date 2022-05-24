class WorkdayCalendar {
    has Str  $.file     is rw;
    has Date @.holidays is rw;
    has Str  @.workdays is rw = <Mon Tue Wed Thu Fri>;

    method clear {
        @.workdays = <Mon Tue Wed Thu Fri>;
        @.holidays = ();
    }

    multi method new(WorkdayCalendar: Str:D :$filename!) {
        my $c := WorkdayCalendar.new;
        $c.read($filename);
        $c
    }

    multi method new(WorkdayCalendar: Str:D $filename) {
        WorkdayCalendar.new(:$filename)
    }

    multi method raku(WorkdayCalendar:D:) {
        self.^name
          ~ '.new('
          ~ @.workdays.raku
          ~ ', '
          ~ @.holidays.raku
          ~ ', '
          ~ $.file.raku
          ~ ')'
    }

    method read(WorkdayCalendar:D: Str:D $calendar_filename) {
        .die without my $CAL := open $calendar_filename;
        LEAVE .close with $CAL;

        $.file = $calendar_filename;
        self.clear;

        #--- Comments are skipped
        for $CAL.lines.grep(!*.starts-with('#')) -> $line {

            my ($type, $data) = split /':'/, $line;
            given $type {
                when 'H' {
                    my ($year, $month, $day) = split /'/'|'-'/, $data; #--- Only Holidays '
                    try {
                        CATCH {
                            $*TESTING || note "ERROR: Specifying holiday date. Date $year-$month-$day skipped";
                            next;
                        }
                        push @.holidays, Date.new(:$year, :$month, :$day);
                    }
                }
                when 'W' {
                    try {
                        my @workweek_spec = split /','/, $data;
                        my $workweek_spec_failed = False;
                        for @workweek_spec -> $weekday {
                            if ($weekday ne any(<Mon Tue Wed Thu Fri Sat Sun>)) {
                                $*TESTING || warn "Workday '$weekday' not recognized";
                                $workweek_spec_failed = True;
                                last;
                            }
                        }
                        if ($workweek_spec_failed) {
                            $*TESTING || note "ERROR: Workweek specification not valid. Assuming Mon,Tue,Wed,Thu,Fri";
                            @.workdays = <Mon Tue Wed Thu Fri>;
                            next;
                        }
                        else {
                            @.workdays = @workweek_spec;
                        }
                    }
                }
            }
        }
        @.holidays .= sort;
    }

    method is-workday(WorkdayCalendar:D: Date:D $day){
        !(self.is-weekend($day) || self.is-holiday($day))
    }

    method is-weekend(WorkdayCalendar:D: Date:D $day) {
        my $weekday_name = <Mon Tue Wed Thu Fri Sat Sun>[$day.day-of-week - 1];
        not $weekday_name eq any(@.workdays)
    }

    method is-holiday(WorkdayCalendar:D: Date:D $day) {
        my @daycounts;
        push @daycounts, .daycount for @.holidays;
        $day.daycount == any(@daycounts)
    }

    method workdays-away(WorkdayCalendar:D:
      Date:D $start,
      Int:D $days
    --> Date:D) {
        return $start if $days == 0;

        my Date $current_day = $start;
        for 1..$days.abs {
            repeat {
                $current_day = ($days > 0) ?? $current_day.Date::succ
                                           !! $current_day.Date::pred;
            } until self.is-workday($current_day);
        }
        $current_day
    }

    method workdays-to(WorkdayCalendar:D:
      Date:D $start is copy,
      Date:D $target is copy
    --> Int:D) {
        return 0 if $start.daycount == $target.daycount;

        my int $sign = $start.daycount < $target.daycount
          ?? +1
          !! -1;
        my Date $current_day = $start;
        my int $count;
        repeat {
            $current_day = ($sign == +1) ?? $current_day.Date::succ
                                         !! $current_day.Date::pred;
            $count++ if self.is-workday($current_day);
        } until ($current_day.daycount == $target.daycount);

        $count * $sign
    }

    method networkdays(WorkdayCalendar:D:
      Date:D $start is copy,
      Date:D $target is copy
    --> Int:D) {
        if $start.daycount == $target.daycount {
             return self.is-workday($start).Int
        }
        my int $sign = +1;
        if $start.daycount > $target.daycount {
            $sign = -1;
            my Date $aux_day = $start;
            $start = $target;
            $target = $aux_day;
        }
        my Date $current_day = $start;
        my int $count;
        while $current_day.daycount <= $target.daycount {
            $count++ if self.is-workday($current_day);
            $current_day = $current_day.Date::succ;
        }

        $count * $sign;
    }

    method range(WorkdayCalendar:D: Date:D $begin, Date:D $end) {
        my Date @slice;
        my int $from = ($begin.daycount, $end.daycount).min;
        my int $to   = ($begin.daycount, $end.daycount).max;
        for @.holidays -> $date { #--- The holidays are already sorted
            push @slice, $date if $from <= $date.daycount <= $to;
        }
        my $result_calendar = self.clone; #-- Requires a customized version of clone
        $result_calendar.holidays = @slice;
        $result_calendar
    }

    method clone(WorkdayCalendar:D:) {
        my WorkdayCalendar $new = WorkdayCalendar.new;
        given self {
            $new.workdays = .workdays;
            $new.holidays = .holidays;
            $new.file     = .file;
        }
        $new
    }
}

#------------------------------------------------------------------------------#

class Workdate is Date {
    has WorkdayCalendar $.calendar is rw;

    method !add-calendar($calendar) {
        self.calendar = $calendar // WorkdayCalendar.new;
        self
    }

    # We try to provide the same constructors as the Date class
    multi method new(Workdate: :$year!, :$month, :$day, :$calendar) {
        self.Date::new(:$year, :$month, :$day)!add-calendar($calendar)
    }
    multi method new(Workdate: $year, $month, $day, $calendar?) {
        self.Date::new(:$year, :$month, :$day)!add-calendar($calendar)
    }
    multi method new(Workdate: Str:D $date, $calendar?) {
        self.Date::new($date)!add-calendar($calendar)
    }
    multi method new(Workdate: DateTime:D $dt, $calendar?) {
        self.Date::new($dt)!add-calendar($calendar)
    }
    multi method new(Date:D $d, $calendar) {
        self.Date::new($d)!add-calendar($calendar)
    }

    method succ() { $.calendar.workdays-away(self, +1) }
    method pred() { $.calendar.workdays-away(self, -1) }

    method is-workday() { $.calendar.is-workday(self) }
    method is-weekend() { $.calendar.is-weekend(self) }
    method is-holiday() { $.calendar.is-holiday(self) }

    method workdays-away(Int:D $days --> Int:D) {
        $.calendar.workdays-away(self, $days)
    }
    method workdays-to(Date:D $target --> Int:D) {
        $.calendar.workdays-to(self, $target)
    }
    method networkdays(Date:D $target --> Int:D) {
        $.calendar.networkdays(self, $target)
    }
    
    multi method raku(Workdate:D: --> Str:D) {
        self.^name
          ~ "($.year, $.month, $.day, $.calendar.raku())"
    }
}

#------------------------------------------------------------------------------#

multi infix:<eq>(WorkdayCalendar:D $wc1, WorkdayCalendar:D $wc2) is export {
    #--- No support for typed arrays yet AFAIK. Have to compare them in a "stringy" way
    my Str (@wc1_string_holidays, @wc2_string_holidays);
    for $wc1.holidays { push @wc1_string_holidays, .yyyy-mm-dd };
    for $wc2.holidays { push @wc2_string_holidays, .yyyy-mm-dd };

    $wc1.workdays ~~ $wc2.workdays
      && @wc1_string_holidays ~~ @wc2_string_holidays
}

multi infix:<ne>(WorkdayCalendar:D $wc1, WorkdayCalendar:D $wc2) is export {
    not $wc1 eq $wc2
}

multi infix:<->(Workdate:D $start, Workdate:D $target) is export {
    $start.calendar eq $target.calendar
      ?? -1 * $start.workdays-to($target)
      !! (die "Both Workdates must have equivalent calendars to substract them")
}

=begin pod

=head1 NAME

Date::WorkdayCalendar - Calendar and Date objects to handle business days, holidays and weekends

=head1 SYNOPSIS

=begin code :lang<raku>

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

=end code

=head1 DESCRIPTION

The C<WorkdayCalendar> and C<Workdate> objects allow date calculations to be
made on a calendar that considers workdays (also called "business days").

Built on top of the C<Date> datatype, it uses a calendar file to specify how
many days a workweek has and which days are to be considered holidays.

By default, the workweek is composed of Monday, Tuesday, Wednesday,
Thursday, and Friday.  Saturday and Sunday form the weekend.

Although most countries have a Monday to Friday workweek, some have very
different ones.

More information about workweeks can be found at
L<http://en.wikipedia.org/wiki/Workweek>.

=head1 INTRODUCTION

The module provides two classes: C<WorkdayCalendar> and C<Workday>.  Objects
of these classes allow date calculations to be made on a calendar that
takes workdays (also called "business days") into account.

Built on top of the C<Date> datatype, it uses a calendar file to specify how
many days a workweek has and which days are to be considered holidays.

By default, the I<workweek> is composed by B<Mon>, B<Tue>, B<Wed>, B<Thu>,
and B<Fri>.  B<Sat> and B<Sun> form the I<weekend>.

Alhough most countries have a workweek of B<Mon> to B<Fri>, some have very
different ones.

More information about workweeks can be found at
L<http://en.wikipedia.org/wiki/Workweek>.

=head1 CALENDAR FILE FORMAT

=begin code

# An example calendar file
W:Mon,Tue,Wed,Thu,Fri
H:2011/01/01
H:2011-04-05

=end code

This calendar specifies that B<Mon> to B<Fri> are to be considered workdays,
and that 2011/01/01 and 2011/04/05 are national holidays. You can use
C</> or C<-> as separators in a date. The format of the date B<must be> in
the order Year, Month, Day.

If the C<W:> specification is incorrect, the default workweek (B<Mon>,
B<Tue>, B<Wed>, B<Thu>, B<Fri>) is used. If a holiday (a row starting with
C<H:>) is not well defined, it is ignored.

Lines starting with C<#> are comments and will be ignored when parsing the file.

=head1 WorkdayCalendar class

=head2 method new

=begin code :lang<raku>

my $wdc1 = WorkdayCalendar.new;
my $wdc2 = WorkdayCalendar.new('calendar.cal');

=end code

Creates a new calendar. Optionally, accepts the name of a file using the
calendar format specified above. If a filename is not specified, the
calendar will have no holidays and a default workweek of B<Mon>, B<Tue>,
B<Wed>, B<Thu>, B<Fri>.

=head2 method clear

Empties the information for holidays and workdays, and resets the
workweek to the default: B<Mon>, B<Tue>, B<Wed>, B<Thu>, B<Fri>.

=head2 method read(Str $calendar_filename)

Reads the data of holidays and workdays from a calendar file.

=head2 method is-workday(Date $day)

Returns C<True> if the day is part of the workweek and not a holiday.

=head2 method is-weekend(Date $day)

Returns C<True> if the day is not part of the workweek.

=head2 method is-holiday(Date $day)

Returns C<True> if the day has been defined as holiday in the calendar file.

=head2 method workdays-away(Date $start, Int $days)

Returns a C<Date> that corresponds to the workday at which C<$days> working
days have passed.  With this method you can ask questions like: "what is the
next working day for some date?" or "what is the previous working day of
some date?" or "what date is 2 working days from a date?".

Examples:

Considering the workdays = B<Mon Tue Wed Thu Fri>...

=begin code

$start       : July 29, 2011 (it is a Friday)
$days        : +1
Return Value : Aug 1, 2011 (it is a Monday)

$start       : July 30, 2011 (it is a Saturday)
$days        : +1
Return Value : Aug 1, 2011 (it is a Monday)

=end code
 
This also works for a negative number of days.

=head2 method workdays-to(Date $start, Date $target)

Returns the 'distance', in workdays, of C<$start> and C<$target> dates.

=head2 method networkdays(Date $start, Date $target)

Works like the C<workdays-to> method, but emulates the NETWORKDAYS function in
Microsoft Excel.

Examples:

=begin code

   Start     Target    workdays-to     networkdays
2011-07-07  2011-07-14     5              6
2011-07-07  2011-07-07     0              1
2011-07-07  2011-07-08     1              2
2011-07-07  2011-07-01    -4             -5
2011-01-01  2011-01-01     0              0
2011-01-01  2011-01-02     0              0
2011-01-01  2011-01-03     1              1

=end code

=head2 method range(Date $start, Date $end)

Returns a part of a calendar as a new C<WorkdayCalendar> object, between the
C<$start> and C<$end> dates, inclusive.  For example, if you have a calendar
that contains holiday information for 3 years, you can use C<range> to
obtain a new calendar that covers a period of 6 months of these 3 years.
Useful with the C<eq> operator for C<WorkdayCalendar> objects.

=head2 method raku

Returns a string representing the contents of the C<WorkdayCalendar> attributes.

=head1 C<Workdate> class

Implemented as a subclass of C<Date>. It replaces C<Date>'s C<.succ> and C<.pred>
methods to take workdays into account and provides the functionality to perform
basic workdate calculations.

You can specify a previously created C<WorkdayCalendar> object as a parameter,
or none at all. If a C<WorkdayCalendar> is not specified, it uses a default
workweek of B<Mon> , B<Tue>, B<Wed>, B<Thu>, B<Fri> and no holidays.

Example:

=begin code :lang<raku>

# July 1st of 2011 is a Friday
my $wdate = Workdate.new(year=>2011, month=>07, day=>01); #--- Uses a default calendar with
                                                          #--- default workweek and no holidays
my $next_day = $wdate.succ; # $next_day is Monday, July 4, 2011

=end code

Another example:

=begin code :lang<raku>

my $CAL = WorkdayCalendar.new('example.cal'); # Some calendar file with 2011-Feb-2 as holiday
my $date = Workdate.new(year=>2011, month=>02, day=>01, calendar=>$CAL);
# February 1 of 2011 is a Tuesday
my $next_day = $date.succ; # $next_day is Thursday, February 3, 2011

=end code

=head2 method new

=begin code :lang<raku>

my $wd1 = Workdate.new(year=>2000, month=>12, day=>01, calendar=>$aWorkdayCalendar);
my $wd2 = Workdate.new(2000, 12, 01, $aWorkdayCalendar);
my $wd3 = Workdate.new($aDateString, $aWorkdayCalendar);
my $wd4 = Workdate.new($aDateTimeObject, $aWorkdayCalendar);
my $wd4 = Workdate.new($aDateObject, $aWorkdayCalendar);

=end code

We try to provide the same constructors as the base C<Date> class, plus another
to create C<Workdate>s from regular C<Date>s.  Thus, we can create a
C<Workdate> in 4 different ways, from named and positional parameters, and
by using a C<Date> or a C<DateTime> object for specifying the date. In all
cases, the calendar is optional, and if it is not specified a default calendar
will be applied to the new C<Workdate>.

=head2 method succ

Returns the next workdate.

=head2 method pred

Returns the previous workdate.

=head2 method is-workday

Returns True if the workdate is not a holiday and is not part of the weekend.

=head2 method is-weekend

Returns True if the workdate is not part of the workweek.

=head2 method is-holiday

Returns True if the workdate is reported as a holiday.

=head2 method workdays-away(Int $days)

Returns the workdate that is C<$days> workdays from the given workdate.

=head2 method workdays-to(Date $target)

Return the number of workdays until C<$target>.

=head2 method raku

Returns a string representing the contents of the C<Workdate> attributes.

=head1 OPERATORS

=head2 Comparison: eq

Compares two calendars and returns True if they are equivalent.  For that,
they must have the same holidays and the same workweek.  For instance, this
would be as if they used the same calendar file.

You can use the C<range> method for C<WorkdayCalendar> objects to compare
smaller periods of time instead of a whole C<WorkdayCalendar>.

=head2 Comparison: ne

Returns the opposite of C<eq>.

=head2 Arithmetic: infix -

Returns the difference, in workdays, between C<$wd1> and C<$wd2>.

=head1 AUTHOR

Shinobi

=head1 COPYRIGHT AND LICENSE

Copyright 2012 - 2013 Shinobi

Copyright 2014 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
