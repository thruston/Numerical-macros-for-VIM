#! /usr/bin/env python
# encoding: utf-8

# Toby Thurston -- 13 Apr 2010 
# Useful tools for (naive) dates

from decimal import *
import datetime

def easter(y):
    """Return the date of Easter Sunday as a Decimal in yyyymmdd form given a year.
    
    >>> print easter(1999)
    19990404

    """

    if y<1500:
        y = 1500
    elif y>10000000:
        y = int(y/10000)
    elif y>9999:
            y = 9999

    g = y%19
    c = 1+int(y/100)
    a = int(c*3/4)-12
    b = int(c*8+5)/25
    e = (11*g+2-a+b)%30
    if e==0 or (e==1 and g>10): e+=1
    d = 19-(e-7+(int(y*5/4)-a+5-e)%7)
    if d<1:
        m = 3
        d += 31
    else:
        m = 4
    return Decimal("%d%02d%02d" % (y, m, d))

def date(n=0):
    """Return the date in yyyymmdd form as a Decimal.

    If abs(n) < 10000 then treat as n as a delta from today
    Otherwise n is a proleptic Gregorian "base date" as produced by datetime.date.toordinal()
    (and you'll get a trap if the resulting date is out of bounds)

    >>> print date(700000)
    19170715
    >>> print datetime.date.today().strftime("%Y%m%d")==str(date())
    True


    """
    if n < 600000:
        n += datetime.date.today().toordinal()
    return Decimal(datetime.date.fromordinal(n).strftime("%Y%m%d"))

def base(n=0):
    """Return date in proleptic Georgian form."""
    if n < 10001231:
        n += datetime.date.today().toordinal()
    else:
        date = str(int(n))
        y = int(date[0:-4])
        d = int(date[-2:])
        m = int(date[-4:-2])
        n = datetime.date(y,m,d).toordinal()
    return Decimal(n)

def timestamp():
    """Return a time stamp string.

    >>> print len(timestamp())
    26

    """
    return datetime.datetime.now().isoformat()
            

if __name__ == "__main__":
    import doctest
    doctest.testmod()
